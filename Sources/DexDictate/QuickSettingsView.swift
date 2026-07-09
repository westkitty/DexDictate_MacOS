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
    @Binding var isExpanded: Bool
    @StateObject private var launchAtLoginController = LaunchAtLoginController()
    @State private var profanityAdditionsText: String = ""
    @State private var profanityRemovalsText: String = ""
    @State private var inputPanelExpanded = false
    @State private var outputPanelExpanded = false
    @State private var accuracyPanelExpanded = false
    @State private var transcriptionProvidersPanelExpanded = false
    @State private var profilePanelExpanded = false
    @State private var appearancePanelExpanded = false
    @State private var routeHealthExpanded = false
    @State private var contextBiasExpanded = false
    @State private var benchmarkPanelExpanded = false
    @State private var experimentalPanelExpanded = false
    @State private var advancedPanelExpanded = false
    @State private var isResettingCoreAudio = false
    @State private var coreAudioResetStatus: String?
    private let coreAudioResetService = CoreAudioResetService()

    var body: some View {
        VStack(spacing: 0) {
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
                        Text(isExpanded ? "Pinned controls stay visible. Deeper tuning is folded into panels." : "Show pinned controls and folded panels.")
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
                VStack(spacing: 10) {
                    pinnedControlsStrip

                    QuickSettingsDisclosureCard(
                        title: "Input",
                        subtitle: "Devices, trigger behavior, route recovery, and capture controls.",
                        systemImage: "mic.fill",
                        isExpanded: $inputPanelExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            controlRow(label: "Input Device") {
                                Picker("", selection: $settings.inputDeviceUID) {
                                    Text("System Default").tag("")
                                    ForEach(scanner.availableDevices) { device in
                                        Text(device.name).tag(device.uid)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(width: 180)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Silence Timeout")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                    Spacer()
                                    Text(settings.silenceTimeout == 0 ? "Disabled" : "\(Int(settings.silenceTimeout))s")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                Slider(value: $settings.silenceTimeout, in: 0...15, step: 1)
                                    .tint(.cyan)
                            }

                                    SettingToggleWithInfo(
                                title: "Pause browser media during dictation",
                                info: "Pauses video and audio in Chrome, Brave, or Edge tabs when recording starts, then resumes them when you stop. macOS will ask for Automation permission the first time it runs. Skips automatically when Zoom is active. Safari and Firefox are not supported.",
                                isOn: $settings.pauseBrowserMediaDuringDictation
                            )

                            DisclosureGroup("Route Health", isExpanded: $routeHealthExpanded) {
                                VStack(alignment: .leading, spacing: 8) {
                                    QuickSettingsSummaryValue(
                                        label: "Active Input",
                                        value: engine.routeHealthSnapshot.activeInputLabel
                                    )
                                    QuickSettingsSummaryValue(
                                        label: "Recoveries",
                                        value: "\(engine.routeHealthSnapshot.recoveryCount)"
                                    )
                                    QuickSettingsSummaryValue(
                                        label: "Last Recovery",
                                        value: routeRecoveryStatusLabel
                                    )

                                    if let recoveryNotice = scanner.recoveryNotice {
                                        Text(recoveryNotice)
                                            .font(.caption2)
                                            .foregroundStyle(.orange.opacity(0.9))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Text(engine.routeHealthSnapshot.detail)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.top, 8)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))

                            HStack {
                                Button("Custom Vocabulary") {
                                    openVocabularyWindow()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button("Voice Commands") {
                                    openCustomCommandsWindow()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            ShortcutRecorder(shortcut: $settings.userShortcut)
                        }
                    }

                    QuickSettingsDisclosureCard(
                        title: "Output",
                        subtitle: "Insertion rules, safety behavior, and post-dictation delivery.",
                        systemImage: "square.and.arrow.down",
                        isExpanded: $outputPanelExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Safe Mode", isOn: safeModeBinding)
                            Toggle("Auto-Paste", isOn: $settings.autoPaste)
                            Toggle("Copy Only in Sensitive Fields", isOn: $settings.copyOnlyInSensitiveFields)
                            Toggle("Use Accessibility API for Insertion", isOn: $settings.useAccessibilityInsertion)
                            Toggle("Show Floating HUD", isOn: $settings.showFloatingHUD)
                            Toggle("Filter Profanity", isOn: $settings.profanityFilter)

                            if settings.profanityFilter {
                                VStack(alignment: .leading, spacing: 6) {
                                    let bundled = ProfanityFilter.bundledWordCount
                                    let custom = settings.customProfanityWords.count
                                    Text("Filtering \(bundled + custom) words (\(bundled) bundled + \(custom) custom)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))

                                    Text("Add words to filter (comma-separated)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                    TextEditor(text: $profanityAdditionsText)
                                        .font(.caption2)
                                        .frame(height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))

                                    Text("Un-filter bundled words (comma-separated)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                    TextEditor(text: $profanityRemovalsText)
                                        .font(.caption2)
                                        .frame(height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Per-App Insertion Rules")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.82))
                                    Text("Use app-specific presets and insertion overrides without bloating the main surface.")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                }

                                Spacer()

                                Button("Manage...") {
                                    openPerAppInsertionWindow()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }

                    QuickSettingsDisclosureCard(
                        title: "Accuracy & Speed",
                        subtitle: "Model choice, tail timing, smart retry, and hidden context biasing.",
                        systemImage: "speedometer",
                        isExpanded: $accuracyPanelExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            controlRow(label: "Active Model") {
                                Picker("", selection: $settings.activeWhisperModelID) {
                                    ForEach(modelCatalog.availableModels) { model in
                                        Text(model.displayName).tag(model.id)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(width: 180)
                            }

                            if let availabilityWarning = modelCatalog.availabilityWarning {
                                Text(availabilityWarning)
                                    .font(.caption2)
                                    .foregroundStyle(.orange.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            controlRow(label: "Model Selection") {
                                Picker("", selection: $settings.modelSelectionMode) {
                                    ForEach(AppSettings.ModelSelectionMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(width: 180)
                            }

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

                            SettingToggleWithInfo(
                                title: "Trim Leading/Trailing Silence",
                                info: "Removes silent audio from the beginning and end of each recording before sending it to Whisper. Reduces the chance of hallucinated words in the silent gaps and can marginally improve speed on short utterances.",
                                isOn: $settings.enableSilenceTrim
                            )

                            SettingToggleWithInfo(
                                title: "Trailing Trim Experiment",
                                info: "An experimental variation that trims silence only at the end of the recording, after your last spoken word. May improve accuracy on the final word of an utterance by preventing Whisper from continuing to 'hear' noise after speech ends. Best used alongside Trim Leading/Trailing Silence.",
                                isOn: $settings.enableTrailingTrimExperiment
                            )

                            SettingToggleWithInfo(
                                title: "Accuracy Retry",
                                info: "When transcription produces a suspiciously short or low-confidence result, DexDictate silently re-runs Whisper on the same audio at a higher quality level. Costs extra processing time but catches utterances where the first pass stumbled.",
                                isOn: $settings.enableAccuracyRetry
                            )

                            if settings.enableAccuracyRetry {
                                SettingToggleWithInfo(
                                    title: "Retry Suspicious Results Automatically",
                                    info: "When Accuracy Retry is on, this fires the retry without asking you first. Turn it off if you'd rather decide manually — you'll see a 'Retry Last in Accuracy Mode' button after each suspicious result instead.",
                                    isOn: $settings.autoRetrySuspiciousResults
                                )
                                .padding(.leading, 16)
                            }

                            SettingToggleWithInfo(
                                title: "Correction Sheet",
                                info: "After each dictation, shows a compact review sheet where you can confirm, edit, or reject the transcript before it gets inserted. Adds one extra step but lets you catch mistakes before they reach the target app.",
                                isOn: $settings.enableCorrectionSheet
                            )

                            SettingToggleWithInfo(
                                title: "Use Context From Focused Field",
                                info: "Reads the text you're currently editing (via the Accessibility API) and uses it to prime Whisper, improving accuracy for proper nouns and continuing sentences. Combined with DexDictate's vocabulary biasing. Off by default; requires Accessibility permission.",
                                isOn: $settings.enableContextInjection
                            )

                            DisclosureGroup("Context Biasing", isExpanded: $contextBiasExpanded) {
                                VStack(alignment: .leading, spacing: 8) {
                                    controlRow(label: "Bias Mode") {
                                        Picker("", selection: $settings.dictationDomainMode) {
                                            ForEach(AppSettings.DictationDomainMode.allCases) { mode in
                                                Text(mode.rawValue).tag(mode)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.menu)
                                        .frame(width: 180)
                                    }

                                    Text("Automatic detects which app is in focus and applies a light domain-specific vocabulary hint — coding terms for Xcode, email phrasing for Mail, chat style for Slack. Manual lets you pin a domain yourself. Off disables all biasing. Everything runs locally; no text leaves your machine.")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.top, 8)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))

                            DisclosureGroup("Benchmarks & Corpus", isExpanded: $benchmarkPanelExpanded) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Open the local capture tool to record the strict corpus, then benchmark it with the existing scripts.")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                        .fixedSize(horizontal: false, vertical: true)

                                    HStack {
                                        Button("Open Benchmark Capture") {
                                            openBenchmarkCapture()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)

                                        Button("Import Model") {
                                            importModel()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }

                                    HStack {
                                        Button("Run Benchmarks Now") {
                                            runBenchmarksNow()
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
                                .padding(.top, 8)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                        }
                    }

                    QuickSettingsDisclosureCard(
                        title: "Transcription Engines",
                        subtitle: "Live-preview captions, command detection, and which engine dictates.",
                        systemImage: "waveform.badge.mic",
                        isExpanded: $transcriptionProvidersPanelExpanded
                    ) {
                        LiveTranscriptionStatusView(
                            settings: settings,
                            registry: engine.transcriptionProviderRegistry,
                            modelCatalog: modelCatalog
                        )
                    }

                    QuickSettingsDisclosureCard(
                        title: "Profiles & History",
                        subtitle: "Flavor profile, ticker behavior, stats, and persistence.",
                        systemImage: "person.text.rectangle",
                        isExpanded: $profilePanelExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            controlRow(label: "Profile") {
                                Picker("", selection: profileBinding) {
                                    ForEach(AppProfile.allCases) { profile in
                                        Text(profile.title).tag(profile)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(width: 160)
                            }

                            if profileManager.activeProfile != .standard {
                                Button("Return to Standard") {
                                    returnToStandardProfile()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            Toggle("Show Flavor Ticker", isOn: $settings.showFlavorTicker)
                            Toggle("Animate Flavor Ticker", isOn: $settings.animateFlavorTicker)
                            Toggle("Show Dictation Stats", isOn: $settings.showDictationStats)
                            Toggle("Persist History Across Sessions", isOn: $settings.persistHistory)

                            Text("Ticker motion still yields to macOS Reduce Motion even when animation stays enabled here. Stats show word count, session duration, and words per minute for the current session.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    QuickSettingsDisclosureCard(
                        title: "Appearance & System",
                        subtitle: "Sounds, theme, menu bar style, and launch behavior.",
                        systemImage: "paintpalette.fill",
                        isExpanded: $appearancePanelExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            controlRow(label: "Appearance") {
                                Picker("", selection: $settings.appearanceTheme) {
                                    ForEach(AppSettings.AppearanceTheme.allCases) { theme in
                                        Text(theme.rawValue).tag(theme)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(width: 150)
                            }

                            controlRow(label: "Status Color") {
                                HStack(spacing: 8) {
                                    ColorPicker(
                                        "",
                                        selection: Binding(
                                            get: { settings.statusAccentColor },
                                            set: { settings.statusAccentColor = $0 }
                                        ),
                                        supportsOpacity: false
                                    )
                                    .labelsHidden()
                                    .accessibilityLabel("Dictation status accent color")

                                    Button("Reset") {
                                        settings.resetStatusAccentColor()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(settings.statusAccentColorHex.isEmpty)
                                    .accessibilityLabel("Reset status color to default")
                                }
                            }

                            Toggle("Play Start Sound", isOn: $settings.playStartSound)
                            if settings.playStartSound {
                                controlRow(label: "Start Sound") {
                                    Picker("", selection: $settings.selectedStartSound) {
                                        ForEach(AppSettings.SystemSound.allCases) { sound in
                                            Text(sound.rawValue).tag(sound)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                    .frame(width: 150)
                                    .onChange(of: settings.selectedStartSound) { _, newValue in
                                        SoundPlayer.play(newValue)
                                    }
                                }
                            }

                            Toggle("Play Stop Sound", isOn: $settings.playStopSound)
                            if settings.playStopSound {
                                controlRow(label: "Stop Sound") {
                                    Picker("", selection: $settings.selectedStopSound) {
                                        ForEach(AppSettings.SystemSound.allCases) { sound in
                                            Text(sound.rawValue).tag(sound)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                    .frame(width: 150)
                                    .onChange(of: settings.selectedStopSound) { _, newValue in
                                        SoundPlayer.play(newValue)
                                    }
                                }
                            }

                            Toggle("Launch at Login", isOn: launchAtLoginBinding)
                                .disabled(!launchAtLoginController.canAttemptRegistration)

                            Text(launchAtLoginController.statusMessage)
                                .font(.caption2)
                                .foregroundStyle(launchAtLoginController.lastError == nil ? .white.opacity(0.5) : .red.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)

                            if launchAtLoginController.needsSystemApproval {
                                Button("Open Login Items Settings") {
                                    openLoginItemsSettings()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            MenuBarSettingsSection(
                                settings: settings,
                                menuBarIconController: menuBarIconController
                            )
                        }
                    }

                    QuickSettingsDisclosureCard(
                        title: "Experimental UI",
                        subtitle: "Preview surfaces — off by default. No dictation behavior changes.",
                        systemImage: "flask.fill",
                        isExpanded: $experimentalPanelExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("These flags activate prototype UI surfaces. The dictation engine, audio, transcription, insertion, and permissions are unchanged.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)

                            Divider().opacity(0.2)

                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("State-first compact popover", isOn: $settings.useExperimentalStateFirstUI)
                                    .accessibilityLabel("Toggle state-first compact popover experiment")
                                Text("Replaces the standard menu-bar popover while enabled.")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.45))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Nano HUD (active dictation strip)", isOn: $settings.useExperimentalNanoHUD)
                                    .accessibilityLabel("Toggle nano HUD experiment")
                                Text("Replaces the floating HUD when a new HUD window is created. Requires Show Floating HUD to be on. Toggle while HUD is hidden for cleanest switch.")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.45))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Command palette (power-user overlay)", isOn: $settings.useExperimentalCommandPalette)
                                    .accessibilityLabel("Toggle experimental command palette")
                                Text("Adds a searchable command overlay accessible from the state-first popover.")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.45))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Dexter stateful feed", isOn: $settings.useExperimentalDexterFeed)
                                    .accessibilityLabel("Toggle experimental Dexter stateful feed")
                                Text("Shows Dexter commentary feed in the Settings & History panel. Local quote packs only — no network.")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.45))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    QuickSettingsDisclosureCard(
                        title: "Advanced",
                        subtitle: "Recovery actions for stuck macOS audio routes.",
                        systemImage: "wrench.and.screwdriver.fill",
                        isExpanded: $advancedPanelExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("If microphone input keeps failing, macOS Core Audio may be stuck. Resetting Core Audio restarts the system audio service and usually fixes missing or frozen microphones.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.58))
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Use this when DexDictate cannot open the selected microphone, Bluetooth audio gets stuck, or macOS reports Core Audio error -10868. This restarts the macOS audio service; audio devices will briefly disappear and reconnect.")
                                .font(.caption2)
                                .foregroundStyle(.orange.opacity(0.86))
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                resetCoreAudio()
                            } label: {
                                HStack(spacing: 6) {
                                    if isResettingCoreAudio {
                                        ProgressView()
                                            .scaleEffect(0.55)
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "waveform.badge.exclamationmark")
                                    }
                                    Text(isResettingCoreAudio ? "Resetting..." : "Reset Core Audio")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(.orange)
                            .disabled(isResettingCoreAudio)
                            .accessibilityLabel("Reset Core Audio")

                            if let coreAudioResetStatus {
                                Text(coreAudioResetStatus)
                                    .font(.caption2)
                                    .foregroundStyle(coreAudioResetStatus.lowercased().contains("failed") ? .red.opacity(0.9) : .white.opacity(0.55))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(SurfaceTokens.cardPadding)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
            }
        }
        .padding(.horizontal)
        .onAppear {
            launchAtLoginController.refresh()
            launchAtLoginController.syncStoredPreference(into: settings)
            menuBarIconController.refreshAssets()
            profileManager.synchronizeBundledVocabulary(with: vocabularyManager)
            modelCatalog.refresh()
            benchmarkResultsStore.reload()
            profanityAdditionsText = settings.customProfanityWords.joined(separator: ", ")
            profanityRemovalsText = settings.customProfanityRemovals.joined(separator: ", ")
        }
        .onChange(of: settings.launchAtLogin) { _, _ in
            launchAtLoginController.refresh()
            launchAtLoginController.syncStoredPreference(into: settings)
        }
        .onChange(of: settings.inputDeviceUID) { _, _ in
            scanner.refreshDevices()
        }
        .onChange(of: profanityAdditionsText) { _, newVal in
            settings.customProfanityWords = newVal
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        .onChange(of: profanityRemovalsText) { _, newVal in
            settings.customProfanityRemovals = newVal
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    private var profileBinding: Binding<AppProfile> {
        Binding(
            get: { profileManager.activeProfile },
            set: { newValue in
                MainActorAction.run {
                    profileManager.selectProfile(newValue)
                    profileManager.synchronizeBundledVocabulary(with: vocabularyManager)
                    profileManager.refreshDynamicContent()
                }
            }
        )
    }

    private var safeModeBinding: Binding<Bool> {
        Binding(
            get: { settings.safeModeEnabled },
            set: { enabled in
                if enabled {
                    settings.enableSafeMode()
                } else {
                    settings.disableSafeMode()
                }
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginController.isEnabled },
            set: { newValue in
                MainActorAction.run {
                    launchAtLoginController.setEnabled(newValue)
                    launchAtLoginController.syncStoredPreference(into: settings)
                }
            }
        )
    }

    private var routeRecoveryStatusLabel: String {
        switch engine.routeHealthSnapshot.lastRecoverySucceeded {
        case .some(true):
            return engine.routeHealthSnapshot.isUsingSystemDefault ? "Fallback to default" : "Recovered"
        case .some(false):
            return "Failed"
        case .none:
            return "No recovery yet"
        }
    }

    private func resetCoreAudio() {
        guard !isResettingCoreAudio else { return }
        let alert = NSAlert()
        alert.messageText = "Reset Core Audio?"
        alert.informativeText = "This will restart macOS Core Audio. Your audio devices may briefly disconnect and reconnect. Continue?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        isResettingCoreAudio = true
        coreAudioResetStatus = "macOS will ask for administrator permission to restart Core Audio."
        Safety.log("QuickSettingsView — Reset Core Audio button invoked", category: .audio)

        Task { @MainActor in
            do {
                try await coreAudioResetService.resetCoreAudio()
                try await Task.sleep(nanoseconds: 1_200_000_000)
                scanner.refreshDevices()
                validatePreferredInputAfterCoreAudioReset()

                switch await engine.rebuildAudioAfterCoreAudioReset() {
                case .success(let message):
                    coreAudioResetStatus = message
                    Safety.log("QuickSettingsView — Core Audio reset postflight succeeded: \(message)", category: .audio)
                case .failure(let error):
                    coreAudioResetStatus = "Core Audio reset completed, but audio input restart failed: \(error.localizedDescription)"
                    Safety.log("QuickSettingsView — Core Audio reset postflight restart failed: \(error)", category: .audio)
                }
            } catch {
                coreAudioResetStatus = "Core Audio reset failed: \(error.localizedDescription)"
                Safety.log("QuickSettingsView — Core Audio reset failed: \(error)", category: .audio)
            }

            isResettingCoreAudio = false
        }
    }

    private func validatePreferredInputAfterCoreAudioReset() {
        let preferredUID = settings.inputDeviceUID
        guard !preferredUID.isEmpty else {
            Safety.log("QuickSettingsView — Core Audio reset postflight device validation: System Default selected", category: .audio)
            return
        }

        let devices = AudioDeviceManager.inputDevices()
        if devices.contains(where: { $0.uid == preferredUID }) {
            Safety.log("QuickSettingsView — Core Audio reset postflight device validation succeeded for preferredUID='\(preferredUID)'", category: .audio)
        } else {
            settings.inputDeviceUID = ""
            Safety.log("QuickSettingsView — Core Audio reset postflight cleared stale preferredUID='\(preferredUID)'", category: .audio)
        }
    }

    @ViewBuilder
    private var pinnedControlsStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pinned Controls")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.72))

            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Trigger Mode")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    HStack(spacing: 0) {
                        TriggerSegment(
                            title: "Hold",
                            isSelected: settings.triggerMode == .holdToTalk
                        ) {
                            settings.triggerMode = .holdToTalk
                        }
                        Divider()
                            .frame(width: 1)
                            .background(Color.white.opacity(0.15))
                        TriggerSegment(
                            title: "Toggle",
                            isSelected: settings.triggerMode == .toggle
                        ) {
                            settings.triggerMode = .toggle
                        }
                    }
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .disabled(settings.safeModeEnabled)

                    Text(settings.triggerMode == .holdToTalk
                         ? "Hold: records only while the trigger is pressed."
                         : "Toggle: first press starts, second press stops.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    compactPickerCard(title: "Input", width: 138) {
                        Picker("", selection: $settings.inputDeviceUID) {
                            Text("System Default").tag("")
                            ForEach(scanner.availableDevices) { device in
                                Text(device.name).tag(device.uid)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    compactPickerCard(title: "Model", width: 138) {
                        Picker("", selection: $settings.activeWhisperModelID) {
                            ForEach(modelCatalog.availableModels) { model in
                                Text(model.displayName).tag(model.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                HStack(spacing: 8) {
                    compactToggleCard(title: "Auto-Paste", isOn: $settings.autoPaste)
                    compactToggleCard(title: "Safe Mode", isOn: safeModeBinding)
                }
            }
        }
    }

    private func controlRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
            Spacer()
            content()
        }
    }

    private func compactPickerCard<Content: View>(title: String, width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            content()
        }
        .frame(width: width, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func compactToggleCard(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // Retain the vocabulary window so we can reuse it instead of creating duplicates.
    @State private var vocabularyWindow: NSWindow?
    @State private var customCommandsWindow: NSWindow?
    @State private var perAppInsertionWindow: NSWindow?

    private func openVocabularyWindow() {
        MainActorAction.run {
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

    private func openPerAppInsertionWindow() {
        MainActorAction.run {
            if let existing = perAppInsertionWindow, existing.isVisible {
                existing.makeKeyAndOrderFront(nil)
                NSApp.activate()
                return
            }
            let view = PerAppInsertionView(manager: engine.appInsertionOverridesManager)
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = NSLocalizedString("Per-App Insertion Rules", comment: "")
            window.setContentSize(NSSize(width: 500, height: 380))
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.center()
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            perAppInsertionWindow = window
        }
    }

    private func openCustomCommandsWindow() {
        MainActorAction.run {
            if let existing = customCommandsWindow, existing.isVisible {
                existing.makeKeyAndOrderFront(nil)
                NSApp.activate()
                return
            }
            let view = CustomCommandsView(manager: engine.customCommandsManager)
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = NSLocalizedString("Voice Commands", comment: "")
            window.setContentSize(NSSize(width: 460, height: 380))
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.center()
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            customCommandsWindow = window
        }
    }

    private func openBenchmarkCapture() {
        MainActorAction.run {
            benchmarkCaptureController.show(engine: engine)
        }
    }

    private func importModel() {
        MainActorAction.run {
            _ = modelCatalog.importModelFromOpenPanel()
        }
    }

    private func runBenchmarksNow() {
        MainActorAction.run {
            adaptiveBenchmarkController.runBenchmarksNow()
        }
    }

    private func returnToStandardProfile() {
        MainActorAction.run {
            profileManager.returnToStandard()
            profileManager.synchronizeBundledVocabulary(with: vocabularyManager)
            profileManager.refreshDynamicContent()
        }
    }

    private func openLoginItemsSettings() {
        MainActorAction.run {
            launchAtLoginController.openSystemSettings()
        }
    }
}

private struct QuickSettingsDisclosureCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isExpanded: Bool
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() } }) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 24, height: 24)
                        .background(Color.cyan.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.18), value: isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .padding(.top, 10)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(isExpanded ? 0.18 : 0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct QuickSettingsSummaryValue: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
        }
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
                Text("No Dex icons were found in \(menuBarIconController.assetSourceDescription).")
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

private struct SettingToggleWithInfo: View {
    let title: String
    let info: String
    @Binding var isOn: Bool
    @State private var showingInfo = false

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showingInfo.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingInfo, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                    Text(info)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(width: 240)
            }
        }
    }
}

private struct LiveTranscriptionStatusView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var registry: TranscriptionProviderRegistry
    @ObservedObject var modelCatalog: WhisperModelCatalog
    @State private var downloadingIDs: Set<TranscriptionProviderID> = []
    @State private var downloadingWhisperID: String?
    @State private var isModelListExpanded = true

    private static let downloadableProviderIDs: Set<TranscriptionProviderID> = [
        .parakeetTDT06Bv3, .nemotron35ASRStreaming06B, .moonshineV2
    ]

    private var primaryEngineIsParakeet: Bool {
        registry.healthReport[.parakeetTDT06Bv3]?.isAvailable == true
    }

    /// The engine currently producing the committed/pasted transcript: the explicit pin if one
    /// is set, otherwise the automatic Parakeet-if-healthy-else-Whisper default. Shared with
    /// the Experimental UI's `DexContextChips` via `ModelSelectionActions`.
    private var primaryEngineID: TranscriptionProviderID {
        ModelSelectionActions.primaryEngineID(settings: settings, registry: registry)
    }

    private var primaryEngineStatusExplanation: String {
        let isPinned = !settings.preferredPrimaryEngineID.isEmpty
        switch primaryEngineID {
        case .parakeetTDT06Bv3:
            return isPinned
                ? "Pinned to Parakeet in the model list below."
                : "Parakeet is downloaded and healthy, so it produces the text that gets typed automatically. Whisper is the fallback if it ever becomes unavailable."
        default:
            if isPinned {
                return "Pinned to Whisper in the model list below."
            }
            return primaryEngineIsParakeet
                ? "Whisper produces the text that gets typed."
                : "Whisper produces the text that gets typed. Download Parakeet below to make it the primary engine instead."
        }
    }

    /// One row in the unified model list — a specific Whisper size, or one of the other engines.
    private enum ModelRow: Identifiable {
        case whisper(id: String, displayName: String, isInstalled: Bool)
        case provider(TranscriptionProviderID)

        var id: String {
            switch self {
            case .whisper(let id, _, _): return "whisper:\(id)"
            case .provider(let pid): return pid.rawValue
            }
        }
    }

    private struct RowDisplay {
        let title: String
        let subtitle: String
        let isSelected: Bool
        let health: TranscriptionProviderHealth?
        let isDownloading: Bool
        let canDownload: Bool
    }

    /// Whisper sizes already on disk, unioned with the full downloadable catalog — de-duplicated
    /// by id so an installed size never appears twice. Shared logic lives in
    /// `ModelSelectionActions` so this list can't drift from the Experimental UI's version.
    private var whisperRows: [ModelRow] {
        ModelSelectionActions.whisperRows(modelCatalog: modelCatalog).map {
            .whisper(id: $0.id, displayName: $0.displayName, isInstalled: $0.isInstalled)
        }
    }

    private var providerRows: [ModelRow] {
        [.provider(.parakeetTDT06Bv3), .provider(.nemotron35ASRStreaming06B), .provider(.moonshineV2), .provider(.appleSpeech)]
    }

    private func providerObject(for id: TranscriptionProviderID) -> any TranscriptionProvider {
        switch id {
        case .parakeetTDT06Bv3: return registry.parakeetProvider
        case .nemotron35ASRStreaming06B: return registry.nemotronProvider
        case .moonshineV2: return registry.moonshineProvider
        case .appleSpeech: return registry.appleSpeechProvider
        case .whisperKit: return registry.whisperKitProvider
        }
    }

    private func display(for row: ModelRow) -> RowDisplay {
        switch row {
        case .whisper(let id, let name, let isInstalled):
            let health: TranscriptionProviderHealth = isInstalled
                ? .available()
                : .unavailable("Not downloaded yet — tap to fetch.")
            return RowDisplay(
                title: name,
                subtitle: "Compatibility",
                isSelected: primaryEngineID == .whisperKit && settings.activeWhisperModelID == id,
                health: health,
                isDownloading: downloadingWhisperID == id,
                canDownload: !isInstalled
            )
        case .provider(let pid):
            let selected: Bool
            switch pid {
            case .parakeetTDT06Bv3: selected = primaryEngineID == .parakeetTDT06Bv3
            case .nemotron35ASRStreaming06B, .appleSpeech: selected = settings.liveTranscriptionEnabled
            case .moonshineV2: selected = settings.commandModeEnabled
            case .whisperKit: selected = false
            }
            return RowDisplay(
                title: providerObject(for: pid).displayName,
                subtitle: providerObject(for: pid).userFacingModeName,
                isSelected: selected,
                health: registry.healthReport[pid],
                isDownloading: downloadingIDs.contains(pid),
                canDownload: Self.downloadableProviderIDs.contains(pid)
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingToggleWithInfo(
                title: "Live Transcription",
                info: "Uses streaming transcription when available. When on, DexDictate shows live partial captions while you speak, preferring Nemotron (if installed), then Apple Speech (on-device). This only affects the live preview — see \"Primary dictation engine\" below for what actually gets typed.",
                isOn: $settings.liveTranscriptionEnabled
            )
            .onChange(of: settings.liveTranscriptionEnabled) { _, _ in
                refreshStatus()
            }

            SettingToggleWithInfo(
                title: "Command Mode",
                info: "When on, short recordings (under 2.5s) are tried against Moonshine first to catch a recognized command phrase (\"scratch that\", \"new line\", a custom Dex command) before falling through to the primary dictation engine. Longer recordings always skip straight to the primary engine. Only applies once Moonshine's model is downloaded below.",
                isOn: $settings.commandModeEnabled
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(primaryEngineID == .parakeetTDT06Bv3 ? Color.green.opacity(0.8) : Color.white.opacity(0.35))
                        .frame(width: 6, height: 6)
                    Text("Primary dictation engine: \(primaryEngineID == .parakeetTDT06Bv3 ? registry.parakeetProvider.displayName : registry.whisperKitProvider.displayName)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Text(primaryEngineStatusExplanation)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let resolution = registry.lastResolution {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(resolution.usesLiveStreaming ? Color.green.opacity(0.8) : Color.white.opacity(0.35))
                            .frame(width: 6, height: 6)
                        Text("Live preview: \(resolution.selectedProviderDisplayName) (\(resolution.modeName))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    if let explanation = resolution.fallbackExplanation {
                        Text(explanation)
                            .font(.caption2)
                            .foregroundStyle(.orange.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            DisclosureGroup("Choose Model", isExpanded: $isModelListExpanded) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tap a model to use it. Not downloaded yet? Tapping it downloads it first, then selects it. Picking a model sets sensible defaults for it below — you can still change those manually afterward.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)

                    ForEach(whisperRows) { row in rowView(row) }
                    Divider().padding(.vertical, 2)
                    ForEach(providerRows) { row in rowView(row) }
                }
                .padding(.top, 6)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
        }
        .onAppear { refreshStatus() }
    }

    private func rowView(_ row: ModelRow) -> some View {
        let d = display(for: row)
        return Button {
            selectRow(row)
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: d.isSelected ? "checkmark.circle.fill" : (d.health?.isAvailable == true ? "circle" : "xmark.circle"))
                    .foregroundStyle(d.isSelected ? .green : (d.health?.isAvailable == true ? .white.opacity(0.5) : .white.opacity(0.3)))
                    .font(.system(size: 11))
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(d.title) — \(d.subtitle)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    if let reason = d.health?.reason, d.health?.isAvailable != true {
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                if d.isDownloading {
                    ProgressView()
                        .controlSize(.mini)
                } else if d.canDownload, d.health?.isAvailable != true {
                    Text("Download")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func refreshStatus() {
        registry.resolveActiveProvider(liveTranscriptionEnabled: settings.liveTranscriptionEnabled)
    }

    private func selectRow(_ row: ModelRow) {
        switch row {
        case .whisper(let id, _, let isInstalled):
            guard downloadingWhisperID == nil else { return }
            downloadingWhisperID = id
            Task {
                await ModelSelectionActions.selectWhisper(id: id, isInstalled: isInstalled, settings: settings, modelCatalog: modelCatalog)
                downloadingWhisperID = nil
                refreshStatus()
            }
        case .provider(let pid):
            guard !downloadingIDs.contains(pid) else { return }
            downloadingIDs.insert(pid)
            Task {
                await ModelSelectionActions.selectProvider(pid, settings: settings, registry: registry)
                downloadingIDs.remove(pid)
                refreshStatus()
            }
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
