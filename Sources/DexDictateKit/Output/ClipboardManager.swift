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
        let deliveryProfile = PasteDeliveryProfile.resolve(for: targetApplication)

        // Preserve the full pasteboard payload instead of flattening it to plain text.
        let originalItems = pasteboard.pasteboardItems?.compactMap { item in
            item.copy() as? NSPasteboardItem
        }

        copy(text)
        let dictationChangeCount = pasteboard.changeCount

        activateTargetApplication(targetApplication)
        schedulePaste(using: deliveryProfile, targetApplication: targetApplication)

        // Restore the clipboard only if DexDictate still owns the current string payload.
        let restoreDelay = deliveryProfile.initialDelay + deliveryProfile.activationTimeout + clipboardRestoreDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
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
}
