import SwiftUI
import DexDictateKit

/// Footer bar containing Restore Defaults, About link, and version string.
struct FooterView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 6) {
            Button(action: { settings.restoreDefaults() }) {
                Text(NSLocalizedString("Restore Defaults", comment: ""))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)

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

            Text(String(format: NSLocalizedString("DexDictate macOS v%@", comment: ""),
                         Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
                .fixedSize()
                .padding(.bottom, 10)
        }
    }
}
