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

    @State private var cachedWatermarkImage: NSImage? = nil

    var body: some View {
        ZStack {
            // Logo watermark (background) — cached to avoid disk I/O on every body re-render
            if let nsImage = cachedWatermarkImage {
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
        .onAppear {
            cachedWatermarkImage = loadWatermarkImage()
        }
        .onChange(of: profileManager.currentWatermarkAsset?.url) { _, _ in
            cachedWatermarkImage = loadWatermarkImage()
        }
    }

    private func loadWatermarkImage() -> NSImage? {
        if let assetURL = profileManager.currentWatermarkAsset?.url,
           let nsImage = NSImage(contentsOf: assetURL) {
            return nsImage
        }
        if let url = Safety.resourceBundle.url(forResource: "Assets.xcassets/AppIcon.appiconset/icon", withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            return nsImage
        }
        return nil
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
    private var hubPanel: NSPanel?
    private var engine: TranscriptionEngine?
    private var profileManager: ProfileManager?
    private var onDetachHistory: (() -> Void)?
    private var onOpenHelp: (() -> Void)?

    init() {}

    func setup(
        engine: TranscriptionEngine,
        profileManager: ProfileManager,
        onDetachHistory: (() -> Void)? = nil,
        onOpenHelp: (() -> Void)? = nil
    ) {
        self.engine = engine
        self.profileManager = profileManager
        self.onDetachHistory = onDetachHistory
        self.onOpenHelp = onOpenHelp
    }

    func show() {
        guard let engine = engine, let profileManager = profileManager else { return }
        if window == nil {
            let rootView: AnyView
            if AppSettings.shared.useExperimentalNanoHUD {
                let nanoView = DexNanoHUDView(
                    engine: engine,
                    profileManager: profileManager,
                    onOpenHub: { [weak self] in self?.showHubPanel() }
                )
                rootView = AnyView(nanoView)
            } else {
                let stdView = FloatingHUDView(engine: engine, profileManager: profileManager)
                rootView = AnyView(stdView)
            }
            window = FloatingHUDWindow(
                contentRect: NSRect(x: 100, y: 100, width: 200, height: 60),
                rootView: rootView
            )
            window?.minSize = NSSize(width: 150, height: 40)
            window?.maxSize = NSSize(width: 480, height: 200)
            window?.setFrameAutosaveName("FloatingHUDPosition")
            if window?.frame.origin == .zero {
                window?.center()
            }
        }
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func toggle(shouldShow: Bool) {
        if shouldShow { show() } else { hide() }
    }

    /// Tear down the existing window and reopen it, picking up any flag changes
    /// (e.g. `useExperimentalNanoHUD`). Safe to call when HUD is hidden — no-op.
    func refresh() {
        let wasVisible = window?.isVisible ?? false
        if wasVisible {
            window?.close()
            window = nil
            show()
        }
    }

    /// Open a floating feature-hub panel from the Nano HUD so the HUD is never a dead end.
    /// The panel hosts DexExperimentalFeatureHubView and uses the same non-activating style
    /// as the HUD — no Dock bounce.
    func showHubPanel() {
        guard let engine = engine, let profileManager = profileManager else { return }
        if hubPanel == nil {
            let hubView = DexExperimentalFeatureHubView(
                engine: engine,
                settings: AppSettings.shared,
                profileManager: profileManager,
                onBack: { [weak self] in self?.closeHubPanel() },
                onDetachHistory: onDetachHistory != nil ? { [weak self] in self?.onDetachHistory?(); self?.closeHubPanel() } : nil,
                onOpenHelp: onOpenHelp != nil ? { [weak self] in self?.onOpenHelp?(); self?.closeHubPanel() } : nil,
                onQuit: { NSApplication.shared.terminate(nil) }
            )
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
                styleMask: [.nonactivatingPanel, .titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = NSColor(red: 0.09, green: 0.10, blue: 0.14, alpha: 1.0)
            panel.hasShadow = true
            panel.contentView = NSHostingView(rootView: AnyView(hubView))
            panel.setFrameAutosaveName("DexFeatureHubPanelPosition")
            if panel.frame.origin == .zero { panel.center() }
            hubPanel = panel
        }
        hubPanel?.orderFront(nil)
    }

    private func closeHubPanel() {
        hubPanel?.orderOut(nil)
        hubPanel = nil
    }
}
