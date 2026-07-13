import AppKit
import DexDictateKit

/// The one "Restore Defaults?" alert shared by every user-facing Restore Defaults control —
/// Settings → General's button and the classic (non-slim) popover footer's link. Both call
/// through here instead of presenting their own `NSAlert`, so the wording and the
/// confirm-before-reset gate (`AppSettings.restoreDefaults(ifConfirmedBy:)`) can never drift
/// apart between the two surfaces.
enum RestoreDefaultsPrompt {
    @discardableResult
    static func confirmAndRestore(_ settings: AppSettings) -> Bool {
        settings.restoreDefaults {
            let alert = NSAlert()
            alert.messageText = "Restore Defaults?"
            alert.informativeText = "This resets shortcuts, input device, model selection, theme, and custom profanity word lists to their factory defaults. This cannot be undone."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Restore Defaults")
            alert.addButton(withTitle: "Cancel")
            return alert.runModal() == .alertFirstButtonReturn
        }
    }
}
