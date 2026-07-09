import SwiftUI
import DexDictateKit

/// Settings → Audio & Microphone. Migrated verbatim (same bindings, same storage keys)
/// from the popover's "Input" / "Accuracy & Speed" cards: input device selection and
/// silence trimming. No input level meter exists in the popover's card to migrate.
struct AudioSettingsPage: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject var scanner: AudioDeviceScanner

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(SettingsPage.audioMicrophone.title)
                    .font(.title2.bold())

                HStack {
                    Text("Input Device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $settings.inputDeviceUID) {
                        Text("System Default").tag("")
                        ForEach(scanner.availableDevices) { device in
                            Text(device.name).tag(device.uid)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 220)
                }

                Divider()

                SettingToggleWithInfo(
                    title: "Trim Leading/Trailing Silence",
                    info: "Removes silent audio from the beginning and end of each recording before sending it to Whisper. Reduces the chance of hallucinated words in the silent gaps and can marginally improve speed on short utterances.",
                    isOn: $settings.enableSilenceTrim
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
