import SwiftUI
import DexDictateKit

/// Footer bar containing Restore Defaults, About link, and version string.
struct FooterView: View {
    @ObservedObject var settings: AppSettings
    var onHiddenDebugTrigger: () -> Void = {}
    @State private var hiddenDebugTapCount = 0
    @State private var hiddenDebugLastTapAt: Date?

    var body: some View {
        VStack(spacing: 6) {
            Button(action: { settings.restoreDefaults() }) {
                Text(NSLocalizedString("Restore Defaults", comment: ""))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button(action: {
                    if let url = URL(string: "https://github.com/WestKitty/DexDictate_MacOS") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text(NSLocalizedString("About", comment: "Footer about link"))
                        .font(.caption2)
                        .underline()
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                // Invisible debug trigger: triple-tap to reopen onboarding.
                Button(action: registerHiddenDebugTap) {
                    Color.clear
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
            }

            Text(String(format: NSLocalizedString("DexDictate macOS v%@", comment: ""),
                         Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
                .fixedSize()
                .padding(.bottom, 10)
        }
    }

    private func registerHiddenDebugTap() {
        let now = Date()
        let isWithinBurstWindow: Bool
        if let lastTap = hiddenDebugLastTapAt {
            isWithinBurstWindow = now.timeIntervalSince(lastTap) <= 1.6
        } else {
            isWithinBurstWindow = false
        }

        hiddenDebugTapCount = isWithinBurstWindow ? (hiddenDebugTapCount + 1) : 1
        hiddenDebugLastTapAt = now

        if hiddenDebugTapCount >= 3 {
            hiddenDebugTapCount = 0
            hiddenDebugLastTapAt = nil
            onHiddenDebugTrigger()
        }
    }
}
