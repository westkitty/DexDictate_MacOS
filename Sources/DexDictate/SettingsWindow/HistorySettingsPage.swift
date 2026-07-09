import SwiftUI
import AppKit
import DexDictateKit

/// Settings → History. Migrated verbatim (same bindings, same storage keys) from the
/// popover's "Profiles & History" card: Show Dictation Stats and Persist History Across
/// Sessions were orphaned by Packet 07/11's scope and assigned here by Andrew during
/// Packet 08B. History content itself is unchanged — it still lives in the existing
/// History window, opened here via the app's single `HistoryWindowController` instance
/// (already `.setup(engine:vocabularyManager:)` by the app; a fresh instance would
/// silently no-op).
struct HistorySettingsPage: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject var historyController: HistoryWindowController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SurfaceTokens.settingsSectionSpacing) {
                Text(SettingsPage.history.title)
                    .font(.title2.bold())

                Text("Transcription history itself stays in the History window — this page only holds its settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Open History Window…") {
                    historyController.show()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                Text("Stats")
                    .font(.headline)
                Toggle("Show Dictation Stats", isOn: $settings.showDictationStats)
                Text("Shows word count, session duration, and words per minute for the current session in the popover.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Divider()

                Text("History Storage")
                    .font(.headline)
                Toggle("Persist History Across Sessions", isOn: $settings.persistHistory)
                Text("When on, transcription history is saved to disk and restored the next time DexDictate launches.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(SurfaceTokens.settingsPagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
