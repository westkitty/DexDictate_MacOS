import SwiftUI
import DexDictateKit

/// Settings → Models & Accuracy. Migrated verbatim (same bindings, same storage keys,
/// same internal/user-facing names — renames are Packet 10) from the popover's
/// "Accuracy & Speed" card and the entry points inside its "Benchmarks & Corpus" group.
/// Benchmarking itself (`ModelBenchmarking.swift`, `WhisperModelCatalog.swift`, promotion
/// policy, `BenchmarkCaptureWindow.swift` internals) is untouched — only its entry point
/// and status display relocate. The popover's Benchmarks & Corpus group is hidden
/// entirely; benchmark automation cadence controls stay there for now (Packet 08 Advanced).
///
/// Context Biasing and Transcription Engines (Packet 08B) were orphaned by Packet 07 —
/// they're adjacent to Context Injection and model selection but weren't in that packet's
/// goal text. `LiveTranscriptionStatusView` is re-hosted intact (it manages its own
/// `onAppear`-triggered status refresh and its own download side effects internally).
struct ModelsAccuracyPage: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var modelCatalog = WhisperModelCatalog.shared
    @ObservedObject private var benchmarkResultsStore = BenchmarkResultsStore.shared
    @ObservedObject var benchmarkCaptureController: BenchmarkCaptureWindowController
    @ObservedObject var adaptiveBenchmarkController: AdaptiveBenchmarkController
    private let engine = TranscriptionEngine.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SurfaceTokens.settingsSectionSpacing) {
                Text(SettingsPage.modelsAccuracy.title)
                    .font(.title2.bold())

                // BUG-006A: this is the one honest, primary-changing selector for "what actually
                // gets typed" — Parakeet and installed Whisper sizes are the only real,
                // mutually-exclusive alternatives for the committed dictation engine (see
                // `ModelSelectionActions.activeModelRows`). It shares state with the popover's
                // model chip and the "Installed Dictation Models" rows below via
                // `ModelSelectionActions.applyActiveModelSelection` — selecting here immediately
                // updates both. Nemotron/Moonshine/Apple Speech are deliberately not offered here;
                // they're independent feature toggles, not primary-engine alternatives (Model
                // Library section below, and its doc comment, explains why).
                HStack {
                    Text("Active Dictation Model")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: activeModelSelectionBinding) {
                        ForEach(activeModelRows) { row in
                            Text(row.displayName).tag(row.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 220)
                }

                Text(ModelSelectionActions.primaryEngineStatusExplanation(settings: settings, registry: engine.transcriptionProviderRegistry))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let availabilityWarning = modelCatalog.availabilityWarning {
                    Text(availabilityWarning)
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Import Model") {
                    _ = modelCatalog.importModelFromOpenPanel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let importError = modelCatalog.lastImportError {
                    Text(importError)
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                // BUG-006A: distinct from "Active Dictation Model" above — this doesn't choose a
                // model at all. It governs whether the idle benchmark system (see
                // `ModelBenchmarking.swift`) is allowed to silently promote/swap the active Whisper
                // model based on its own quality measurements. Renamed from the old ambiguous
                // "Model Selection" label, which sat directly under the real model picker and read
                // as if it were a second, competing way to choose the model.
                HStack {
                    Text("Model Auto-Promotion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $settings.modelSelectionMode) {
                        ForEach(AppSettings.ModelSelectionMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 220)
                }

                Text("Auto Idle Benchmark lets DexDictate silently swap your Whisper model when idle benchmarking finds a better one. Manual keeps whatever you pick above until you change it yourself.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                SettingToggleWithInfo(
                    title: "Quality Retry",
                    info: "When transcription produces a suspiciously short or low-confidence result, DexDictate silently re-runs Whisper on the same audio at a higher quality level. Costs extra processing time but catches utterances where the first pass stumbled.",
                    isOn: $settings.enableAccuracyRetry
                )

                if settings.enableAccuracyRetry {
                    SettingToggleWithInfo(
                        title: "Retry Suspicious Results Automatically",
                        info: "When Quality Retry is on, this fires the retry without asking you first. Turn it off if you'd rather decide manually — you'll see a 'Retry with Higher Quality' button after each suspicious result instead.",
                        isOn: $settings.autoRetrySuspiciousResults
                    )
                    .padding(.leading, 16)
                }

                SettingToggleWithInfo(
                    title: "Context Priming",
                    info: "Reads the text around your cursor so names and jargon come out right.",
                    isOn: $settings.enableContextInjection
                )

                Divider()

                contextBiasingSection

                Divider()

                Text("Model Library & Other Engines")
                    .font(.headline)
                LiveTranscriptionStatusView(
                    settings: settings,
                    registry: engine.transcriptionProviderRegistry,
                    modelCatalog: modelCatalog
                )

                Divider()

                Button("Open Benchmark Lab…") {
                    benchmarkCaptureController.show(engine: engine)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)

                benchmarkToolsSection
            }
            .padding(SurfaceTokens.settingsPagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    /// BUG-006A: rows for the "Active Dictation Model" picker — Parakeet (if healthy) plus every
    /// installed Whisper size. Shared with the popover's model chip via `ModelSelectionActions` so
    /// the two surfaces can never drift apart.
    private var activeModelRows: [ModelSelectionActions.ActiveModelRow] {
        ModelSelectionActions.activeModelRows(
            settings: settings, registry: engine.transcriptionProviderRegistry, modelCatalog: modelCatalog
        )
    }

    private var activeModelSelectionBinding: Binding<String> {
        Binding(
            get: { activeModelRows.first(where: { $0.isSelected })?.id ?? activeModelRows.first?.id ?? "" },
            set: { newID in
                guard let row = activeModelRows.first(where: { $0.id == newID }) else { return }
                ModelSelectionActions.applyActiveModelSelection(row, settings: settings)
            }
        )
    }

    /// Packet 10B: re-homes the three benchmark controls Packet 07 hid along with the rest
    /// of the popover's "Benchmarks & Corpus" group but never gave a new home
    /// (`docs/refactor_baseline/packet_10/NEEDS_ANDREW.md`). "Open Captured Corpus" is not
    /// re-hosted here — it's already reachable via the Benchmark Lab window's own
    /// "Open Corpus Folder" button (same `openCorpusFolder()` call, same
    /// `sessionDirectory == nil` disabled guard). Logic is identical to the hidden popover
    /// copy: same `adaptiveBenchmarkController.runBenchmarksNow()` / `settings
    /// .restoreStableDictationDefaults()` calls, same disabled condition, same
    /// `BenchmarkResultsSection` (widened from `private` to internal in
    /// `QuickSettingsView.swift`, zero logic changes).
    private var benchmarkToolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("Benchmark Tools")
                .font(.headline)

            HStack {
                Button("Run Benchmarks Now") {
                    MainActorAction.run {
                        adaptiveBenchmarkController.runBenchmarksNow()
                    }
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
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            BenchmarkResultsSection(
                settings: settings,
                modelCatalog: modelCatalog,
                benchmarkResultsStore: benchmarkResultsStore,
                adaptiveBenchmarkController: adaptiveBenchmarkController
            )
        }
    }

    /// Distinct from "Context Priming" (formerly "Context Injection") above: this
    /// applies a light domain-specific vocabulary hint based on which app is frontmost,
    /// rather than reading live cursor content. Migrated verbatim from the popover's
    /// "Context Biasing" disclosure group (Packet 08B — was orphaned by Packet 07).
    private var contextBiasingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Context Biasing")
                .font(.headline)

            HStack {
                Text("Bias Mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $settings.dictationDomainMode) {
                    ForEach(AppSettings.DictationDomainMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 220)
            }

            Text("Automatic detects which app is in focus and applies a light domain-specific vocabulary hint — coding terms for Xcode, email phrasing for Mail, chat style for Slack. Manual lets you pin a domain yourself. Off disables all biasing. Everything runs locally; no text leaves your machine.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
