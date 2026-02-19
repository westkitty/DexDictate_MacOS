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

    var body: some View {
        ZStack {
            // Logo watermark (background) — load directly from kit bundle PNG
            if let url = Safety.resourceBundle.url(forResource: "Assets.xcassets/AppIcon.appiconset/icon", withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .opacity(0.20)
                    .ignoresSafeArea()
            }
            Text("DEX")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.14))
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
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
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
}

@MainActor
class FloatingHUDController: ObservableObject {
    private var window: FloatingHUDWindow?
    private var engine: TranscriptionEngine?
    
    init() {}
    
    func setup(engine: TranscriptionEngine) {
        self.engine = engine
    }
    
    func show() {
        guard let engine = engine else { return }
        if window == nil {
            let view = FloatingHUDView(engine: engine)
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
