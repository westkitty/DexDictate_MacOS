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
    @ObservedObject var benchmarkCaptureController: BenchmarkCaptureWindowController
    private let engine = TranscriptionEngine.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                    title: "Use Context From Focused Field",
                    info: "Reads the text you're currently editing (via the Accessibility API) and uses it to prime Whisper, improving accuracy for proper nouns and continuing sentences. Combined with DexDictate's vocabulary biasing. Off by default; requires Accessibility permission.",
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
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    /// Distinct from "Use Context From Focused Field" (Context Injection) above: this
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
