import SwiftUI
import DexDictateKit

/// Sidebar + detail shell for the Settings window. Pages are placeholders until
/// Packets 03–11 migrate real controls into them one domain at a time.
struct SettingsRootView: View {
    @Binding var selection: SettingsPage
    @ObservedObject var scanner: AudioDeviceScanner
    @ObservedObject var benchmarkCaptureController: BenchmarkCaptureWindowController
    @ObservedObject var historyController: HistoryWindowController
    @ObservedObject var profileManager: ProfileManager

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: $selection)
        } detail: {
            detailView
        }
        .frame(minWidth: 640, minHeight: 420)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .general: GeneralSettingsPage()
        case .dictation: DictationSettingsPage()
        case .audioMicrophone: AudioSettingsPage(scanner: scanner)
        case .outputInsertion: OutputSettingsPage()
        case .vocabularyCommands: VocabularyCommandsPage()
        case .modelsAccuracy: ModelsAccuracyPage(benchmarkCaptureController: benchmarkCaptureController)
        case .smartCleanup: SmartCleanupPage()
        case .history: HistorySettingsPage(historyController: historyController)
        case .dexterPersonality: DexterPersonalityPage(profileManager: profileManager)
        case .diagnosticsRecovery: DiagnosticsPage(scanner: scanner)
        case .advanced: AdvancedPage()
        }
    }
}
