import AppKit
import ApplicationServices
import Foundation

public struct OutputCoordinator: OutputCoordinating {
    private let writer: OutputWriting
    private let contextInspector: FocusedContextInspecting
    private let applicationActivator: OutputApplicationActivating
    // Read by the Accessibility insertion strategies in
    // `OutputCoordinatorAccessibilityInsertion.swift`, hence not `private`.
    let axOperator: AccessibilityElementOperating

    public init(
        writer: OutputWriting = ClipboardOutputWriter(),
        contextInspector: FocusedContextInspecting = AccessibilityFocusedContextInspector(),
        axOperator: AccessibilityElementOperating = SystemAccessibilityElementOperator()
    ) {
        self.init(
            writer: writer,
            contextInspector: contextInspector,
            applicationActivator: AppKitOutputApplicationActivator(),
            axOperator: axOperator
        )
    }

    init(
        writer: OutputWriting,
        contextInspector: FocusedContextInspecting,
        applicationActivator: OutputApplicationActivating = AppKitOutputApplicationActivator(),
        axOperator: AccessibilityElementOperating = SystemAccessibilityElementOperator()
    ) {
        self.writer = writer
        self.contextInspector = contextInspector
        self.applicationActivator = applicationActivator
        self.axOperator = axOperator
    }

    public func deliver(
        text: String,
        autoPaste: Bool,
        protectSensitiveContexts: Bool,
        insertionMode: InsertionModeOverride = .clipboardPaste,
        targetApplication: OutputTargetApplication? = nil,
        completion: @escaping (OutputDeliveryDecision) -> Void
    ) -> OutputDeliveryDecision {
        guard autoPaste else {
            return OutputDeliveryDecision(delivery: .savedOnly)
        }

        if insertionMode == .clipboardOnly {
            guard writer.copy(text) else {
                return OutputDeliveryDecision(delivery: .failed(reason: "Could not copy text to the clipboard."))
            }
            return OutputDeliveryDecision(delivery: .copiedOnly(reason: "Per-app clipboard-only mode"))
        }

        let didTriggerActivation = activateTargetApplicationIfNeeded(targetApplication)

        if protectSensitiveContexts,
           let sensitiveDecision = sensitiveContextDecision(
               text: text, targetApplication: targetApplication, didTriggerActivation: didTriggerActivation
           ) {
            return sensitiveDecision
        }

        if insertionMode == .replaceFieldWithClipboardPaste {
            return deliverByReplacingField(
                text,
                targetApplication: targetApplication,
                completion: completion
            )
        }

        let outputText = textWithAutoSpacing(text)

        if insertionMode == .accessibilityAPI,
           canAttemptDirectAccessibilityInsertion(for: targetApplication),
           let decision = deliverViaAccessibility(outputText, targetApplication: targetApplication) {
            return decision
        }

        return deliverViaClipboardPaste(
            outputText,
            targetApplication: targetApplication,
            completion: completion
        )
    }

    /// Waits for activation (when needed) and inspects the focused context. Returns a
    /// `.copiedOnly` decision when the field looks sensitive, or `nil` to let `deliver`
    /// continue with normal insertion.
    ///
    /// - Note: `NSRunningApplication.activate()` is asynchronous with no completion callback.
    ///   Without waiting here, `inspectFocusedContext()` can read the *previous* frontmost
    ///   app's focused element — a real secure field in the target app would then be
    ///   misclassified as `.standard` and auto-pasted into. Bounded so a target that never
    ///   actually activates (e.g. it quit mid-flight) can't hang delivery.
    private func sensitiveContextDecision(
        text: String, targetApplication: OutputTargetApplication?, didTriggerActivation: Bool
    ) -> OutputDeliveryDecision? {
        if let targetApplication, didTriggerActivation {
            waitForTargetActivation(targetApplication)
        }
        let context = contextInspector.inspectFocusedContext()
        guard case .sensitive(let reason) = context else { return nil }
        guard writer.copy(text) else {
            return OutputDeliveryDecision(delivery: .failed(reason: "Could not copy text to the clipboard."))
        }
        return OutputDeliveryDecision(delivery: .copiedOnly(reason: reason))
    }

    private func deliverByReplacingField(
        _ text: String,
        targetApplication: OutputTargetApplication?,
        completion: @escaping (OutputDeliveryDecision) -> Void
    ) -> OutputDeliveryDecision {
        guard writer.selectAllAndPaste(
            text,
            targetApplication: targetApplication,
            completion: { completion(OutputDeliveryDecision(delivery: $0)) }
        ) else {
            return OutputDeliveryDecision(delivery: .failed(reason: "Could not copy text for replace-field paste."))
        }
        return OutputDeliveryDecision(
            delivery: .requestedButUnverified
        )
    }

