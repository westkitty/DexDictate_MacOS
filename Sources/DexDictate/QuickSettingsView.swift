import SwiftUI
import AppKit
import DexDictateKit

/// Collapsible settings panel embedded in the main popover.
struct QuickSettingsView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var settings: AppSettings
    @ObservedObject var scanner: AudioDeviceScanner
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var benchmarkCaptureController: BenchmarkCaptureWindowController
    @ObservedObject var vocabularyManager: VocabularyManager
    @ObservedObject var menuBarIconController: MenuBarIconController
    @ObservedObject var modelCatalog: WhisperModelCatalog
    @ObservedObject var adaptiveBenchmarkController: AdaptiveBenchmarkController
    @ObservedObject var benchmarkResultsStore: BenchmarkResultsStore
    @State private var isExpanded = false
    @StateObject private var launchAtLoginController = LaunchAtLoginController()

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
                        Text(NSLocalizedString("Mode", comment: ""))
                            .font(.caption).bold().foregroundStyle(.white.opacity(0.7))

                        HStack {
                            Text(NSLocalizedString("Profile:", comment: ""))
                                .font(.caption).foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Picker("", selection: Binding(
                                get: { profileManager.activeProfile },
                                set: { newValue in
                                    profileManager.selectProfile(newValue)
                                    profileManager.synchronizeBundledVocabulary(with: vocabularyManager)
                                    profileManager.refreshDynamicContent()
                                }
                            )) {
                                ForEach(AppProfile.allCases) { profile in
                                    Text(profile.title).tag(profile)
                                }
                            }
                            .labelsHidden().frame(width: 120).fixedSize()
                        }

                        if profileManager.activeProfile != .standard {
                            Button("Return to Standard") {
                                profileManager.returnToStandard()
                                profileManager.synchronizeBundledVocabulary(with: vocabularyManager)
                                profileManager.refreshDynamicContent()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Toggle(NSLocalizedString("Show Flavor Ticker", comment: ""), isOn: $settings.showFlavorTicker)
                        Toggle(NSLocalizedString("Animate Flavor Ticker", comment: ""), isOn: $settings.animateFlavorTicker)

                        Text(NSLocalizedString("Ticker motion still yields to macOS Reduce Motion even when animation stays enabled here.", comment: ""))
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20)
                    }

                    Divider().background(Color.white.opacity(0.3))

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

                        Toggle(NSLocalizedString("Copy Only in Sensitive Fields", comment: ""), isOn: $settings.copyOnlyInSensitiveFields)
                        Text(NSLocalizedString("If the focused field looks like a password, passcode, token, or other secure input, DexDictate will copy the result without auto-pasting it.", comment: ""))
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20).padding(.bottom, 2)

                        Toggle(NSLocalizedString("Insert without clipboard (Accessibility)", comment: ""), isOn: $settings.useAccessibilityInsertion)
                            .toggleStyle(.switch)
                            .font(.caption)
                        Text(NSLocalizedString("Inserts dictation text directly into the focused field without overwriting your clipboard. Falls back to normal paste if the field doesn't support it.", comment: ""))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20).padding(.bottom, 2)

                        Toggle(NSLocalizedString("Filter Profanity", comment: ""), isOn: $settings.profanityFilter)

                        Toggle(NSLocalizedString("Show Floating HUD", comment: ""), isOn: $settings.showFloatingHUD)

                        Toggle(NSLocalizedString("Trim trailing silence", comment: ""), isOn: $settings.enableTrailingTrimExperiment)
                            .toggleStyle(.switch)
                            .font(.caption)
                        Text(NSLocalizedString("Removes silent audio at the end of each recording before transcription — reduces Whisper processing time.", comment: ""))
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20).padding(.bottom, 2)

                        Toggle(NSLocalizedString("Trim leading silence (experimental)", comment: ""), isOn: $settings.enableOnsetTrim)
                            .toggleStyle(.switch)
                            .font(.caption)
                        Text(NSLocalizedString("Detects and removes silence at the start of recordings. May clip quiet speech — test before enabling.", comment: ""))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20).padding(.bottom, 2)

                        Toggle(NSLocalizedString("Use context from focused field", comment: ""), isOn: $settings.enableContextInjection)
                            .toggleStyle(.switch)
                            .font(.caption)
                        Text(NSLocalizedString("Reads your active text field to improve transcription accuracy for proper nouns and continuing sentences. Requires Accessibility permission.", comment: ""))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20).padding(.bottom, 2)
                    }

                    Divider().background(Color.white.opacity(0.3))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("System", comment: ""))
                            .font(.caption).bold().foregroundStyle(.white.opacity(0.7))

                        Toggle(
                            NSLocalizedString("Launch at Login", comment: ""),
                            isOn: Binding(
                                get: { launchAtLoginController.isEnabled },
                                set: { newValue in
                                    launchAtLoginController.setEnabled(newValue)
                                    launchAtLoginController.syncStoredPreference(into: settings)
                                }
                            )
                        )
                        .disabled(!launchAtLoginController.canAttemptRegistration)

                        Text(launchAtLoginController.statusMessage)
                            .font(.caption2)
                            .foregroundStyle(launchAtLoginController.lastError == nil ? .white.opacity(0.5) : .red.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20)
                            .padding(.bottom, launchAtLoginController.needsSystemApproval ? 2 : 0)

                        if launchAtLoginController.needsSystemApproval {
                            Button("Open Login Items Settings") {
                                launchAtLoginController.openSystemSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .padding(.leading, 20)
                        }
                    }

                    Divider().background(Color.white.opacity(0.3))

                    MenuBarSettingsSection(
                        settings: settings,
                        menuBarIconController: menuBarIconController
                    )

                    Divider().background(Color.white.opacity(0.3))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Benchmark", comment: ""))
                            .font(.caption).bold().foregroundStyle(.white.opacity(0.7))

                        Text("Open the local capture tool to record the strict corpus, then benchmark it with the existing scripts.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Open Benchmark Capture") {
                            benchmarkCaptureController.show(engine: engine)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if let sessionDirectory = benchmarkCaptureController.sessionDirectory {
                            Button("Open Captured Corpus") {
                                benchmarkCaptureController.openCorpusFolder()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Text(sessionDirectory.lastPathComponent)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.45))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Divider().background(Color.white.opacity(0.3))

                        Text("Optimization")
                            .font(.caption).bold().foregroundStyle(.white.opacity(0.7))

                        HStack {
                            Text("Active Model:")
                                .font(.caption).foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Picker("", selection: $settings.activeWhisperModelID) {
                                ForEach(modelCatalog.availableModels) { model in
                                    Text(model.displayName).tag(model.id)
                                }
                            }
                            .labelsHidden().frame(width: 150).fixedSize()
                        }

                        HStack {
                            Text("Model Selection:")
                                .font(.caption).foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Picker("", selection: $settings.modelSelectionMode) {
                                ForEach(AppSettings.ModelSelectionMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .labelsHidden().frame(width: 150).fixedSize()
                        }

                        HStack {
                            Text("End Preset:")
                                .font(.caption).foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Picker("", selection: $settings.utteranceEndPreset) {
                                ForEach(AppSettings.UtteranceEndPreset.allCases) { preset in
                                    Text(preset.rawValue).tag(preset)
                                }
                            }
                            .labelsHidden().frame(width: 150).fixedSize()
                        }

                        Toggle("Accuracy Retry", isOn: $settings.enableAccuracyRetry)
                        Toggle("Correction Sheet", isOn: $settings.enableCorrectionSheet)

                        HStack {
                            Button("Import Model") {
                                _ = modelCatalog.importModelFromOpenPanel()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Run Benchmarks Now") {
                                adaptiveBenchmarkController.runBenchmarksNow()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(adaptiveBenchmarkController.status.isBusy || !(engine.state == .ready || engine.state == .stopped))

                            Button("Restore Stable Defaults") {
                                settings.restoreStableDictationDefaults()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Text(adaptiveBenchmarkController.status.description)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)

                        if let importError = modelCatalog.lastImportError {
                            Text(importError)
                                .font(.caption2)
                                .foregroundStyle(.orange.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        BenchmarkResultsSection(
                            settings: settings,
                            modelCatalog: modelCatalog,
                            benchmarkResultsStore: benchmarkResultsStore,
                            adaptiveBenchmarkController: adaptiveBenchmarkController
                        )
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

                        Text(NSLocalizedString("Advanced end-of-utterance controls live in Benchmark optimization so the default surface stays honest.", comment: ""))
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)

                        if let recoveryNotice = scanner.recoveryNotice {
                            Text(recoveryNotice)
                                .font(.caption2)
                                .foregroundStyle(.orange.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                            
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
        .onAppear {
            launchAtLoginController.refresh()
            launchAtLoginController.syncStoredPreference(into: settings)
            menuBarIconController.refreshAssets()
            profileManager.synchronizeBundledVocabulary(with: vocabularyManager)
            modelCatalog.refresh()
            benchmarkResultsStore.reload()
        }
        .onChange(of: settings.launchAtLogin) { _, _ in
            launchAtLoginController.refresh()
            launchAtLoginController.syncStoredPreference(into: settings)
        }
        .onChange(of: settings.inputDeviceUID) { _, _ in
            scanner.refreshDevices()
        }
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

private struct MenuBarSettingsSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var menuBarIconController: MenuBarIconController
    @State private var isEmojiPickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("Menu Bar Style", comment: ""))
                .font(.caption).bold().foregroundStyle(.white.opacity(0.7))

            Text("Default is the native microphone plus \"DexDictate.\" Switch to mic-only, a Dex icon, or an emoji icon. Dex icons now render larger and pulse with a recording badge while listening.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text("Style")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer(minLength: 8)

                Picker("", selection: $settings.menuBarDisplayMode) {
                    ForEach(AppSettings.MenuBarDisplayMode.allCases) { mode in
                        Text(displayLabel(for: mode)).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
            }

            MenuBarDisplayPreview(
                mode: settings.menuBarDisplayMode,
                dexImage: selectedDexPreview,
                logoImage: menuBarIconController.appLogoPreviewImage(),
                emoji: settings.selectedMenuBarEmoji
            )

            switch settings.menuBarDisplayMode {
            case .customIcon:
                dexIconSection
            case .logoOnly:
                logoOnlySection
            case .emojiIcon:
                emojiIconSection
            case .micAndText, .micOnly:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedDexPreview: NSImage? {
        menuBarIconController
            .selectedIcon(using: settings)
            .flatMap(menuBarIconController.previewImage(for:))
    }

    private var dexIconSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dex icons are converted into monochrome template images so they behave like native macOS menu bar icons.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)

            if menuBarIconController.icons.isEmpty {
                Text("No Dex icons were found at \(menuBarIconController.assetDirectoryURL.path).")
                    .font(.caption2)
                    .foregroundStyle(.orange.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(alignment: .center, spacing: 10) {
                    MenuBarIconPreview(image: selectedDexPreview)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.selectedMenuBarIconIdentifier.isEmpty ? "No Dex icon selected" : "Dex icon active")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(settings.selectedMenuBarIconIdentifier.isEmpty ? "Pick one of the Dex icons below." : "DexDictate will render the selected Dex icon as a menu bar icon.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    Spacer()

                    Menu {
                        ForEach(Array(menuBarIconController.icons.enumerated()), id: \.element.id) { index, icon in
                            Button {
                                settings.selectMenuBarIcon(identifier: icon.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: settings.selectedMenuBarIconIdentifier == icon.id ? "checkmark.circle.fill" : "circle")

                                    if let previewImage = menuBarIconController.previewImage(for: icon) {
                                        Image(nsImage: previewImage)
                                            .resizable()
                                            .interpolation(.high)
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                    }

                                    Text("DexDictate \(index + 1)")
                                        .lineLimit(1)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Choose")
                                .font(.caption.weight(.semibold))
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(8)
                .background(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
            }
        }
    }

    private var emojiIconSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose an emoji for the menu bar. The emoji keeps its color and gets the same pulsing red recording badge while listening.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: 10) {
                MenuBarIconPreview(image: nil, emoji: settings.selectedMenuBarEmoji)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Emoji icon active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Current emoji: \(settings.selectedMenuBarEmoji)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                Button("Choose Emoji") {
                    isEmojiPickerPresented = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $isEmojiPickerPresented, arrowEdge: .top) {
                    EmojiIconPicker(
                        selectedEmoji: Binding(
                            get: { settings.selectedMenuBarEmoji },
                            set: { settings.selectMenuBarEmoji($0) }
                        ),
                        isPresented: $isEmojiPickerPresented
                    )
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
        }
    }

    private var logoOnlySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Logo Only uses the bundled DexDictate mark as the menu bar icon. It stays monochrome and gets the same recording indicator while active.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: 10) {
                MenuBarIconPreview(image: menuBarIconController.appLogoPreviewImage())

                VStack(alignment: .leading, spacing: 2) {
                    Text("DexDictate logo active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Uses the bundled app logo without extra text.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()
            }
            .padding(8)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
        }
    }

    private func displayLabel(for mode: AppSettings.MenuBarDisplayMode) -> String {
        switch mode {
        case .micAndText:
            return "Mic + Text"
        case .micOnly:
            return "Mic Only"
        case .customIcon:
            return "Dex Icon"
        case .logoOnly:
            return "Logo Only"
        case .emojiIcon:
            return "Emoji"
        }
    }
}

private struct BenchmarkResultsSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var modelCatalog: WhisperModelCatalog
    @ObservedObject var benchmarkResultsStore: BenchmarkResultsStore
    @ObservedObject var adaptiveBenchmarkController: AdaptiveBenchmarkController

    private var currentResults: [ModelBenchmarkResult] {
        benchmarkResultsStore.latestResultsForCurrentEnvironment(settings: settings)
    }

    private var activeResult: ModelBenchmarkResult? {
        guard let descriptor = modelCatalog.activeDescriptor(settings: settings) else { return nil }
        return benchmarkResultsStore.latestResult(for: descriptor, settings: settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Benchmark Results")
                .font(.caption).bold().foregroundStyle(.white.opacity(0.7))

            if !adaptiveBenchmarkController.progressEntries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Run")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))

                    ForEach(adaptiveBenchmarkController.progressEntries) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(progressColor(for: entry.state))
                                .frame(width: 7, height: 7)
                                .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.modelID)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                Text(entry.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let activeResult {
                resultCard(
                    title: "Active: \(activeResult.modelID)",
                    result: activeResult,
                    emphasized: true
                )
            } else {
                Text("No cached benchmark results for the current preset yet.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(currentResults.filter { $0.modelID != activeResult?.modelID }.prefix(3)) { result in
                resultCard(title: result.modelID, result: result, emphasized: false)
            }
        }
    }

    @ViewBuilder
    private func resultCard(title: String, result: ModelBenchmarkResult, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(emphasized ? 0.9 : 0.8))

            Text("WER \(formatPercent(result.averageWER)) · avg \(Int(result.averageLatencyMs))ms · p95 \(Int(result.p95LatencyMs))ms")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.65))

            Text("\(result.decodeProfile) · \(result.utteranceEndPreset) · \(result.completedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(10)
        .background(Color.white.opacity(emphasized ? 0.06 : 0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(emphasized ? 0.14 : 0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatPercent(_ value: Double) -> String {
        let percentage = value * 100
        return String(format: "%.1f%%", percentage)
    }

    private func progressColor(for state: BenchmarkProgressState) -> Color {
        switch state {
        case .queued:
            return .white.opacity(0.55)
        case .running:
            return .yellow
        case .cached:
            return .cyan
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .orange
        }
    }
}

private struct MenuBarIconPreview: View {
    let image: NSImage?
    let emoji: String?

    init(image: NSImage?, emoji: String? = nil) {
        self.image = image
        self.emoji = emoji
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.96), Color(red: 0.86, green: 0.88, blue: 0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(4)
            } else if let emoji {
                Text(emoji)
                    .font(.system(size: 24))
            } else {
                RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius)
                    .stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))

                Image(systemName: "questionmark.square.dashed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(width: 38, height: 38)
    }
}

private struct MenuBarDisplayPreview: View {
    let mode: AppSettings.MenuBarDisplayMode
    let dexImage: NSImage?
    let logoImage: NSImage?
    let emoji: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.96), Color(red: 0.86, green: 0.88, blue: 0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                previewContent
                    .foregroundStyle(.black.opacity(0.88))
                    .padding(.horizontal, 10)
            }
            .frame(height: 34)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch mode {
        case .micAndText:
            HStack(spacing: 4) {
                Image(systemName: "mic.fill")
                    .font(.caption.weight(.semibold))
                Text("DexDictate")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
        case .micOnly:
            Image(systemName: "mic.fill")
                .font(.caption.weight(.semibold))
        case .customIcon:
            if let dexImage {
                Image(nsImage: dexImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            } else {
                HStack(spacing: 4) {
                    Text("Dex")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
            }
        case .logoOnly:
            if let logoImage {
                Image(nsImage: logoImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            } else {
                Text("Logo")
                    .font(.caption.weight(.semibold))
            }
        case .emojiIcon:
            Text(emoji)
                .font(.system(size: 20))
        }
    }
}

private struct EmojiIconPicker: View {
    @Binding var selectedEmoji: String
    @Binding var isPresented: Bool
    @State private var draftEmoji: String

    private let suggestedEmojis = [
        "🐶", "🎙️", "🎤", "🗣️", "🐾", "🦴", "🐕", "🐺",
        "🦊", "🐱", "🤖", "🎧", "📣", "✨", "⚡", "🔥",
        "⭐", "🫡", "🎯", "🧠", "🛸", "🚀", "💬", "📝"
    ]

    init(selectedEmoji: Binding<String>, isPresented: Binding<Bool>) {
        _selectedEmoji = selectedEmoji
        _isPresented = isPresented
        _draftEmoji = State(initialValue: selectedEmoji.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick an Emoji")
                .font(.headline)

            Text("Click one of the suggestions or paste any emoji below.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Paste any emoji", text: $draftEmoji)
                .textFieldStyle(.roundedBorder)

            Button("Use Entered Emoji") {
                let trimmed = draftEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                selectedEmoji = trimmed
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(suggestedEmojis, id: \.self) { emoji in
                    Button {
                        draftEmoji = emoji
                        selectedEmoji = emoji
                        isPresented = false
                    } label: {
                        Text(emoji)
                            .font(.system(size: 26))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}
