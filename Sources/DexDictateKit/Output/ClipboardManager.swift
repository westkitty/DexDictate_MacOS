import AppKit
import ApplicationServices

/// Writes text to the system pasteboard and simulates a Cmd+V keystroke to paste it into
/// the currently focused application.
///
/// - Important: Requires the Accessibility entitlement and user approval so that
///   `CGEvent.post(tap:)` is permitted to inject synthetic keyboard events.
enum ClipboardManager {
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Copies `text` to the general pasteboard, then simulates Cmd+V in the frontmost app.
    /// The clipboard is automatically cleared after paste to prevent data leakage.
    ///
    /// - Parameter text: The string to copy and paste.
    static func copyAndPaste(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Store original clipboard content to restore it
        let originalContent = pasteboard.string(forType: .string)

        copy(text)
        simulatePaste()

        // Clear clipboard after paste completes (with slight delay to ensure paste succeeds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pasteboard.clearContents()
            // Restore original clipboard content if it existed
            if let original = originalContent {
                pasteboard.setString(original, forType: .string)
            }
        }
    }

    /// Inserts `text` at the cursor position of the focused UI element using the
    /// Accessibility API. Returns `true` on success. Does not touch the clipboard.
    ///
    /// Works for standard text fields, NSTextView, and most SwiftUI text inputs.
    /// Does NOT work for: web browser address bars, some Electron apps, Terminal.
    @discardableResult
    static func insertViaAccessibility(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedValue = focusedRef else { return false }

        let element = unsafeBitCast(focusedValue, to: AXUIElement.self)

        // Verify the element supports setting selected text
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        guard settable.boolValue else { return false }

        // Setting kAXSelectedTextAttribute replaces the current selection with `text`,
        // or inserts at cursor if nothing is selected. Preserves surrounding text.
        return AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
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
