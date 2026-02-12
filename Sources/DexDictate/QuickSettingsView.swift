import SwiftUI

/// Collapsible settings panel embedded in the main popover.
///
/// Organised into three sections: **Feedback** (sound-effect pickers), **Output**
/// (Auto-Paste and profanity-filter toggles), and **Input** (`ShortcutRecorder`).
/// Changing a sound picker immediately previews the selection via `SoundPlayer`.
struct QuickSettingsView: View {
    @ObservedObject var settings: Settings
    @State private var inputDevices: [AudioInputDevice] = []

    var body: some View {
        DisclosureGroup("Quick Settings") {
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 12) {
                    // Feedback Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Feedback (Sound Effects)").font(.caption).bold().foregroundStyle(.white.opacity(0.7))

                        HStack {
                            Text("Play Start:")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Picker("", selection: $settings.selectedStartSound) {
                                ForEach(Settings.SystemSound.allCases) { sound in
                                    Text(sound.rawValue).tag(sound)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                            .fixedSize()
                            .onChange(of: settings.selectedStartSound) { _, newValue in
                                SoundPlayer.play(newValue)
                            }
                        }

                        HStack {
                            Text("Play Stop:")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Picker("", selection: $settings.selectedStopSound) {
                                ForEach(Settings.SystemSound.allCases) { sound in
                                    Text(sound.rawValue).tag(sound)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                            .fixedSize()
                            .onChange(of: settings.selectedStopSound) { _, newValue in
                                SoundPlayer.play(newValue)
                            }
                        }
                    }

                    Divider().background(Color.white.opacity(0.3))

                    // Output Section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Output").font(.caption).bold().foregroundStyle(.white.opacity(0.7))

                        Toggle("Auto-Paste", isOn: $settings.autoPaste)
                        Text("Automatically pastes text into the active app.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20)
                            .padding(.bottom, 2)

                        Toggle("Filter Profanity", isOn: $settings.profanityFilter)
                    }

                    Divider().background(Color.white.opacity(0.3))

                    // Input Configuration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Input")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.white.opacity(0.7))

                        HStack {
                            Text("Input Device:")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Picker("", selection: $settings.inputDeviceUID) {
                                Text("System Default").tag("")
                                ForEach(inputDevices) { device in
                                    Text(device.name).tag(device.uid)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                            .fixedSize()
                        }

                        Text("Applies the next time dictation starts.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ShortcutRecorder(shortcut: $settings.userShortcut)
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
        }
        .accentColor(.white)
        .padding(.horizontal)
        .onAppear {
            inputDevices = AudioDeviceManager.inputDevices()
        }
    }
}
