import AppKit
import Foundation

/// Centralises the `x-apple.systempreferences:` deep-link URLs for the three TCC
/// permissions required by DexDictate and provides a single open-or-fallback entry point.
///
/// Usage:
/// ```swift
/// PermissionSettingsLinker.open(.microphone)
/// ```
public enum PermissionSettingsLinker {

    // MARK: - Permission cases

    public enum Permission {
        case microphone
        case accessibility
        case inputMonitoring
        case speechRecognition
    }

    // MARK: - URL construction

    /// Returns the deep-link URL for the given permission pane, or `nil` if the string
    /// fails to parse (should never happen in practice).
    public static func url(for permission: Permission) -> URL? {
        let string: String
        switch permission {
        case .microphone:
            string = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            string = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .inputMonitoring:
            string = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        case .speechRecognition:
            string = "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
        }
        return URL(string: string)
    }

    /// Fallback URL that opens the top-level Privacy & Security pane.
    public static let fallbackURL: URL? = URL(string: "x-apple.systempreferences:com.apple.preference.security")

    // MARK: - Open helpers

    /// Opens the System Settings pane for `permission`, degrading gracefully to the
    /// top-level Privacy & Security pane if the deep-link URL cannot be constructed.
    public static func open(_ permission: Permission) {
        let target = url(for: permission) ?? fallbackURL
        guard let target else { return }
        NSWorkspace.shared.open(target)
    }

    /// Opens the fallback Privacy & Security pane directly.
    public static func openFallback() {
        guard let url = fallbackURL else { return }
        NSWorkspace.shared.open(url)
    }
}
