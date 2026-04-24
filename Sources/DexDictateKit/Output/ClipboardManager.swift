import AppKit

/// Writes text to the system pasteboard and simulates a Cmd+V keystroke to paste it into
/// the currently focused application.
///
/// - Important: Requires the Accessibility entitlement and user approval so that
///   `CGEvent.post(tap:)` is permitted to inject synthetic keyboard events.
enum ClipboardManager {
    private static let targetActivationDelay: TimeInterval = 0.08
    private static let clipboardRestoreDelay: TimeInterval = 1.0

    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Copies `text` to the general pasteboard, then simulates Cmd+V in the frontmost app.
    /// The clipboard is automatically cleared after paste to prevent data leakage.
    ///
    /// - Parameter text: The string to copy and paste.
    static func copyAndPaste(_ text: String, targetApplication: OutputTargetApplication?) {
        let pasteboard = NSPasteboard.general

        // Preserve the full pasteboard payload instead of flattening it to plain text.
        let originalItems = pasteboard.pasteboardItems?.compactMap { item in
            item.copy() as? NSPasteboardItem
        }

        copy(text)
        let dictationChangeCount = pasteboard.changeCount

        DispatchQueue.main.asyncAfter(deadline: .now() + targetActivationDelay) {
            simulatePaste()
        }

        // Restore the clipboard only if DexDictate still owns the current string payload.
        DispatchQueue.main.asyncAfter(deadline: .now() + targetActivationDelay + clipboardRestoreDelay) {
            guard pasteboard.changeCount == dictationChangeCount,
                  pasteboard.string(forType: .string) == text else {
                return
            }

            pasteboard.clearContents()
            if let originalItems, !originalItems.isEmpty {
                pasteboard.writeObjects(originalItems)
            }
        }
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
