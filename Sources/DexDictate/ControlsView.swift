import SwiftUI
import DexDictateKit

/// Start/Stop Dictation and Quit buttons shown in the main popover.
///
/// Displays a **Start Dictation** button when the engine is `.stopped`.
/// When the engine is running, shows a status label (colour-coded by state),
/// the current trigger shortcut, and a **Stop Dictation** button.
/// The "Start Listening / Stop Listening" toggle has been removed — the trigger
/// shortcut or the Start/Stop Dictation buttons are the only controls.
struct ControlsView: View {
    @ObservedObject var engine: TranscriptionEngine

    // MARK: - Derived

    /// Colour that reflects the current engine state.
    private var statusColor: Color {
        switch engine.state {
        case .listening:    return .red
        case .transcribing: return .yellow
        case .ready:        return .green
        case .error:        return .orange
        default:            return .white
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            if engine.state == .stopped {
                // ── Stopped: offer to start the dictation system ──────────────
                Button(action: startDictation) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text(NSLocalizedString("Start Dictation", comment: "Button: Start Dictation"))
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.3), lineWidth: 1))
                    .shadow(color: .green.opacity(0.3), radius: 5)
                }
                .buttonStyle(.plain)
            } else {
                // ── Running: status + shortcut hint + stop button ─────────────

                // Colour-coded status label (Listening / Transcribing / Ready / …)
                Text(engine.statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                // Remind user which shortcut triggers dictation
                Text("\(NSLocalizedString("Trigger:", comment: "")) \(AppSettings.shared.userShortcut.displayString)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))

                // Stop the whole dictation system (returns to .stopped)
                Button(action: stopDictation) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text(NSLocalizedString("Turn Off Dictation", comment: ""))
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.5))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .red.opacity(0.3), radius: 5)
                }
                .buttonStyle(.plain)
            }

            // ── Always visible: Quit ──────────────────────────────────────────
            Button(action: quitApp) {
                Text(NSLocalizedString("Quit App", comment: ""))
                    .font(.subheadline).fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    // MARK: - Helper Methods

    /// Starts the dictation system asynchronously on the MainActor.
    ///
    /// Using named functions (rather than inline closures) avoids the SIGSEGV crash
    /// caused by SwiftUI's button gesture machinery calling `MainActor.assumeIsolated`
    /// when `engine` is `@MainActor`-isolated. This applies to ALL buttons that call
    /// methods on `@MainActor` types, including synchronous ones like `stopSystem()`.
    private func startDictation() {
        Task { @MainActor in
            await engine.startSystem()
        }
    }

    private func stopDictation() {
        engine.stopSystem()
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
