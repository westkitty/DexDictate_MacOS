import SwiftUI
import AppKit
import DexDictateKit

/// Settings → General. Migrated verbatim (same bindings, same storage keys) from the
/// popover's "Appearance & System" card: Launch at Login, start/stop sounds, status
/// color, and menu bar style. The theme picker and Dexter profile controls stay in the
/// popover until Packet 11.
struct GeneralSettingsPage: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var menuBarIconController = MenuBarIconController.shared
    @StateObject private var launchAtLoginController = LaunchAtLoginController()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(SettingsPage.general.title)
                    .font(.title2.bold())

                statusColorRow

                Toggle("Play Start Sound", isOn: $settings.playStartSound)
                if settings.playStartSound {
                    startSoundRow
                }

                Toggle("Play Stop Sound", isOn: $settings.playStopSound)
                if settings.playStopSound {
                    stopSoundRow
                }

                Divider()

                launchAtLoginSection

                Divider()

                Text("Interface")
                    .font(.headline)
                Toggle("Show Floating HUD", isOn: $settings.showFloatingHUD)

                Divider()

                MenuBarSettingsSection(
                    settings: settings,
                    menuBarIconController: menuBarIconController
                )

                Divider()

                HStack(spacing: 12) {
                    Button("Replay Onboarding") {
                        replayOnboarding()
                    }
                    .buttonStyle(.bordered)

                    Button("Restore Defaults") {
                        settings.restoreDefaults()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear {
            // Same idempotent refresh QuickSettingsView performs in its own onAppear —
            // needed here too since this page can be opened without ever opening the
            // popover first.
            launchAtLoginController.refresh()
            launchAtLoginController.syncStoredPreference(into: settings)
            menuBarIconController.refreshAssets()
        }
        .onChange(of: settings.launchAtLogin) { _, _ in
            launchAtLoginController.refresh()
            launchAtLoginController.syncStoredPreference(into: settings)
        }
    }

    private var statusColorRow: some View {
        HStack {
            Text("Status Color")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 8) {
                ColorPicker(
                    "",
                    selection: Binding(
                        get: { settings.statusAccentColor },
                        set: { settings.statusAccentColor = $0 }
                    ),
                    supportsOpacity: false
                )
                .labelsHidden()
                .accessibilityLabel("Dictation status accent color")

                Button("Reset") {
                    settings.resetStatusAccentColor()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(settings.statusAccentColorHex.isEmpty)
                .accessibilityLabel("Reset status color to default")
            }
        }
    }

    private var startSoundRow: some View {
        HStack {
            Text("Start Sound")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $settings.selectedStartSound) {
                ForEach(AppSettings.SystemSound.allCases) { sound in
                    Text(sound.rawValue).tag(sound)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150)
            .onChange(of: settings.selectedStartSound) { _, newValue in
                SoundPlayer.play(newValue)
            }
        }
    }

    private var stopSoundRow: some View {
        HStack {
            Text("Stop Sound")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $settings.selectedStopSound) {
                ForEach(AppSettings.SystemSound.allCases) { sound in
                    Text(sound.rawValue).tag(sound)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150)
            .onChange(of: settings.selectedStopSound) { _, newValue in
                SoundPlayer.play(newValue)
            }
        }
    }

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Launch at Login", isOn: launchAtLoginBinding)
                .disabled(!launchAtLoginController.canAttemptRegistration)

            Text(launchAtLoginController.statusMessage)
                .font(.caption2)
                .foregroundStyle(launchAtLoginController.lastError == nil ? Color.secondary : Color.red.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            if launchAtLoginController.needsSystemApproval {
                Button("Open Login Items Settings") {
                    launchAtLoginController.openSystemSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginController.isEnabled },
            set: { newValue in
                MainActorAction.run {
                    launchAtLoginController.setEnabled(newValue)
                    launchAtLoginController.syncStoredPreference(into: settings)
                }
            }
        )
    }

    /// Calls the exact same presentation entry point as the popover's five-tap version
    /// gesture (`FooterView.registerVersionTapForOnboarding` → `onHiddenDebugTrigger` →
    /// `AppDelegate.presentOnboardingForDebug()`), reached here via the shared app delegate
    /// instance rather than by modifying `OnboardingView.swift` internals.
    private func replayOnboarding() {
        (NSApp.delegate as? AppDelegate)?.presentOnboardingForDebug()
    }
}