    /// Returns `nil` when direct Accessibility insertion didn't succeed, so the caller falls
    /// through to clipboard paste — matches the pre-refactor inline fallthrough exactly.
    private func deliverViaAccessibility(
        _ outputText: String, targetApplication: OutputTargetApplication?
    ) -> OutputDeliveryDecision? {
        let attempt = insertViaAccessibility(outputText)
        switch attempt {
        case .failed:
            return nil
        case .mutatedButUnverified:
            return OutputDeliveryDecision(delivery: .requestedButUnverified)
        case .confirmed(let previousValue, let replacementRange, let element):
            return OutputDeliveryDecision(
                delivery: .pastedToActiveApp,
                undoContext: DictationUndoContext(
                    insertedText: outputText,
                    previousFieldValue: previousValue,
                    replacementRange: replacementRange,
                    targetApplication: targetApplication,
                    targetElement: element
                )
            )
        }
    }

    private func deliverViaClipboardPaste(
        _ outputText: String,
        targetApplication: OutputTargetApplication?,
        completion: @escaping (OutputDeliveryDecision) -> Void
    ) -> OutputDeliveryDecision {
        guard writer.copyAndPaste(
            outputText,
            targetApplication: targetApplication,
            completion: { completion(OutputDeliveryDecision(delivery: $0)) }
        ) else {
            return OutputDeliveryDecision(delivery: .failed(reason: "Could not copy text for paste."))
        }
        return OutputDeliveryDecision(
            delivery: .requestedButUnverified
        )
    }

    /// Prepends a space to `text` when it's about to be inserted immediately after a
    /// sentence-ending period with no space in between (e.g. cursor right after "...done."),
    /// which otherwise produces "done.Nexttext" when dictation lands mid-flow between fields.
    /// Reads the focused element's value and cursor position via the Accessibility API;
    /// returns `text` unchanged whenever that isn't available (no AX element, cursor at the
    /// very start of the field, `text` already starts with whitespace, or the preceding
    /// character isn't a period).
    ///
    /// Reads the *committed* value, not the raw one: an empty web composer reports its
    /// placeholder through `kAXValueAttribute`, and inspecting that string would decide
    /// spacing from the character before a cursor offset that indexes into decoration.
    private func textWithAutoSpacing(_ text: String) -> String {
        guard let firstScalar = text.unicodeScalars.first,
              !CharacterSet.whitespacesAndNewlines.contains(firstScalar) else {
            return text
        }
        guard let element = axOperator.focusedElement() else { return text }
        let snapshot = axOperator.editableTextSnapshot(element: element)
        guard let currentValue = snapshot.committedValue,
              let selectedRange = snapshot.logicalRange,
              selectedRange.location > 0 else {
            return text
        }

        let currentNSString = currentValue as NSString
        guard selectedRange.location <= currentNSString.length else { return text }
        let precedingCharacter = currentNSString.substring(
            with: NSRange(location: selectedRange.location - 1, length: 1)
        )
        guard precedingCharacter == "." else { return text }

        return " " + text
    }

    /// Returns `true` when it actually called `activate()` — i.e. the target existed, wasn't
    /// us, and wasn't already frontmost — which is exactly when the caller needs to worry
    /// about activation still being in flight.
    @discardableResult
    private func activateTargetApplicationIfNeeded(_ targetApplication: OutputTargetApplication?) -> Bool {
        guard let targetApplication else { return false }
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        guard targetApplication.processIdentifier != currentProcessIdentifier else {
            return false
        }
        guard targetApplication.processIdentifier != applicationActivator.frontmostProcessIdentifier else {
            return false
        }

        applicationActivator.activate(targetApplication)
        return true
    }

    /// Spins the run loop (not a hard `Thread.sleep`) until `targetApplication` actually
    /// becomes frontmost, or `timeout` elapses. Bounded so a target that never activates
    /// (e.g. it quit between capture and delivery) can't hang dictation delivery.
    private func waitForTargetActivation(
        _ targetApplication: OutputTargetApplication,
        timeout: TimeInterval = 0.15
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while applicationActivator.frontmostProcessIdentifier != targetApplication.processIdentifier,
              Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }

    private func canAttemptDirectAccessibilityInsertion(for targetApplication: OutputTargetApplication?) -> Bool {
        guard let targetApplication else { return true }
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        guard targetApplication.processIdentifier != currentProcessIdentifier else {
            return false
        }
        guard targetApplication.processIdentifier == applicationActivator.frontmostProcessIdentifier else {
            Safety.log(
                "OutputCoordinator — skipping direct Accessibility insertion because target application is not frontmost; falling back to clipboard paste.",
                category: .output
            )
            return false
        }
        return true
    }

}
