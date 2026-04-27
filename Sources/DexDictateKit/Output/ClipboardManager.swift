import AppKit

/// Writes text to the system pasteboard and simulates a Cmd+V keystroke to paste it into
/// the currently focused application.
///
/// - Important: Requires the Accessibility entitlement and user approval so that
///   `CGEvent.post(tap:)` is permitted to inject synthetic keyboard events.
enum ClipboardManager {
    struct SavedPasteboardContents {
        let hadOriginalContents: Bool
        let items: [SavedPasteboardItem]

        func makePasteboardItems() -> [NSPasteboardItem] {
            items.map { $0.makePasteboardItem() }
        }
    }

    struct SavedPasteboardItem {
        let representations: [SavedPasteboardRepresentation]

        var isEmpty: Bool {
            representations.isEmpty
        }

        func makePasteboardItem() -> NSPasteboardItem {
            let item = NSPasteboardItem()
            for representation in representations {
                representation.apply(to: item)
            }
            return item
        }
    }

    struct SavedPasteboardRepresentation {
        enum Value {
            case data(Data)
            case string(String)
            case propertyList(Any)
        }

        let type: NSPasteboard.PasteboardType
        let value: Value

        func apply(to item: NSPasteboardItem) {
            switch value {
            case .data(let data):
                item.setData(data, forType: type)
            case .string(let string):
                item.setString(string, forType: type)
            case .propertyList(let propertyList):
                item.setPropertyList(propertyList, forType: type)
            }
        }
    }

    private static let targetActivationDelay: TimeInterval = 0.08
    private static let clipboardRestoreDelay: TimeInterval = 1.0

    static func copy(_ text: String) {
        runOnMainThread {
            writeString(text, to: NSPasteboard.general)
        }
    }

    /// Copies `text` to the general pasteboard, then simulates Cmd+V in the frontmost app.
    /// The clipboard is automatically cleared after paste to prevent data leakage.
    ///
    /// - Parameter text: The string to copy and paste.
    static func copyAndPaste(_ text: String, targetApplication: OutputTargetApplication?) {
        _ = targetApplication

        runOnMainThread {
            let pasteboard = NSPasteboard.general

            // Preserve the full pasteboard payload instead of flattening it to plain text.
            let originalContents = clonePasteboardItems(pasteboard.pasteboardItems)

            writeString(text, to: pasteboard)
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

                restorePasteboardContents(originalContents, to: pasteboard, fallbackText: text)
            }
        }
    }

    static func clonePasteboardItem(_ source: NSPasteboardItem) -> NSPasteboardItem {
        snapshotPasteboardItem(source).makePasteboardItem()
    }

    static func clonePasteboardItems(_ items: [NSPasteboardItem]?) -> SavedPasteboardContents {
        let sourceItems = items ?? []
        let clonedItems = sourceItems
            .map { snapshotPasteboardItem($0) }
            .filter { !$0.isEmpty }

        return SavedPasteboardContents(
            hadOriginalContents: !sourceItems.isEmpty,
            items: clonedItems
        )
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

    private static func restorePasteboardContents(
        _ contents: SavedPasteboardContents,
        to pasteboard: NSPasteboard,
        fallbackText: String
    ) {
        guard contents.hadOriginalContents else {
            pasteboard.clearContents()
            return
        }

        guard !contents.items.isEmpty else {
            Safety.log("Clipboard restore skipped because the original clipboard contents could not be cloned safely.")
            writeString(fallbackText, to: pasteboard)
            return
        }

        let restoredItems = contents.makePasteboardItems()
        pasteboard.clearContents()
        guard pasteboard.writeObjects(restoredItems) else {
            Safety.log("Clipboard restore failed; leaving dictation text on the clipboard.")
            writeString(fallbackText, to: pasteboard)
            return
        }
    }

    private static func snapshotPasteboardItem(_ source: NSPasteboardItem) -> SavedPasteboardItem {
        let representations = source.types.compactMap { type -> SavedPasteboardRepresentation? in
            if let data = source.data(forType: type) {
                return SavedPasteboardRepresentation(type: type, value: .data(data))
            }

            if let string = source.string(forType: type) {
                return SavedPasteboardRepresentation(type: type, value: .string(string))
            }

            if let propertyList = source.propertyList(forType: type) {
                return SavedPasteboardRepresentation(type: type, value: .propertyList(propertyList))
            }

            return nil
        }

        return SavedPasteboardItem(representations: representations)
    }

    private static func writeString(_ text: String, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            Safety.log("Writing dictation text to the clipboard failed.")
            return
        }
    }

    private static func runOnMainThread(_ work: () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }
}
