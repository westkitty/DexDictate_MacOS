import AppKit

struct PasteDeliveryProfile: Equatable {
    let initialDelay: TimeInterval
    let activationTimeout: TimeInterval
    let activationPollInterval: TimeInterval
    let postsToTargetProcess: Bool

    static func resolve(for targetApplication: OutputTargetApplication?) -> PasteDeliveryProfile {
        let bundleIdentifier = targetApplication?.bundleIdentifier.lowercased() ?? ""
        if bundleIdentifier.hasPrefix("us.zoom.") {
            return PasteDeliveryProfile(
                initialDelay: 0.22,
                activationTimeout: 0.45,
                activationPollInterval: 0.02,
                postsToTargetProcess: true
            )
        }

        return PasteDeliveryProfile(
            initialDelay: 0.12,
            activationTimeout: 0.20,
            activationPollInterval: 0.02,
            postsToTargetProcess: true
        )
    }
}

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
        runOnMainThread {
            let pasteboard = NSPasteboard.general
            let deliveryProfile = PasteDeliveryProfile.resolve(for: targetApplication)

            // Preserve the full pasteboard payload instead of flattening it to plain text.
            let originalContents = clonePasteboardItems(pasteboard.pasteboardItems)

            writeString(text, to: pasteboard)
            let dictationChangeCount = pasteboard.changeCount

            activateTargetApplication(targetApplication)
            schedulePaste(using: deliveryProfile, targetApplication: targetApplication)

            // Restore the clipboard only if DexDictate still owns the current string payload.
            let restoreDelay = deliveryProfile.initialDelay + deliveryProfile.activationTimeout + clipboardRestoreDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
                guard shouldRestoreClipboard(
                    currentChangeCount: pasteboard.changeCount,
                    currentStringPayload: pasteboard.string(forType: .string),
                    dictationChangeCount: dictationChangeCount,
                    dictationPayload: text
                ) else {
                    return
                }

                restorePasteboardContents(originalContents, to: pasteboard, fallbackText: text)
            }
        }
    }

    static func clonePasteboardItem(_ source: NSPasteboardItem) -> NSPasteboardItem {
        snapshotPasteboardItem(source).makePasteboardItem()
    }

    static func shouldRestoreClipboard(
        currentChangeCount: Int,
        currentStringPayload: String?,
        dictationChangeCount: Int,
        dictationPayload: String
    ) -> Bool {
        currentChangeCount == dictationChangeCount &&
        currentStringPayload == dictationPayload
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

    private static func schedulePaste(
        using profile: PasteDeliveryProfile,
        targetApplication: OutputTargetApplication?
    ) {
        let deadline = Date().addingTimeInterval(profile.initialDelay + profile.activationTimeout)
        DispatchQueue.main.asyncAfter(deadline: .now() + profile.initialDelay) {
            waitForTargetActivationAndPaste(
                targetApplication: targetApplication,
                profile: profile,
                deadline: deadline
            )
        }
    }

    private static func waitForTargetActivationAndPaste(
        targetApplication: OutputTargetApplication?,
        profile: PasteDeliveryProfile,
        deadline: Date
    ) {
        guard let targetApplication else {
            simulatePaste(targetProcessIdentifier: nil)
            return
        }

        if isFrontmost(targetApplication) {
            let targetProcessIdentifier = profile.postsToTargetProcess ? targetApplication.processIdentifier : nil
            simulatePaste(targetProcessIdentifier: targetProcessIdentifier)
            return
        }

        if Date() >= deadline {
            let targetProcessIdentifier = profile.postsToTargetProcess ? targetApplication.processIdentifier : nil
            simulatePaste(targetProcessIdentifier: targetProcessIdentifier)
            return
        }

        activateTargetApplication(targetApplication)
        DispatchQueue.main.asyncAfter(deadline: .now() + profile.activationPollInterval) {
            waitForTargetActivationAndPaste(
                targetApplication: targetApplication,
                profile: profile,
                deadline: deadline
            )
        }
    }

    private static func activateTargetApplication(_ targetApplication: OutputTargetApplication?) {
        guard let targetApplication,
              targetApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let app = NSRunningApplication(processIdentifier: targetApplication.processIdentifier) else {
            return
        }

        _ = app.activate(options: [])
    }

    private static func isFrontmost(_ targetApplication: OutputTargetApplication) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == targetApplication.processIdentifier
    }

    private static func simulatePaste(targetProcessIdentifier: pid_t?) {
        let src = CGEventSource(stateID: .hidSystemState)

        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: false)

        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand

        post(cmdDown, targetProcessIdentifier: targetProcessIdentifier)
        post(vDown, targetProcessIdentifier: targetProcessIdentifier)
        post(vUp, targetProcessIdentifier: targetProcessIdentifier)
        post(cmdUp, targetProcessIdentifier: targetProcessIdentifier)
    }

    private static func post(_ event: CGEvent?, targetProcessIdentifier: pid_t?) {
        guard let event else { return }

        if let targetProcessIdentifier, targetProcessIdentifier > 0 {
            event.postToPid(targetProcessIdentifier)
            return
        }

        event.post(tap: .cghidEventTap)
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
