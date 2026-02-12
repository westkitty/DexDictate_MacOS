import SwiftUI

/// Start/Stop Dictation and Quit buttons shown in the main popover.
///
/// Displays a **Start Dictation** button when the engine is `.stopped`, or a
/// **Stop Dictation** button in all other states.
struct ControlsView: View {
    @ObservedObject var engine: TranscriptionEngine

    var body: some View {
        VStack(spacing: 12) {
            if engine.state == .stopped {
                Button(action: { Task { await engine.startSystem() } }) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Start Dictation")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.3), lineWidth: 1))
                    .shadow(color: .green.opacity(0.3), radius: 5)
                }
                .buttonStyle(.plain)
            } else {
                let canToggleListening = engine.state == .ready || engine.state == .listening
                Button(action: { engine.toggleListening() }) {
                    HStack {
                        Image(systemName: engine.state == .listening ? "stop.circle.fill" : "mic.circle.fill")
                        Text(engine.state == .listening ? "Stop Listening" : "Start Listening")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(color: .blue.opacity(0.3), radius: 5)
                }
                .buttonStyle(.plain)
                .disabled(!canToggleListening)

                Text("Trigger: \(Settings.shared.userShortcut.displayString)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))

                Button(action: { engine.stopSystem() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop Dictation")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(color: .red.opacity(0.3), radius: 5)
                }
                .buttonStyle(.plain)
            }

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("Quit App")
                    .font(.subheadline).fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
}
