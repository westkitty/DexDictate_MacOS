import SwiftUI

/// Shared placeholder body used by every Settings page stub in Packet 02.
/// Later packets replace this content with real controls, one page at a time.
struct SettingsPagePlaceholder: View {
    let title: String
    let message: String

    init(title: String, message: String = "Settings for this section will move here.") {
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.bold())
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
