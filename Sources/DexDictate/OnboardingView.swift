import SwiftUI
import DexDictateKit

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    var onboardingWindow: NSWindow?
    
    // We can use a TabView for pages
    @State private var currentPage = 0
    
    var body: some View {
        VStack {
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
