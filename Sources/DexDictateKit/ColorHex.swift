import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Hex <-> `Color` conversion used to persist the user-selected status accent
/// color in `UserDefaults` (SwiftUI `Color` is not directly storable).
public extension Color {
    /// Parses a 6-digit RGB hex string (`"#34C759"` or `"34c759"`).
    /// Returns `nil` for anything that is not exactly six hex digits.
    init?(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6, let value = UInt32(string, radix: 16) else { return nil }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self = Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }

    /// Renders the color as an uppercase `#RRGGBB` string in the sRGB space.
    func hexString() -> String {
        #if canImport(AppKit)
        let resolved = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let red = Int((resolved.redComponent * 255).rounded())
        let green = Int((resolved.greenComponent * 255).rounded())
        let blue = Int((resolved.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
        #else
        return "#000000"
        #endif
    }
}
