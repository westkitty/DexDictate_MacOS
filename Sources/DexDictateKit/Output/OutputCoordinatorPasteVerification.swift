import AppKit
import ApplicationServices
import Foundation

// Post-paste verification, split out of `OutputCoordinator.swift` to keep that type's body
// within the project's length limit. A dispatched Cmd-V is not evidence of anything on its
// own; these members turn it into an exact observation of the saved element.

extension OutputCoordinator {
    /// Reads the target *before* Cmd-V. Returns `nil` when there is no readable element, in
    /// which case the paste simply stays unverified — exactly today's behaviour, never worse.
    func pastePreDispatchRecord(
        insertedText: String,
        targetApplication: OutputTargetApplication?
    ) -> PastePreDispatchRecord? {
        guard let element = axOperator.focusedElement() else { return nil }
        let snapshot = axOperator.editableTextSnapshot(element: element)
        return PastePreDispatchRecord(
            element: element,
            targetApplication: targetApplication,
            role: snapshot.role,
            subrole: snapshot.subrole,
            rawValue: snapshot.rawValue,
            committedValue: snapshot.committedValue,
            emptiness: snapshot.emptiness,
            selectedRange: snapshot.selectedRange,
            insertedText: insertedText
        )
    }

    /// Polls the saved element on the main queue until the paste is observable, then reports a
    /// verified insertion (with a reversible context) or leaves the delivery unverified.
    func verifyDispatchedPaste(
        _ record: PastePreDispatchRecord,
        completion: @escaping (OutputDeliveryDecision) -> Void
    ) {
        PastedInsertionVerifier(axOperator: axOperator).verify(
            record,
            schedule: { delay, work in
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            },
            // Supersession is enforced upstream by `applyDeliveryCompletion`, which drops any
            // decision whose delivery ID is no longer current.
            isStillCurrent: { true },
            completion: { outcome in
                Safety.log("clipboard paste verification — \(outcome.diagnosticLabel)", category: .output)
                completion(Self.decision(for: outcome, record: record))
            }
        )
    }

    static func decision(
        for outcome: PasteVerificationOutcome,
        record: PastePreDispatchRecord
    ) -> OutputDeliveryDecision {
        switch outcome {
        case .verifiedKnownContent(let postValue, let previousValue, let range):
            return OutputDeliveryDecision(
                delivery: .pastedToActiveApp,
                undoContext: DictationUndoContext(
                    insertedText: record.insertedText,
                    previousFieldValue: previousValue,
                    replacementRange: range,
                    targetApplication: record.targetApplication,
                    targetElement: record.element,
                    restoration: .knownPreviousValue,
                    verifiedPostDeliveryValue: postValue
                )
            )
        case .verifiedLogicallyEmpty(let postValue, let presentationValue):
            return OutputDeliveryDecision(
                delivery: .pastedToActiveApp,
                undoContext: DictationUndoContext(
                    insertedText: record.insertedText,
                    previousFieldValue: "",
                    replacementRange: NSRange(location: 0, length: 0),
                    targetApplication: record.targetApplication,
                    targetElement: record.element,
                    restoration: .logicallyEmptyEditor(presentationValue: presentationValue),
                    verifiedPostDeliveryValue: postValue
                )
            )
        case .noChange:
            return OutputDeliveryDecision(
                delivery: .failed(reason: "The paste did not reach the field. Text remains on the clipboard.")
            )
        case .unexplainedChange, .targetUnavailable:
            return OutputDeliveryDecision(delivery: .requestedButUnverified)
        }
    }
}
