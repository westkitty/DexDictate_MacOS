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

// MARK: - Main HUD View

struct FloatingHUDView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var settings: AppSettings

    // Waveform bars
    @State private var barHeights: [CGFloat] = Array(repeating: 3, count: 16)
    @State private var wavePhase: Double = 0
    private let waveTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Watermark
            watermarkLayer

            // Status content
            VStack(spacing: 6) {
                // Top row: dot + state label + app name
                HStack(spacing: 7) {
                    Circle()
                        .fill(stateColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: stateColor.opacity(0.8), radius: 5)
                        .opacity(isActive ? 1.0 : 0.6)

                    Text(engine.statusText.uppercased())
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(stateColor)
                        .lineLimit(1)

                    Spacer()

                    Text("DEXDICTATE")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.12))
                }

                // Waveform (listening) or shimmer bar (transcribing)
                if engine.state == .listening {
                    HUDWaveformView(barHeights: barHeights)
                } else if engine.state == .transcribing {
                    HUDShimmerBar(color: stateColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
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
                            .fill(stateColor.opacity(statusTintOpacity))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(stateColor.opacity(borderOpacity), lineWidth: 1)
                    )
                    .shadow(color: stateColor.opacity(isActive ? 0.22 : 0.08), radius: isActive ? 12 : 4)
            }
        }
        .onReceive(waveTimer) { _ in
            guard engine.state == .listening else {
                barHeights = Array(repeating: 3, count: barHeights.count)
                return
            }
            wavePhase += 0.18
            let amp = max(0.05, engine.inputLevel)
            barHeights = barHeights.enumerated().map { i, _ in
                let sine = sin(wavePhase + Double(i) * 0.65) * 0.5 + 0.5
                return CGFloat(max(3, (sine + Double.random(in: 0...0.25)) * amp * 14))
            }
        }
    }

    // MARK: - Watermark

    @ViewBuilder
    private var watermarkLayer: some View {
        ZStack {
            if let assetURL = profileManager.currentWatermarkAsset?.url,
               let nsImage = NSImage(contentsOf: assetURL) {
                Image(nsImage: nsImage)
                    .resizable().scaledToFit()
                    .frame(width: watermarkSize, height: watermarkSize)
                    .opacity(watermarkOpacity)
                    .ignoresSafeArea()
            } else if let url = Safety.resourceBundle.url(
                forResource: "Assets.xcassets/AppIcon.appiconset/icon", withExtension: "png"),
                      let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable().scaledToFit()
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
        }
    }

    // MARK: - Colours

    /// Returns the user-overridden accent colour if one is set, otherwise falls back to the
    /// state-driven semantic colour.
    var stateColor: Color {
        // If user has set a custom colour (all components ≥ 0), use it
        if settings.hudAccentColorR >= 0 {
            return Color(
                red: settings.hudAccentColorR,
                green: settings.hudAccentColorG,
                blue: settings.hudAccentColorB
            )
        }
        switch engine.state {
        case .listening:    return SemanticColors.listening
        case .transcribing: return SemanticColors.transcribing
        case .ready:        return SemanticColors.ready
        case .error:        return SemanticColors.error
        case .initializing: return SemanticColors.initializing
        case .stopped:      return SemanticColors.stopped
        }
    }

    private var isActive: Bool {
        engine.state == .listening || engine.state == .transcribing
    }

    private var watermarkSize: CGFloat  { isActive ? 92 : 88 }
    private var watermarkOpacity: Double { isActive ? 0.44 : 0.34 }
    private var watermarkTextOpacity: Double { isActive ? 0.28 : 0.22 }
    private var chromeOpacity: Double { isActive ? 0.18 : 0.12 }
    private var readabilityScrimOpacity: Double { isActive ? 0.12 : 0.08 }

    private var statusTintOpacity: Double {
        switch engine.state {
        case .listening:    return 0.08
        case .transcribing: return 0.06
        case .ready:        return 0.04
        case .error:        return 0.07
        case .initializing: return 0.05
        case .stopped:      return 0.03
        }
    }

    private var borderOpacity: Double { isActive ? 0.30 : 0.14 }
}

// MARK: - HUD Sub-Views

private struct HUDWaveformView: View {
    let barHeights: [CGFloat]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barHeights.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [
                                SemanticColors.listening.opacity(0.9),
                                SemanticColors.listening.opacity(0.35)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: barHeights[i])
                    .animation(.linear(duration: 0.05), value: barHeights[i])
            }
        }
        .frame(height: 14, alignment: .center)
    }
}

/// An animated shimmer bar shown during transcription.
private struct HUDShimmerBar: View {
    let color: Color
    @State private var offset: CGFloat = -60

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.06))

                // Shimmer
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.clear, color.opacity(0.7), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 50)
                    .offset(x: offset)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 1.1)
                            .repeatForever(autoreverses: false)
                        ) {
                            offset = geo.size.width + 10
                        }
                    }
            }
        }
        .frame(height: 3)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - Controller

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
            let view = FloatingHUDView(
                engine: engine,
                profileManager: profileManager,
                settings: AppSettings.shared
            )
            window = FloatingHUDWindow(
                contentRect: NSRect(x: 100, y: 100, width: 220, height: 64),
                rootView: AnyView(view)
            )
            window?.minSize = NSSize(width: 160, height: 50)
            window?.maxSize = NSSize(width: 420, height: 200)
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
}
