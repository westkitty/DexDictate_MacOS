import SwiftUI

enum SurfaceTokens {
    static let sectionSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 10
    static let cornerRadius: CGFloat = 10
    static let capsuleHorizontal: CGFloat = 10
    static let capsuleVertical: CGFloat = 5
}

/// Calibrated semantic colours for the dark-glass UI.
///
/// These replace full-saturation primaries (pure red/green/yellow) with
/// Tailwind-style values that look intentional rather than debug-like
/// on a translucent dark background.
enum SemanticColors {
    // State colours
    static let listening    = Color(red: 0.937, green: 0.267, blue: 0.267) // red-500
    static let transcribing = Color(red: 0.918, green: 0.702, blue: 0.031) // yellow-500
    static let ready        = Color(red: 0.133, green: 0.773, blue: 0.369) // green-500
    static let error        = Color(red: 0.976, green: 0.451, blue: 0.086) // orange-500
    static let initializing = Color(red: 0.369, green: 0.647, blue: 0.984) // blue-400
    static let stopped      = Color(red: 0.620, green: 0.620, blue: 0.620) // gray-400

    // Accent
    static let accent       = Color(red: 0.133, green: 0.827, blue: 0.933) // cyan-400

    // Background tint helpers (use with opacity)
    static func tint(_ color: Color, opacity: Double = 0.10) -> Color {
        color.opacity(opacity)
    }
}
