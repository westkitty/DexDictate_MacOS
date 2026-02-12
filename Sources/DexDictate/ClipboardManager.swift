import AppKit

/// Writes text to the system pasteboard and simulates a Cmd+V keystroke to paste it into
/// the currently focused application.
///
/// - Important: Requires the Accessibility entitlement and user approval so that
///   `CGEvent.post(tap:)` is permitted to inject synthetic keyboard events.
enum ClipboardManager {

    /// Copies `text` to the general pasteboard, then simulates Cmd+V in the frontmost app.
    ///
    /// - Parameter text: The string to copy and paste.
    static func copyAndPaste(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        simulatePaste()
    }

    private static func simulatePaste() {
        let src = CGEventSource(stateID: .hidSystemState)

        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: false)

        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand

        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}
