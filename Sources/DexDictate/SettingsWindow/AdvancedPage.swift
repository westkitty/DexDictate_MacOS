import SwiftUI
import DexDictateKit

/// Settings → Advanced. Migrated verbatim (same bindings, same storage keys) from the
/// popover's "Accuracy & Speed" card (Trailing Trim Experiment) and its "Experimental UI"
/// card (all four experiment flags — moved together since they're presented as one group
/// in the popover and the packet names the card as a whole).
struct AdvancedPage: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SurfaceTokens.settingsSectionSpacing) {
                Text(SettingsPage.advanced.title)
                    .font(.title2.bold())

                Text("Experiment Flags")
                    .font(.headline)
                SettingToggleWithInfo(
                    title: "Trailing Trim Experiment",
                    info: "An experimental variation that trims silence only at the end of the recording, after your last spoken word. May improve accuracy on the final word of an utterance by preventing Whisper from continuing to 'hear' noise after speech ends. Best used alongside Trim Leading/Trailing Silence.",
                    isOn: $settings.enableTrailingTrimExperiment
                )

                Divider()

                Text("Experimental UI")
                    .font(.headline)
                Text("Packet 12B: the state-first compact popover surface has been retired — every capability it introduced now lives permanently in the standard popover and Settings (Command Palette via ⌘K, compact controls, live transcript/mic meter, Dexter Feed in Settings → Dexter & Personality). Only Nano HUD remains an opt-in alternative to the Floating HUD below. The dictation engine, audio, transcription, insertion, and permissions were unchanged throughout.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                experimentToggle(
                    title: "Nano HUD (active dictation strip)",
                    isOn: $settings.useExperimentalNanoHUD,
                    caption: "Replaces the floating HUD when a new HUD window is created. Requires Show Floating HUD to be on. Toggle while HUD is hidden for cleanest switch."
                )
            }
            .padding(SurfaceTokens.settingsPagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func experimentToggle(title: String, isOn: Binding<Bool>, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: isOn)
                .accessibilityLabel("Toggle \(title)")
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
