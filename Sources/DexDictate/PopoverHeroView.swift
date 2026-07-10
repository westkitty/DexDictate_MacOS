import SwiftUI
import DexDictateKit

/// The popover's primary "what's happening / do it" zone (Packet 09 slim popover contract).
/// Start/Stop calls the same `engine.startSystem()`/`engine.stopSystem()` API the classic
/// `ControlsView` buttons call — no engine changes. The Dexter watermark renders here only
/// while idle (`.stopped`/`.ready`), never behind the result text in `PopoverResultView`.
///
/// BUG-006B: this view used to hold one combined Start/Stop button. The red "Stop Dictation"
/// half competed visually with the model/status chip row directly below it in
/// `PopoverRootView`. That half moved to `PopoverRootView.stopDictationButton`, positioned
/// under the chip section instead — this hero now only ever shows the "Start Dictation"
/// affordance, and only while idle (`engine.state == .stopped`), matching exactly the
/// condition under which the old combined button used to say "Start Dictation". No change to
/// what stopping dictation actually does — only where the control that starts it lives.
struct PopoverHeroView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var settings: AppSettings
    @ObservedObject var livePreviewController: LivePreviewController
    let watermarkImage: NSImage?

    private var isIdle: Bool {
        engine.state == .stopped || engine.state == .ready
    }

    private var statusColor: Color {
        switch engine.state {
        case .listening: return .red
        case .transcribing: return .yellow
        case .ready, .stopped: return settings.statusAccentColor
        case .error: return .orange
        case .initializing: return .white
        }
    }

    private var statusLabel: String {
        switch engine.state {
        case .stopped: return "Ready"
        case .initializing: return "Starting…"
        case .ready: return "Ready"
        case .listening: return "Recording"
        case .transcribing: return "Processing"
        case .error: return "Error"
        }
    }

    private var triggerHint: String {
        let shortcut = settings.userShortcut.displayString
        switch settings.triggerMode {
        case .holdToTalk: return "Hold \(shortcut) to talk"
        case .toggle: return "Press \(shortcut) to start, again to stop"
        }
    }

    var body: some View {
        ZStack {
            if isIdle, let watermarkImage {
                Image(nsImage: watermarkImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .opacity(0.14)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusColor)
                }

                Text(triggerHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if engine.state == .stopped {
                    Button(action: toggleDictation) {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text("Start Dictation")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(settings.statusAccentColor.opacity(0.45))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start dictation system")
                }

                LivePreviewCaptionView(controller: livePreviewController)
                    .padding(.horizontal, 4)
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    private func toggleDictation() {
        if engine.state == .stopped {
            MainActorAction.run { await engine.startSystem() }
        } else {
            MainActorAction.run { engine.stopSystem() }
        }
    }
}
