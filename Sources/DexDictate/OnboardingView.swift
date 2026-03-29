import SwiftUI
import DexDictateKit

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    var onboardingWindow: NSWindow?

    @State private var currentPage = 0

    private let stepLabels = [
        NSLocalizedString("Welcome", comment: "Onboarding step"),
        NSLocalizedString("Permissions", comment: "Onboarding step"),
        NSLocalizedString("Shortcut", comment: "Onboarding step"),
        NSLocalizedString("Done", comment: "Onboarding step"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // ── Step rail ────────────────────────────────────────────────────
            OnboardingStepRail(currentStep: currentPage, stepLabels: stepLabels)
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 16)

            Divider().opacity(0.15)

            // ── Page content ─────────────────────────────────────────────────
            ZStack {
                if currentPage == 0 {
                    WelcomePage().transition(.opacity)
                } else if currentPage == 1 {
                    PermissionsPage().transition(.opacity)
                } else if currentPage == 2 {
                    ShortcutPage(settings: settings).transition(.opacity)
                } else if currentPage == 3 {
                    CompletionPage(settings: settings).transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.15)

            // ── Navigation bar ───────────────────────────────────────────────
            HStack(spacing: 12) {
                if currentPage > 0 {
                    Button(action: { withAnimation { currentPage -= 1 } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.caption.weight(.semibold))
                            Text(NSLocalizedString("Back", comment: ""))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                Spacer()

                if currentPage < 3 {
                    Button(action: { withAnimation { currentPage += 1 } }) {
                        HStack(spacing: 4) {
                            Text(NSLocalizedString("Continue", comment: ""))
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else {
                    Button(action: {
                        settings.hasCompletedOnboarding = true
                        onboardingWindow?.close()
                    }) {
                        HStack(spacing: 4) {
                            Text(NSLocalizedString("Start Dictating", comment: ""))
                            Image(systemName: "arrow.right.circle.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .tint(SemanticColors.ready)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 520, height: 520)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}

// MARK: - Step Rail

/// A connected step progress indicator with numbered circles, labels, and a fill line.
private struct OnboardingStepRail: View {
    let currentStep: Int
    let stepLabels: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<stepLabels.count, id: \.self) { index in
                // Step node
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(nodeFill(for: index))
                            .frame(width: 28, height: 28)
                        Circle()
                            .strokeBorder(nodeBorder(for: index), lineWidth: 1.5)
                            .frame(width: 28, height: 28)

                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(nodeLabel(for: index))
                        }
                    }

                    Text(stepLabels[index])
                        .font(.system(size: 9, weight: index == currentStep ? .semibold : .regular))
                        .foregroundStyle(index == currentStep
                            ? SemanticColors.accent
                            : Color.white.opacity(0.3))
                        .lineLimit(1)
                }

                // Connecting line (not after last step)
                if index < stepLabels.count - 1 {
                    Rectangle()
                        .fill(index < currentStep
                              ? SemanticColors.ready.opacity(0.7)
                              : Color.white.opacity(0.1))
                        .frame(height: 1.5)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 20) // align with circle centre
                }
            }
        }
    }

    private func nodeFill(for index: Int) -> Color {
        if index < currentStep { return SemanticColors.ready.opacity(0.85) }
        if index == currentStep { return SemanticColors.accent.opacity(0.15) }
        return Color.white.opacity(0.05)
    }

    private func nodeBorder(for index: Int) -> Color {
        if index < currentStep { return SemanticColors.ready.opacity(0.8) }
        if index == currentStep { return SemanticColors.accent.opacity(0.8) }
        return Color.white.opacity(0.12)
    }

    private func nodeLabel(for index: Int) -> Color {
        if index == currentStep { return SemanticColors.accent }
        return Color.white.opacity(0.25)
    }
}

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle.fill")
                .resizable()
                .frame(width: 72, height: 72)
                .foregroundStyle(SemanticColors.accent)

            Text(NSLocalizedString("Welcome to DexDictate", comment: ""))
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(NSLocalizedString("Supercharge your dictation with global shortcuts\nand Whisper-powered accuracy.", comment: ""))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 24)
    }
}

struct PermissionsPage: View {
    // Track whether the user has clicked the grant button (so we can show Input Monitoring steps)
    @State private var accessibilityRequested = false
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var microphoneHarness = MicrophoneValidationHarness()
    @State private var triggerValidationState: TriggerValidationState = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(NSLocalizedString("Permissions", comment: ""))
                    .font(.title).bold()
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(NSLocalizedString("DexDictate needs 3 permissions. Follow these steps:", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                LivePermissionChecklist(permissionManager: permissionManager)
                OnboardingValidationPanel(
                    triggerValidationState: triggerValidationState,
                    microphoneHarness: microphoneHarness,
                    onRunTriggerTest: {
                        triggerValidationState = TriggerValidationProbe.runCheck()
                    },
                    onRunMicrophoneTest: {
                        microphoneHarness.runTest()
                    }
                )

                // ── Step 1: Accessibility ─────────────────────────────────────
                PermissionStep(
                    number: 1,
                    icon: "hand.raised.fill",
                    iconColor: .blue,
                    title: NSLocalizedString("Accessibility", comment: ""),
                    description: NSLocalizedString("Required to detect your global hotkey.", comment: "")
                ) {
                    Button(NSLocalizedString("Open Accessibility Settings", comment: "")) {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                            as CFDictionary
                        AXIsProcessTrustedWithOptions(options)
                        withAnimation { accessibilityRequested = true }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }

                // ── Step 2: Input Monitoring (manual — macOS requires it) ─────
                if accessibilityRequested {
                    PermissionStep(
                        number: 2,
                        icon: "keyboard.fill",
                        iconColor: .orange,
                        title: NSLocalizedString("Input Monitoring", comment: ""),
                        description: NSLocalizedString(
                            "macOS requires you to add DexDictate manually:",
                            comment: "")
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            // Numbered sub-steps
                            ForEach([
                                NSLocalizedString("1. Open System Settings → Privacy & Security → Input Monitoring", comment: ""),
                                NSLocalizedString("2. Click the  +  button at the bottom of the list", comment: ""),
                                NSLocalizedString("3. Navigate to Applications → select DexDictate → click Open", comment: ""),
                                NSLocalizedString("4. Make sure the toggle next to DexDictate is ON", comment: ""),
                            ], id: \.self) { step in
                                Text(step)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                            }

                            Button(NSLocalizedString("Open Input Monitoring Settings", comment: "")) {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .padding(.top, 4)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // ── Step 3: Microphone ────────────────────────────────────────
                PermissionStep(
                    number: accessibilityRequested ? 3 : 2,
                    icon: "mic.fill",
                    iconColor: .red,
                    title: NSLocalizedString("Microphone", comment: ""),
                    description: NSLocalizedString(
                        "macOS will ask automatically when you first press your dictation shortcut. No action needed now.",
                        comment: "")
                ) { EmptyView() }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .onAppear {
            permissionManager.refreshPermissions()
            permissionManager.startMonitoring()
        }
        .onDisappear {
            permissionManager.stopMonitoring()
        }
    }
}

private struct LivePermissionChecklist: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Checklist")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                PermissionSummaryBadge(allGranted: permissionManager.allPermissionsGranted)
            }

            PermissionStatusRow(
                title: NSLocalizedString("Accessibility", comment: ""),
                detail: NSLocalizedString("Needed for the event tap trust path and output control.", comment: ""),
                isGranted: permissionManager.accessibilityGranted
            )

            PermissionStatusRow(
                title: NSLocalizedString("Input Monitoring", comment: ""),
                detail: NSLocalizedString("Needed to receive your global trigger events.", comment: ""),
                isGranted: permissionManager.inputMonitoringGranted
            )

            PermissionStatusRow(
                title: NSLocalizedString("Microphone", comment: ""),
                detail: NSLocalizedString("Checked separately and prompted when dictation actually needs audio access.", comment: ""),
                isGranted: permissionManager.microphoneGranted
            )
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct PermissionSummaryBadge: View {
    let allGranted: Bool

    var body: some View {
        Text(allGranted ? "Ready" : "In Progress")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(allGranted ? Color.green.opacity(0.22) : Color.orange.opacity(0.22))
            .foregroundStyle(allGranted ? Color.green : Color.orange)
            .clipShape(Capsule())
    }
}

private struct PermissionStatusRow: View {
    let title: String
    let detail: String
    let isGranted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(isGranted ? Color.green : Color.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline).bold()
                    Text(isGranted ? "Granted" : "Waiting")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isGranted ? Color.green : Color.orange)
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OnboardingValidationPanel: View {
    let triggerValidationState: TriggerValidationState
    @ObservedObject var microphoneHarness: MicrophoneValidationHarness
    let onRunTriggerTest: () -> Void
    let onRunMicrophoneTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Validation")
                .font(.headline)
                .foregroundStyle(.white)

            ValidationCard(
                title: "Trigger Test",
                headline: triggerValidationState.headline,
                detail: triggerValidationState.detail,
                accentColor: triggerValidationState.isSuccess ? .green : .orange
            ) {
                Button("Test Trigger Readiness", action: onRunTriggerTest)
                    .buttonStyle(.borderedProminent)
            }

            ValidationCard(
                title: "Microphone Test",
                headline: microphoneHarness.state.headline,
                detail: microphoneHarness.state.detail,
                accentColor: microphoneHarness.state.isSuccess ? .green : .orange
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Button(
                        microphoneHarness.state == .running
                        ? "Testing Microphone..."
                        : "Test Microphone"
                    ) {
                        onRunMicrophoneTest()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(microphoneHarness.state == .running)

                    ProgressView(value: min(max(microphoneHarness.inputLevel, 0), 1))
                        .progressViewStyle(.linear)
                        .tint(microphoneHarness.state.isSuccess ? .green : .blue)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ValidationCard<Action: View>: View {
    let title: String
    let headline: String
    let detail: String
    let accentColor: Color
    @ViewBuilder let action: () -> Action

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline).bold()
                    .foregroundStyle(.white)
                Spacer()
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
            }

            Text(headline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            action()
        }
        .padding(12)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// A single numbered permission step card.
private struct PermissionStep<Action: View>: View {
    let number: Int
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Circle step number
            ZStack {
                Circle().fill(iconColor.opacity(0.2)).frame(width: 36, height: 36)
                Text("\(number)").font(.headline).foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.subheadline).bold()
                    .foregroundStyle(iconColor)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                action()
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ShortcutPage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 40)
                .foregroundStyle(SemanticColors.accent)

            Text(NSLocalizedString("Choose Your Trigger", comment: ""))
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(NSLocalizedString("Select a shortcut to start dictation.\nThe default is the Middle Mouse Button.", comment: ""))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)

            ShortcutRecorder(shortcut: $settings.userShortcut)
                .frame(width: 200)
                .padding()
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 24)
    }
}

struct CompletionPage: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 72, height: 72)
                .foregroundStyle(SemanticColors.ready)

            Text(NSLocalizedString("You're All Set!", comment: ""))
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(NSLocalizedString("DexDictate lives in your menu bar.\nClick the icon or press your shortcut to start dictating.", comment: ""))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 24)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
