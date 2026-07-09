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

                HStack {
                    Text("Active Model")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $settings.activeWhisperModelID) {
                        ForEach(modelCatalog.availableModels) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 220)
                }

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

                HStack {
                    Text("Model Selection")
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

                Text("Transcription Engines")
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
