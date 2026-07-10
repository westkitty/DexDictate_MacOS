import SwiftUI
import DexDictateKit

/// Sidebar + detail shell for the Settings window. Pages are placeholders until
/// Packets 03–11 migrate real controls into them one domain at a time.
///
/// BUG-005 fix: `selection` is now this view's own `@State`, not a `@Binding` sourced from
/// a bare `Binding(get:set:)` closure pair constructed in `SettingsWindowController`. That
/// custom binding had no SwiftUI-tracked source of truth in this view's hierarchy (nothing
/// here held `SettingsWindowController` via `@ObservedObject`), so writes to it from
/// `SettingsSidebar`'s `List(selection:)` never triggered `SettingsRootView.body` to
/// re-evaluate — the sidebar's native AppKit-backed row highlight updated immediately
/// (that's intrinsic `NSTableView` behavior, independent of SwiftUI's render cycle), but
/// `detailView`'s switch below kept rendering whatever was last actually re-rendered
/// (`.general`, from initial load). A plain local `@State` is a real SwiftUI dependency,
/// so both the sidebar and the detail switch below now react to the same change. This
/// still preserves "last-viewed page persists across close/reopen," since the window (and
/// this already-constructed view's `@State` storage) is never torn down between
/// `SettingsWindowController.show()` calls — only hidden/shown.
struct SettingsRootView: View {
    @State private var selection: SettingsPage = .general
    @ObservedObject var scanner: AudioDeviceScanner
    @ObservedObject var benchmarkCaptureController: BenchmarkCaptureWindowController
    @ObservedObject var historyController: HistoryWindowController
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var adaptiveBenchmarkController: AdaptiveBenchmarkController

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: $selection)
        } detail: {
            // Dexter identity watermark sits behind every Settings page (one place covers
            // all 11). It is decorative and never intercepts interaction — see
            // `DexterIdentityWatermark`. The profile-driven asset keeps it consistent with
            // the popover's current Dexter image and the active regional profile.
            ZStack {
                DexterIdentityWatermark(assetURL: profileManager.currentWatermarkAsset?.url)
                detailView
            }
        }
        .frame(minWidth: 640, minHeight: 420)
        // Packet 15: most controls migrated into this window were re-hosted verbatim from
        // the always-dark popover (hardcoded `.white`-opacity text/backgrounds throughout
        // `SettingToggleWithInfo`, `MenuBarSettingsSection`, etc.). Under system Light Mode
        // this window would otherwise render washed-out/illegible. Forcing dark here is the
        // minimal, consumer-side fix — matches how the popover's own `system` theme already
        // renders dark, and avoids a much larger multi-file rewrite of every reused
        // component's colors to adaptive semantic colors.
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .general: GeneralSettingsPage()
        case .dictation: DictationSettingsPage()
        case .audioMicrophone: AudioSettingsPage(scanner: scanner)
        case .outputInsertion: OutputSettingsPage()
        case .vocabularyCommands: VocabularyCommandsPage()
        case .modelsAccuracy: ModelsAccuracyPage(benchmarkCaptureController: benchmarkCaptureController, adaptiveBenchmarkController: adaptiveBenchmarkController)
        case .smartCleanup: SmartCleanupPage()
        case .history: HistorySettingsPage(historyController: historyController)
        case .dexterPersonality: DexterPersonalityPage(profileManager: profileManager)
        case .diagnosticsRecovery: DiagnosticsPage(scanner: scanner)
        case .advanced: AdvancedPage()
        }
    }
}
