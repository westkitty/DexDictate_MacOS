import SwiftUI

/// Footer bar containing Restore Defaults, About link, and version string.
struct FooterView: View {
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(spacing: 6) {
            Button(action: { settings.restoreDefaults() }) {
                Text("Restore Defaults")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)

            Button(action: {
                if let url = URL(string: "https://github.com/WestKitty/DexDictate_MacOS") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("About")
                    .font(.caption2)
                    .underline()
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)

            Text("DexDictate macOS v1.0")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
                .fixedSize()
                .padding(.bottom, 10)
        }
    }
}
