import SwiftUI
import DexDictateKit

// MARK: - Nano HUD View

/// Experimental minimal nano strip HUD.
///
/// Shown only when `AppSettings.useExperimentalNanoHUD == true` and
/// `AppSettings.showFloatingHUD == true`. The existing `FloatingHUDView`
/// remains in place and is restored by disabling `useExperimentalNanoHUD`.
///
/// Deliberately small: state text + mic meter + cancel/stop. Does not steal
/// focus (panel created with `.nonactivatingPanel`).
///
/// Hard constraints respected:
/// - Does not modify audio capture, transcription, or output insertion.
/// - Stop button calls `engine.toggleListening()`, which stops recording and proceeds
///   to transcription. There is no public discard-without-transcribing path.
/// - Reduced Motion removes the meter animation.
struct DexNanoHUDView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var profileManager: ProfileManager
    var onOpenHub: (() -> Void)?

    @State private var cachedWatermarkImage: NSImage? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            watermarkLayer

            HStack(spacing: 10) {
                stateIndicator
                centerContent
                if engine.state == .listening {
                    cancelButton
                }
                hubButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(backgroundLayer)
        }
        .fixedSize()
        .onAppear { cachedWatermarkImage = loadWatermarkImage() }
        .onChange(of: profileManager.currentWatermarkAsset?.url) { _, _ in
            cachedWatermarkImage = loadWatermarkImage()
        }
    }

    // MARK: - Sub-views

    private var watermarkLayer: some View {
        ZStack {
            if let nsImage = cachedWatermarkImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .opacity(0.18)
                    .allowsHitTesting(false)
            }
            Text("DEX")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Color.white.opacity(0.14))
                .rotationEffect(.degrees(-14))
                .allowsHitTesting(false)
        }
    }

    private var stateIndicator: some View {
        Image(systemName: stateIcon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(stateColor)
            .symbolEffect(
                .pulse,
                isActive: engine.state == .listening && !reduceMotion
            )
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
    }

    private var centerContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(stateLabel)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(stateColor)
                .lineLimit(1)
                .accessibilityLabel("Dictation state: \(stateLabel)")

            if engine.state == .listening {
                micMeter
            } else if engine.state == .transcribing {
                Text(engine.liveTranscript.isEmpty ? "Processing…" : engine.liveTranscript)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.60))
                    .lineLimit(1)
                    .frame(width: 100, alignment: .leading)
                    .accessibilityLabel(engine.liveTranscript.isEmpty ? "Processing" : engine.liveTranscript)
            }
        }
        .frame(width: 120, alignment: .leading)
    }

    private var micMeter: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(stateColor.opacity(0.80))
                    .frame(width: geo.size.width * CGFloat(min(engine.inputLevel, 1.0)))
                    .animation(reduceMotion ? nil : .linear(duration: 0.08), value: engine.inputLevel)
            }
        }
        .frame(width: 100, height: 3)
        .accessibilityLabel("Microphone level: \(Int(engine.inputLevel * 100)) percent")
    }

    @ViewBuilder
    private var cancelButton: some View {
        // Wired to toggleListening() which stops recording and proceeds to transcription.
        // There is no public engine method to discard audio without transcribing — the
        // button stops the recording session early rather than truly cancelling it.
        // Future: expose engine.discardCurrentRecording() to support silent discard.
        Button(action: stopRecording) {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.50))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop recording now")
        .help("Stop recording (finishes transcription)")
    }

    // Always-visible settings button — ensures the HUD is never a dead-end surface.
    // Opens the DexDictate popover via the status item, which contains the full Feature Hub.
    private var hubButton: some View {
        Button(action: { onOpenHub?() }) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.42))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open DexDictate settings")
        .help("All features and settings")
    }

    private var backgroundLayer: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.ultraThinMaterial)
            .opacity(0.92)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .fill(stateColor.opacity(stateColorTint))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 8, y: 2)
    }

    // MARK: - State helpers

    private var stateLabel: String {
        switch engine.state {
        case .stopped:      return "Off"
        case .initializing: return "Starting…"
        case .ready:        return "Ready"
        case .listening:    return "Listening"
        case .transcribing: return "Transcribing"
        case .error:        return "Error"
        }
    }

    private var stateIcon: String {
        switch engine.state {
        case .stopped:      return "mic.slash"
        case .initializing: return "ellipsis.circle"
        case .ready:        return "mic"
        case .listening:    return "waveform"
        case .transcribing: return "brain"
        case .error:        return "exclamationmark.triangle"
        }
    }

    private var stateColor: Color {
        switch engine.state {
        case .stopped:      return .gray
        case .initializing: return .blue
        case .ready:        return .green
        case .listening:    return .red
        case .transcribing: return .yellow
        case .error:        return .orange
        }
    }

    private var stateColorTint: Double {
        switch engine.state {
        case .listening:    return 0.07
        case .transcribing: return 0.05
        default:            return 0.03
        }
    }

    // MARK: - Actions

    private func stopRecording() {
        // Calls toggleListening() which transitions from .listening → .transcribing.
        // Audio is processed normally — this is "stop early" not "discard".
        // A true silent-discard path would require a new engine method.
        MainActorAction.run {
            engine.toggleListening()
        }
    }

    private func loadWatermarkImage() -> NSImage? {
        if let assetURL = profileManager.currentWatermarkAsset?.url,
           let nsImage = NSImage(contentsOf: assetURL) {
            return nsImage
        }
        if let url = Safety.resourceBundle.url(
            forResource: "Assets.xcassets/AppIcon.appiconset/icon",
            withExtension: "png"
        ), let nsImage = NSImage(contentsOf: url) {
            return nsImage
        }
        return nil
    }
}
