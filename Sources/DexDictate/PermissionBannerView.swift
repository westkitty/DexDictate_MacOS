import SwiftUI
import DexDictateKit

/// Contextual banner displayed when one or more required permissions are missing.
///
/// The banner is hidden (`EmptyView`) when `permissionManager.allPermissionsGranted` is
/// `true`, so it imposes no layout cost when permissions are satisfied.
struct PermissionBannerView: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        if !permissionManager.allPermissionsGranted {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(permissionManager.permissionsSummary)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                Button(NSLocalizedString("Open Settings", comment: "")) {
                    if let url = permissionManager.settingsURL {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption2)
            }
            .padding(8)
            .background(Color.orange.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
        }
    }
}
