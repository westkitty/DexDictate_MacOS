import SwiftUI
import AppKit
import DexDictateKit

/// Collapsible settings panel embedded in the main popover.
struct QuickSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var scanner: AudioDeviceScanner
    @ObservedObject var vocabularyManager: VocabularyManager
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Clickable header — the entire row toggles expansion (not just the chevron).
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 24, height: 24)
                        .background(Color.cyan.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Quick Settings", comment: ""))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(isExpanded ? "Tuning and device controls are open." : "Show tuning, device, and output controls.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(SurfaceTokens.cardPadding)
                .background(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius)
                        .stroke(Color.white.opacity(isExpanded ? 0.18 : 0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse quick settings" : "Expand quick settings")

        if isExpanded {
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: SurfaceTokens.sectionSpacing) {
                    
                    // MARK: - Feedback Section (Sound Effects)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Feedback (Sound Effects)", comment: ""))
                            .font(.caption).bold().foregroundStyle(.white.opacity(0.7))

                        Toggle(NSLocalizedString("Play Start Sound", comment: ""), isOn: $settings.playStartSound)

                        if settings.playStartSound {
                            HStack {
                                Text(NSLocalizedString("Start Sound:", comment: ""))
                                    .font(.caption).foregroundStyle(.white.opacity(0.8))
                                Spacer()
                                Picker("", selection: $settings.selectedStartSound) {
                                    ForEach(AppSettings.SystemSound.allCases) { sound in
                                        Text(sound.rawValue).tag(sound)
                                    }
                                }
                                .labelsHidden().frame(width: 120).fixedSize()
                                .onChange(of: settings.selectedStartSound) { _, newValue in
                                    SoundPlayer.play(newValue)
                                }
                            }
                            .padding(.leading, 20)
                        }

                        Toggle(NSLocalizedString("Play Stop Sound", comment: ""), isOn: $settings.playStopSound)

                        if settings.playStopSound {
                            HStack {
                                Text(NSLocalizedString("Stop Sound:", comment: ""))
                                    .font(.caption).foregroundStyle(.white.opacity(0.8))
                                Spacer()
                                Picker("", selection: $settings.selectedStopSound) {
                                    ForEach(AppSettings.SystemSound.allCases) { sound in
                                        Text(sound.rawValue).tag(sound)
                                    }
                                }
                                .labelsHidden().frame(width: 120).fixedSize()
                                .onChange(of: settings.selectedStopSound) { _, newValue in
                                    SoundPlayer.play(newValue)
                                }
                            }
                            .padding(.leading, 20)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.3))
                    
                    // MARK: - Appearance Section
                    HStack {
                         Text(NSLocalizedString("Appearance:", comment: ""))
                             .font(.caption).foregroundStyle(.white.opacity(0.8))
                         Spacer()
                         Picker("", selection: $settings.appearanceTheme) {
                             ForEach(AppSettings.AppearanceTheme.allCases) { theme in
                                 Text(theme.rawValue).tag(theme)
                             }
                         }
                         .labelsHidden().frame(width: 120).fixedSize()
                         .onChange(of: settings.appearanceTheme) { _, newValue in
                             settings.appearanceThemeStored = newValue.rawValue
                         }
                    }

                    Divider().background(Color.white.opacity(0.3))
                    
                    // MARK: - Output Section
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Output", comment: ""))
                            .font(.caption).bold().foregroundStyle(.white.opacity(0.7))

                        Toggle(
                            NSLocalizedString("Safe Mode", comment: ""),
                            isOn: Binding(
                                get: { settings.safeModeEnabled },
                                set: { enabled in
                                    if enabled {
                                        settings.enableSafeMode()
                                    } else {
                                        settings.disableSafeMode()
                                    }
                                }
                            )
                        )
                        Text(NSLocalizedString("Turns off auto-paste, sound cues, and toggle-style triggering until you turn it back off.", comment: ""))
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20).padding(.bottom, 2)

                        Toggle(NSLocalizedString("Auto-Paste", comment: ""), isOn: $settings.autoPaste)
                        Text(NSLocalizedString("Automatically pastes text into the active app.", comment: ""))
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20).padding(.bottom, 2)

                        Toggle(NSLocalizedString("Filter Profanity", comment: ""), isOn: $settings.profanityFilter)
                        
                        Toggle(NSLocalizedString("Show Floating HUD", comment: ""), isOn: $settings.showFloatingHUD)
                    }

                    Divider().background(Color.white.opacity(0.3))

                    // MARK: - Input Configuration
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Input", comment: ""))
                            .font(.caption).bold().foregroundStyle(.white.opacity(0.7))

                        HStack {
                            Text(NSLocalizedString("Input Device:", comment: ""))
                                .font(.caption).foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Picker("", selection: $settings.inputDeviceUID) {
                                Text(NSLocalizedString("System Default", comment: "")).tag("")
                                ForEach(scanner.availableDevices) { device in
                                    Text(device.name).tag(device.uid)
                                }
                            }
                            .labelsHidden().frame(width: 180).fixedSize()
                        }

                        // Silence Detection
                        HStack {
                            Text(NSLocalizedString("Silence Timeout:", comment: ""))
                                .font(.caption).foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            HStack(spacing: 8) {
                                Slider(value: $settings.silenceTimeout, in: 0...10, step: 0.5)
                                    .tint(.blue)
                                    .frame(maxWidth: 60)
                                TextField("0.0", value: $settings.silenceTimeout, format: .number)
                                    .font(.caption2)
                                    .frame(width: 40)
                                    .textFieldStyle(.roundedBorder)
                                Text("s").font(.caption2).foregroundStyle(.secondary)
                            }
                        }

                        Text(NSLocalizedString("Applies the next time dictation starts.", comment: ""))
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                            
                        Divider().background(Color.white.opacity(0.3))
                        
                        HStack {
                             Text(NSLocalizedString("Custom Vocabulary", comment: ""))
                                 .font(.caption).bold().foregroundStyle(.white.opacity(0.7))
                             Spacer()
                             Button(NSLocalizedString("Manage...", comment: "")) {
                                 openVocabularyWindow()
                             }
                             .buttonStyle(.bordered)
                             .controlSize(.small)
                        }
                    }

                    ShortcutRecorder(shortcut: $settings.userShortcut)
                }
            }
            .padding(SurfaceTokens.cardPadding)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
        } // end if isExpanded
        } // end VStack
        .padding(.horizontal)
    }
    
    // Retain the vocabulary window so we can reuse it instead of creating duplicates.
    @State private var vocabularyWindow: NSWindow?

    private func openVocabularyWindow() {
        if let existing = vocabularyWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let view = VocabularySettingsView(vocabularyManager: vocabularyManager)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = NSLocalizedString("Custom Vocabulary", comment: "")
        window.setContentSize(NSSize(width: 400, height: 300))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        vocabularyWindow = window
    }
}
