import SwiftUI
import DexDictateKit

/// Settings → Vocabulary & Commands. Embeds the existing `VocabularySettingsView` and
/// `CustomCommandsView` content views verbatim — replacing the two buried buttons in the
/// popover's Input card. `VocabularyManager`/`CommandProcessor` logic is untouched; this
/// page only re-hosts their existing UI.
///
/// No "Learned" badge: `VocabularyItem` (see `VocabularyManager.swift`) has no
/// provenance/source field, so there's no existing data to render a badge from — adding
/// one would require a schema change, which is out of scope for this packet. Learned
/// corrections (via the History window's "Learn Correction" flow) still add plain
/// `VocabularyItem`s through the same unmodified `VocabularyManager.add`, so they appear
/// in the list below exactly like any other entry.
///
/// No import/export UI exists in either source view today, so there's nothing to preserve.
struct VocabularyCommandsPage: View {
    private let engine = TranscriptionEngine.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SurfaceTokens.settingsSectionSpacing) {
                Text(SettingsPage.vocabularyCommands.title)
                    .font(.title2.bold())

                // Ordered to match the actual processing order stated in the caption below
                // (TranscriptionEngine.prepareTranscriptionResult runs CommandProcessor before
                // VocabularyManager) — this previously showed Vocabulary above Commands, the
                // reverse of what the caption said ran first.
                CustomCommandsView(manager: engine.customCommandsManager)

                Divider()

                VocabularySettingsView(vocabularyManager: engine.vocabularyManager)

                Divider()

                Text("After transcription: Commands run first, then Vocabulary corrections, then the text is inserted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(SurfaceTokens.settingsPagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
