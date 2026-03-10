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
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Permissions Need Attention")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(permissionManager.permissionsSummary)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                Button(NSLocalizedString("Open Privacy Settings", comment: "")) {
                    if let url = permissionManager.settingsURL {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("Open privacy settings")
            }
            .padding(SurfaceTokens.cardPadding)
            .background(Color.orange.opacity(0.24))
            .overlay(
                RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius)
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
            .padding(.horizontal)
        }
    }
}
