import SwiftUI
import DexDictateKit

/// Settings → Dictation. Migrated verbatim (same bindings, same storage keys) from the
/// popover's pinned Trigger Mode control and the "Input" / "Accuracy & Speed" cards:
/// trigger style, the shortcut recorder, silence timeout, and the adaptive tail preset.
/// "Pause browser media during dictation" (Packet 08B) also lives here — it was an
/// orphaned Input-card control with no home until Andrew assigned it during Packet 08.
struct DictationSettingsPage: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(SettingsPage.dictation.title)
                    .font(.title2.bold())

                triggerModeSection

                ShortcutRecorder(shortcut: $settings.userShortcut)

                Divider()

                silenceTimeoutSection

                Divider()

                controlRow(label: "End Preset") {
                    Picker("", selection: $settings.utteranceEndPreset) {
                        ForEach(AppSettings.UtteranceEndPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }

                SettingToggleWithInfo(
                    title: "Adaptive Tail Delay",
                    info: "After you stop speaking, DexDictate waits a moment before cutting off the recording. Adaptive Tail Delay learns how long you typically pause between words and adjusts this wait automatically — so it doesn't clip the end of what you said or make you wait too long before transcription starts.",
                    isOn: $settings.adaptiveTailDelayEnabled
                )

                Divider()

                Text("During Dictation")
                    .font(.headline)
                SettingToggleWithInfo(
                    title: "Pause browser media during dictation",
                    info: "Pauses video and audio in Chrome, Brave, or Edge tabs when recording starts, then resumes them when you stop. macOS will ask for Automation permission the first time it runs. Skips automatically when Zoom is active. Safari and Firefox are not supported.",
                    isOn: $settings.pauseBrowserMediaDuringDictation
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var triggerModeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Trigger Mode")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                TriggerSegment(
                    title: "Hold",
                    isSelected: settings.triggerMode == .holdToTalk
                ) {
                    settings.triggerMode = .holdToTalk
                }
                Divider().frame(width: 1)
                TriggerSegment(
                    title: "Toggle",
                    isSelected: settings.triggerMode == .toggle
                ) {
                    settings.triggerMode = .toggle
                }
            }
            .frame(width: 220)
            .background(Color.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .disabled(settings.safeModeEnabled)

            Text(settings.triggerMode == .holdToTalk
                 ? "Hold: records only while the trigger is pressed."
                 : "Toggle: first press starts, second press stops.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var silenceTimeoutSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Silence Timeout")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(settings.silenceTimeout == 0 ? "Disabled" : "\(Int(settings.silenceTimeout))s")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $settings.silenceTimeout, in: 0...15, step: 1)
                .tint(.cyan)
            Text("For long dictation, raise this or turn it off.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func controlRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            content()
        }
    }
}
