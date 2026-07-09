import SwiftUI
import DexDictateKit

// MARK: - Feature Hub

/// Full-feature access panel opened from the Nano HUD (`FloatingHUD.swift`'s
/// `showHubPanel()`) so the HUD is never a dead end.
///
/// Wraps `QuickSettingsView` along with top-level actions (Quit, Help, History).
/// Owns scanner / benchmark state objects so the parent views don't need to thread them.
///
/// Packet 12B: moved out of `ExperimentalUI/` — the state-first popover surface that used
/// to also host this view (`DexStateFirstPopoverView.swift`, via `ExperimentalScreen
/// .featureHub`) has been retired, but this view remains load-bearing for the (still
/// real, still opt-in) Nano HUD, so it stays. The type name is unchanged from before the
/// retirement to minimize churn; only its file location and this comment changed.
struct DexExperimentalFeatureHubView: View {
    @ObservedObject var engine: TranscriptionEngine
    @ObservedObject var settings: AppSettings
    @ObservedObject var profileManager: ProfileManager
    var onBack: () -> Void
    var onDetachHistory: (() -> Void)?
    var onOpenHelp: (() -> Void)?
    var onQuit: () -> Void

    @StateObject private var scanner = AudioDeviceScanner()
    @StateObject private var benchmarkCaptureController = BenchmarkCaptureWindowController()
    @StateObject private var adaptiveBenchmarkController = AdaptiveBenchmarkController()
    @ObservedObject private var menuBarIconController = MenuBarIconController.shared
    @ObservedObject private var modelCatalog = WhisperModelCatalog.shared
    @ObservedObject private var benchmarkResultsStore = BenchmarkResultsStore.shared

    @State private var isQuickSettingsExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            hubHeader
            Divider().opacity(0.18)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    hubActions
                    QuickSettingsView(
                        engine: engine,
                        settings: settings,
                        scanner: scanner,
                        profileManager: profileManager,
                        benchmarkCaptureController: benchmarkCaptureController,
                        vocabularyManager: engine.vocabularyManager,
                        menuBarIconController: menuBarIconController,
                        modelCatalog: modelCatalog,
                        adaptiveBenchmarkController: adaptiveBenchmarkController,
                        benchmarkResultsStore: benchmarkResultsStore,
                        isExpanded: $isQuickSettingsExpanded
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var hubHeader: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                    Text("Back")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to main popover")
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Text("All Features")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Button(action: onQuit) {
                HStack(spacing: 3) {
                    Image(systemName: "power")
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text("Quit")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quit DexDictate")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Quick actions

    private var hubActions: some View {
        HStack(spacing: 8) {
            if let onDetachHistory {
                Button(action: { onDetachHistory(); onBack() }) {
                    Label("History", systemImage: "clock")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.06))
                        .foregroundStyle(.white.opacity(0.75))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open full history window")
            }

            if let onOpenHelp {
                Button(action: { onOpenHelp(); onBack() }) {
                    Label("Help", systemImage: "questionmark.circle")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.06))
                        .foregroundStyle(.white.opacity(0.75))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Help")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
