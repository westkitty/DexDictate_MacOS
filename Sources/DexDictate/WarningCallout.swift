import SwiftUI

/// Consistent alert-style callout for destructive/risky-action warnings (Packet 15).
/// Presentation only — every existing warning's text is unchanged, just restyled with an
/// icon + tinted background instead of plain colored text.
struct WarningCallout: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .padding(.top, 1)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.orange.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: SurfaceTokens.cornerRadius))
    }
}
