import SwiftUI
import AppKit
import DexDictateKit

/// A transparent, floating panel that shows dictation status.
class FloatingHUDWindow: NSPanel {
    init(contentRect: NSRect, rootView: AnyView) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .hudWindow, .utilityWindow, .titled],
                   backing: .buffered,
                   defer: false)
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.hasShadow = true
        
        let hostingView = NSHostingView(rootView: rootView)
        self.contentView = hostingView
    }
}

struct FloatingHUDView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var profileManager: ProfileManager

    var body: some View {
        ZStack {
            // Logo watermark (background) — load directly from kit bundle PNG
            if let assetURL = profileManager.currentWatermarkAsset?.url,
               let nsImage = NSImage(contentsOf: assetURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: watermarkSize, height: watermarkSize)
                    .opacity(watermarkOpacity)
                    .ignoresSafeArea()
            } else if let url = Safety.resourceBundle.url(forResource: "Assets.xcassets/AppIcon.appiconset/icon", withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: watermarkSize, height: watermarkSize)
                    .opacity(watermarkOpacity)
                    .ignoresSafeArea()
            }
            Text("DEX")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(watermarkTextOpacity))
                .rotationEffect(.degrees(-14))
                .allowsHitTesting(false)

            // Status content (foreground)
            HStack(spacing: 8) {
                Image(systemName: engine.statusIcon)
                    .font(.title2)
                    .symbolEffect(.pulse, isActive: engine.state == .listening)
                    .foregroundStyle(statusColor)

                if engine.state == .listening || engine.state == .transcribing {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(engine.statusText)
                            .font(.caption)
                            .bold()
                            .lineLimit(1)

                        // Mic Level
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                Rectangle()
                                    .fill(statusColor)
                                    .frame(width: geo.size.width * CGFloat(engine.inputLevel))
                                    .animation(.linear(duration: 0.1), value: engine.inputLevel)
                            }
                        }
                        .frame(height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    .frame(width: 100)
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(chromeOpacity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(readabilityScrimOpacity))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(statusColor.opacity(statusTintOpacity))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
                    )
            }
        }
    }
    
    var statusColor: Color {
        switch engine.state {
        case .listening: return .red
        case .transcribing: return .yellow
        case .ready: return .green
        case .error: return .orange
        case .initializing: return .blue
        case .stopped: return .gray
        }
    }

    private var isActiveState: Bool {
        engine.state == .listening || engine.state == .transcribing
    }

    private var watermarkSize: CGFloat {
        isActiveState ? 92 : 88
    }

    private var watermarkOpacity: Double {
        isActiveState ? 0.44 : 0.34
    }

    private var watermarkTextOpacity: Double {
        isActiveState ? 0.28 : 0.22
    }

    private var chromeOpacity: Double {
        isActiveState ? 0.18 : 0.12
    }

    private var readabilityScrimOpacity: Double {
        isActiveState ? 0.12 : 0.08
    }

    private var statusTintOpacity: Double {
        switch engine.state {
        case .listening:
            return 0.08
        case .transcribing:
            return 0.06
        case .ready:
            return 0.04
        case .error:
            return 0.07
        case .initializing:
            return 0.05
        case .stopped:
            return 0.03
        }
    }

    private var borderOpacity: Double {
        isActiveState ? 0.18 : 0.12
    }
}

@MainActor
class FloatingHUDController: ObservableObject {
    private var window: FloatingHUDWindow?
    private var engine: TranscriptionEngine?
    private var profileManager: ProfileManager?
    
    init() {}
    
    func setup(engine: TranscriptionEngine, profileManager: ProfileManager) {
        self.engine = engine
        self.profileManager = profileManager
    }
    
    func show() {
        guard let engine = engine, let profileManager = profileManager else { return }
        if window == nil {
            let view = FloatingHUDView(engine: engine, profileManager: profileManager)
            window = FloatingHUDWindow(
                contentRect: NSRect(x: 100, y: 100, width: 200, height: 60),
                rootView: AnyView(view)
            )
            // Set window size constraints to prevent invalid resizing
            window?.minSize = NSSize(width: 150, height: 50)
            window?.maxSize = NSSize(width: 400, height: 200)

            // Restore saved position or center on first launch
            window?.setFrameAutosaveName("FloatingHUDPosition")
            if window?.frame.origin == .zero {
                window?.center() // Only center on first launch
            }
        }
        window?.orderFront(nil)
    }
    
    func hide() {
        window?.orderOut(nil)
    }
    
    func toggle(shouldShow: Bool) {
        if shouldShow {
            show()
        } else {
            hide()
        }
    }
}
