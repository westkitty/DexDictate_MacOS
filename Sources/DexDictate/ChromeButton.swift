import SwiftUI

struct ChromeIconButton: View {
    let systemName: String
    let accessibilityText: String
    /// Icon tint. Defaults to white, preserving every existing call site's appearance
    /// (detached windows like History/Help don't follow `settings.appearanceTheme`).
    /// The popover header passes a theme-aware tint to fix the Minimalist seam (Packet 11).
    /// Declared before `action` so trailing-closure call sites are unaffected.
    var tint: Color = .white
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint.opacity(isHovered ? 0.92 : 0.6))
                .frame(width: 28, height: 28)
                .background(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.white.opacity(isHovered ? 0.18 : 0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel(accessibilityText)
    }
}
