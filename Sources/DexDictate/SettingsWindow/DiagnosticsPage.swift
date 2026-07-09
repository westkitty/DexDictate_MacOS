import SwiftUI
import AppKit
import DexDictateKit

/// Settings → Diagnostics & Recovery. Permission status rows are new content (informed by
/// `PermissionBannerView.swift` as a display precedent, read-only) since the popover only
/// ever showed a conditional banner, not a dedicated status page. Route Health (moved from
/// the Input card) and Safe Mode (moved from the Output card) are migrated verbatim — same
/// bindings, same storage keys. Reset Core Audio replicates the exact same call sequence as
/// the popover's button (`CoreAudioResetService.resetCoreAudio()` → `scanner.refreshDevices()`
/// → preferred-input validation → `engine.rebuildAudioAfterCoreAudioReset()`) — zero edits to
/// `CoreAudioResetService.swift`, the recovery planner, or `PermissionManager.swift` logic.
struct DiagnosticsPage: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    @ObservedObject var scanner: AudioDeviceScanner
    private let engine = TranscriptionEngine.shared
    private let coreAudioResetService = CoreAudioResetService()

    @State private var isResettingCoreAudio = false
    @State private var coreAudioResetStatus: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SurfaceTokens.settingsSectionSpacing) {
                Text(SettingsPage.diagnosticsRecovery.title)
                    .font(.title2.bold())

                Text("Permissions")
                    .font(.headline)
                permissionRow(
                    title: "Microphone",
                    granted: permissionManager.microphoneGranted,
                    fix: "Open Microphone Settings",
                    action: permissionManager.openMicrophoneSettings
                )
                permissionRow(
                    title: "Accessibility",
                    granted: permissionManager.accessibilityGranted,
                    fix: "Open Accessibility Settings",
                    action: permissionManager.openAccessibilitySettings
                )
                permissionRow(
                    title: "Input Monitoring",
                    granted: permissionManager.inputMonitoringGranted,
                    fix: "Open Input Monitoring Settings",
                    action: permissionManager.openInputMonitoringSettings
                )

                Divider()

                Text("Route Health")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    diagnosticRow(label: "Active Input", value: engine.routeHealthSnapshot.activeInputLabel)
                    diagnosticRow(label: "Recoveries", value: "\(engine.routeHealthSnapshot.recoveryCount)")
                    diagnosticRow(label: "Last Recovery", value: routeRecoveryStatusLabel)

                    if let recoveryNotice = scanner.recoveryNotice {
                        Text(recoveryNotice)
                            .font(.caption2)
                            .foregroundStyle(.orange.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(engine.routeHealthSnapshot.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                Text("Safe Mode")
                    .font(.headline)
                Toggle("Safe Mode", isOn: safeModeBinding)
                Text("Safe Mode applies a low-risk preset: Hold to Talk trigger, clipboard-only output (no auto-paste), and no sound effects. Your current settings are snapshotted when enabled and restored exactly when turned off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                systemRepairGroup
            }
            .padding(SurfaceTokens.settingsPagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var systemRepairGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("System Repair")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("If microphone input keeps failing, macOS Core Audio may be stuck. Resetting Core Audio restarts the system audio service and usually fixes missing or frozen microphones.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            WarningCallout(text: "Use this when DexDictate cannot open the selected microphone, Bluetooth audio gets stuck, or macOS reports Core Audio error -10868. This restarts the macOS audio service; audio devices will briefly disappear and reconnect.")

            Button {
                resetCoreAudio()
            } label: {
                HStack(spacing: 6) {
                    if isResettingCoreAudio {
                        ProgressView().scaleEffect(0.55).controlSize(.small)
                    } else {
                        Image(systemName: "waveform.badge.exclamationmark")
                    }
                    Text(isResettingCoreAudio ? "Resetting..." : "Reset Core Audio")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isResettingCoreAudio)
            .accessibilityLabel("Reset Core Audio")

            if let coreAudioResetStatus {
                Text(coreAudioResetStatus)
                    .font(.caption2)
                    .foregroundStyle(coreAudioResetStatus.lowercased().contains("failed") ? .red.opacity(0.9) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SurfaceTokens.cardPadding)
        .overlay(
            RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    private func permissionRow(title: String, granted: Bool, fix: String, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .yellow)
            Text(title)
                .font(.caption)
            Spacer()
            if !granted {
                Button(fix) { action() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else {
                Text("Granted")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func diagnosticRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }

    private var routeRecoveryStatusLabel: String {
        switch engine.routeHealthSnapshot.lastRecoverySucceeded {
        case .some(true):
            return engine.routeHealthSnapshot.isUsingSystemDefault ? "Fallback to default" : "Recovered"
        case .some(false):
            return "Failed"
        case .none:
            return "No recovery yet"
        }
    }

    private var safeModeBinding: Binding<Bool> {
        Binding(
            get: { settings.safeModeEnabled },
            set: { enabled in
                if enabled {
                    settings.enableSafeMode()
                } else {
                    settings.disableSafeMode()
                }
            }
        )
    }

    private func validatePreferredInputAfterCoreAudioReset() {
        let preferredUID = settings.inputDeviceUID
        guard !preferredUID.isEmpty else {
            Safety.log("DiagnosticsPage — Core Audio reset postflight device validation: System Default selected", category: .audio)
            return
        }

        let devices = AudioDeviceManager.inputDevices()
        if devices.contains(where: { $0.uid == preferredUID }) {
            Safety.log("DiagnosticsPage — Core Audio reset postflight device validation succeeded for preferredUID='\(preferredUID)'", category: .audio)
        } else {
            settings.inputDeviceUID = ""
            Safety.log("DiagnosticsPage — Core Audio reset postflight cleared stale preferredUID='\(preferredUID)'", category: .audio)
        }
    }

    private func resetCoreAudio() {
        guard !isResettingCoreAudio else { return }
        let alert = NSAlert()
        alert.messageText = "Reset Core Audio?"
        alert.informativeText = "This will restart macOS Core Audio. Your audio devices may briefly disconnect and reconnect. Continue?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        isResettingCoreAudio = true
        coreAudioResetStatus = "macOS will ask for administrator permission to restart Core Audio."
        Safety.log("DiagnosticsPage — Reset Core Audio button invoked", category: .audio)

        Task { @MainActor in
            do {
                try await coreAudioResetService.resetCoreAudio()
                try await Task.sleep(nanoseconds: 1_200_000_000)
                scanner.refreshDevices()
                validatePreferredInputAfterCoreAudioReset()

                switch await engine.rebuildAudioAfterCoreAudioReset() {
                case .success(let message):
                    coreAudioResetStatus = message
                    Safety.log("DiagnosticsPage — Core Audio reset postflight succeeded: \(message)", category: .audio)
                case .failure(let error):
                    coreAudioResetStatus = "Core Audio reset completed, but audio input restart failed: \(error.localizedDescription)"
                    Safety.log("DiagnosticsPage — Core Audio reset postflight restart failed: \(error)", category: .audio)
                }
            } catch {
                coreAudioResetStatus = "Core Audio reset failed: \(error.localizedDescription)"
                Safety.log("DiagnosticsPage — Core Audio reset failed: \(error)", category: .audio)
            }
            isResettingCoreAudio = false
        }
    }
}
