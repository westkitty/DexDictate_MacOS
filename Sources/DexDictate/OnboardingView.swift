import SwiftUI
import DexDictateKit

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissionManager: PermissionManager
    var onboardingWindow: NSWindow?
    
    // We can use a TabView for pages
    @State private var currentPage = 0
    
    var body: some View {
        VStack {
            ZStack {
                if currentPage == 0 {
                    WelcomePage().transition(.opacity)
                } else if currentPage == 1 {
                    PermissionsPage(permissionManager: permissionManager).transition(.opacity)
                } else if currentPage == 2 {
                    ShortcutPage(settings: settings).transition(.opacity)
                } else if currentPage == 3 {
                    CompletionPage(settings: settings).transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            HStack {
                if currentPage > 0 {
                    Button(NSLocalizedString("Back", comment: "")) {
                        withAnimation { currentPage -= 1 }
                    }
                }
                
                Spacer()
                
                // Dots indicator
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                if currentPage < 3 {
                    Button(NSLocalizedString("Next", comment: "")) {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(NSLocalizedString("Get Started", comment: "")) {
                        settings.hasCompletedOnboarding = true
                        onboardingWindow?.close()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 520, height: 480)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundStyle(.blue)
            
            Text(NSLocalizedString("Welcome to DexDictate", comment: ""))
                .font(.largeTitle)
                .bold()
            
            Text(NSLocalizedString("Supercharge your dictation with global shortcuts and Whisper-powered accuracy.", comment: ""))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

struct PermissionsPage: View {
    // Track whether the user has clicked the grant button (so we can show Input Monitoring steps)
    @State private var accessibilityRequested = false
    @ObservedObject var permissionManager: PermissionManager
    @StateObject private var microphoneHarness = MicrophoneValidationHarness()
    @State private var triggerValidationState: TriggerValidationState = .idle

    private func syncPermissionSteps() {
        accessibilityRequested = permissionManager.accessibilityGranted || permissionManager.inputMonitoringGranted
    }

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
                        permissionManager.requestAccessibilityIfNeeded()
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
                                permissionManager.openInputMonitoringSettings()
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
            syncPermissionSteps()
            permissionManager.refreshPermissions()
            permissionManager.startMonitoring()
        }
        .onChange(of: permissionManager.accessibilityGranted) { _, _ in
            syncPermissionSteps()
        }
        .onChange(of: permissionManager.inputMonitoringGranted) { _, _ in
            syncPermissionSteps()
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
        VStack(spacing: 20) {
            Text(NSLocalizedString("Choose Your Trigger", comment: ""))
                .font(.title)
            
            Text(NSLocalizedString("Select a shortcut to start dictation. The default is the Middle Mouse Button.", comment: ""))
                .multilineTextAlignment(.center)
            
            ShortcutRecorder(shortcut: $settings.userShortcut)
                .frame(width: 200)
                .padding()
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct CompletionPage: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundStyle(.green)
            
            Text(NSLocalizedString("You're All Set!", comment: ""))
                .font(.title)
            
            Text(NSLocalizedString("DexDictate runs in your menu bar. Click the icon or use your shortcut to start dictating.", comment: ""))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
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
