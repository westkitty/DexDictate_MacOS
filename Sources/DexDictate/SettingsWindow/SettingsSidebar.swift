import SwiftUI

/// Sidebar navigation for the Settings window, listing all 11 pages in fixed order.
struct SettingsSidebar: View {
    @Binding var selection: SettingsPage

    var body: some View {
        List(SettingsPage.allCases, selection: $selection) { page in
            Label(page.title, systemImage: page.systemImage)
                .tag(page)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 190)
    }
}
