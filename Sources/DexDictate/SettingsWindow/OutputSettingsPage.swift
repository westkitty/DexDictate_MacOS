import SwiftUI
import AppKit
import DexDictateKit

/// Settings → Output & Insertion. Migrated verbatim (same bindings, same storage keys)
/// from the popover's "Output" card (Auto-Paste, Copy Only in Sensitive Fields, Use
/// Accessibility API for Insertion, Filter Profanity, Per-App Rules) and the "Accuracy &
/// Speed" card (Correction Sheet, renamed "Review Before Insert" in Packet 10 — grouped
/// here as an output-safety control even though it's declared alongside accuracy controls
/// in the popover). Safe Mode and Show Floating
/// HUD stay in the popover until Packet 08. No insertion/clipboard/secure-input logic
/// changed — only where these toggles are displayed.
struct OutputSettingsPage: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var profanityAdditionsText: String = ""
    @State private var profanityRemovalsText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SurfaceTokens.settingsSectionSpacing) {
                DexPageTitle(SettingsPage.outputInsertion.title)

                DexSectionTitle("Where text goes")
                Toggle("Auto-Paste (Insert at Cursor)", isOn: $settings.autoPaste)
                Toggle("Use Accessibility API for Insertion", isOn: $settings.useAccessibilityInsertion)

                Divider()

                DexSectionTitle("Safety")
                Toggle("Copy Only in Sensitive Fields", isOn: $settings.copyOnlyInSensitiveFields)

                SettingToggleWithInfo(
                    title: "Review Before Insert",
                    info: "After each dictation, shows a compact review sheet where you can confirm, edit, or reject the transcript before it gets inserted. Adds one extra step but lets you catch mistakes before they reach the target app.",
                    isOn: $settings.enableCorrectionSheet
                )

                Toggle("Filter Profanity", isOn: $settings.profanityFilter)
                if settings.profanityFilter {
                    profanityEditors
                }

                DexSectionDescription("DexDictate copies your previous clipboard contents before inserting, then restores them afterward (capped to a maximum payload size).")

                Divider()

                DexSectionTitle("Per-App Rules")
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Per-App Insertion Rules")
                            .font(.subheadline.weight(.semibold))
                        DexSecondaryText("Use app-specific presets and insertion overrides without bloating the main surface.")
                    }
                    Spacer()
                    Button("Manage Per-App Rules…") {
                        openPerAppInsertionWindow()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(SurfaceTokens.settingsPagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear {
            profanityAdditionsText = settings.customProfanityWords.joined(separator: ", ")
            profanityRemovalsText = settings.customProfanityRemovals.joined(separator: ", ")
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

    private var profanityEditors: some View {
        VStack(alignment: .leading, spacing: 6) {
            let bundled = ProfanityFilter.bundledWordCount
            let custom = settings.customProfanityWords.count
            Text("Filtering \(bundled + custom) words (\(bundled) bundled + \(custom) custom)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Add words to filter (comma-separated)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextEditor(text: $profanityAdditionsText)
                .font(.caption2)
                .frame(height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text("Un-filter bundled words (comma-separated)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextEditor(text: $profanityRemovalsText)
                .font(.caption2)
                .frame(height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private func openPerAppInsertionWindow() {
        MainActorAction.run {
            PerAppInsertionWindowController.shared.show(
                manager: TranscriptionEngine.shared.appInsertionOverridesManager
            )
        }
    }
}
