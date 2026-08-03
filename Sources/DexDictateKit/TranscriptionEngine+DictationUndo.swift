import Foundation

/// How long after an undo attempt the "nothing reversible to undo" notice stays suppressed.
/// Matches `UndoUnavailableNoticeRateLimiter`'s default interval so a burst of chord presses
/// resolves to exactly one truthful message.
private let undoUnavailableNoticeSuppressionWindow: TimeInterval = 1.5

/// "Undo Last Dictation" glue for `TranscriptionEngine`, split into its own file so this
/// feature's code doesn't grow `TranscriptionEngine.swift`'s already-oversized type body.
/// Reads/writes `dictationUndoManager` and `pendingFocusSnapshot`, both declared internal
/// (not `private`) in the main file for exactly this reason.
extension TranscriptionEngine {
    /// Republishes `canUndoLastDictation` from the authoritative manager. Every mutation of
    /// the undo record goes through `armUndo`/`disarmUndo`/`undoLastDictation()`, all of
    /// which end here, so the published value cannot drift from the manager.
    func syncUndoAvailability() {
        let authoritative = dictationUndoManager.availability
        if undoAvailability != authoritative {
            undoAvailability = authoritative
        }
    }

    /// The only production path that arms undo. Keeps the manager and the published mirror
    /// in lockstep.
    private func armUndo(_ record: DictationUndoRecord) {
        dictationUndoManager.record(record)
        syncUndoAvailability()
    }

    /// The only production path that clears undo. Safe to call when nothing is armed.
    /// Not `private`: `stopSystem()` in TranscriptionEngine.swift invalidates undo too.
    func disarmUndo(reason: DictationUndoUnavailableReason) {
        dictationUndoManager.clear(reason: reason)
        syncUndoAvailability()
    }

    /// Supersedes both a pending delivery callback and any older undo record as soon as a
    /// later delivery cycle begins, including cycles that are later cancelled or fail.
    func beginDeliveryCycle() {
        pendingDeliveryID = nil
        pendingDeliveryFocusSnapshot = nil
        disarmUndo(reason: .supersededByNewerDictation)
    }

    /// Applies a delivery result that arrived asynchronously. A callback from a superseded
    /// delivery cycle is dropped here rather than being allowed to overwrite feedback or
    /// undo state belonging to a newer cycle.
    func applyDeliveryCompletion(
        _ decision: OutputDeliveryDecision,
        deliveryID: UUID,
        modified: Bool
    ) {
        guard pendingDeliveryID == deliveryID else { return }
        applyDeliveryDecision(decision, modified: modified)
    }

    /// Applies one delivery result to feedback and the single-slot undo record. Every result
    /// clears older undo state first; only a confirmed Accessibility write with complete
    /// pre-insertion and focus context replaces it with a reversible record.
    /// `awaitingVerification` is set only for the *synchronous* result of a dispatched
    /// clipboard paste, whose real outcome arrives later from post-paste verification. It makes
    /// the undo row say "checking…" instead of asserting the delivery was unreversible, which
    /// would be replaced moments later anyway.
    func applyDeliveryDecision(
        _ decision: OutputDeliveryDecision,
        modified: Bool,
        awaitingVerification: Bool = false
    ) {
        recordDictationUndoIfNeeded(decision, awaitingVerification: awaitingVerification)

        switch decision.delivery {
        case .savedOnly:
            resultFeedback = .savedToHistory(modified: modified)
            onToast?(.outputSavedOnly)
        case .pastedToActiveApp:
            resultFeedback = .pastedToActiveApp(modified: modified)
            onToast?(.outputInserted)
        case .copiedOnly(let reason):
            resultFeedback = .copiedOnlySensitiveContext(modified: modified, reason: reason)
            onToast?(.clipboardFallback(reason: reason))
        case .requestedButUnverified:
            resultFeedback = .pasteRequestedUnverified(modified: modified)
            onToast?(.outputPasteUnverified)
        case .blocked(let reason):
            resultFeedback = .deliveryBlocked(modified: modified, reason: reason)
            onToast?(.outputBlocked(reason: reason))
        case .failed(let reason):
            resultFeedback = .deliveryFailed(modified: modified, reason: reason)
            onToast?(.outputFailed(reason: reason))
        }
    }

    private func recordDictationUndoIfNeeded(
        _ decision: OutputDeliveryDecision,
        awaitingVerification: Bool = false
    ) {
        // The reason is what the disabled control will show, so it must name the *actual*
        // delivery outcome. "The undo button never appeared" was previously indistinguishable
        // from "this delivery was never reversible in the first place".
        let pendingPasteVerification = awaitingVerification && decision.delivery == .requestedButUnverified
        disarmUndo(
            reason: pendingPasteVerification
                ? .verificationPending
                : .deliveryNotReversible(decision.delivery.undoIneligibilityDetail)
        )
        guard decision.delivery == .pastedToActiveApp,
              let undoContext = decision.undoContext,
              undoContext.previousFieldValue != nil,
              undoContext.replacementRange != nil,
              undoContext.targetElement != nil else { return }
        // Falls back to the delivery-scoped snapshot: an asynchronously verified paste lands
        // after `finalizeTranscription` has already cleared `pendingFocusSnapshot`.
        let focusSnapshot = pendingFocusSnapshot ?? pendingDeliveryFocusSnapshot
        armUndo(
            DictationUndoRecord(
                focusSnapshot: focusSnapshot,
                context: undoContext,
                timestamp: Date()
            )
        )
    }

    /// Reverses the most recently pasted dictation directly in the target app — without
    /// touching its clipboard or its own undo stack. See `DictationUndoManager` for the
    /// verification strategies this goes through before it will actually delete anything.
    public func undoLastDictation(invocation: DictationUndoInvocation = .popoverButton) {
        // Outcomes that are only *temporarily* unverifiable retain the record, so the mirror
        // must be refreshed from the manager on every branch below rather than assumed false.
        defer { syncUndoAvailability() }
        lastUndoAttemptAt = Date()

        let outcome = dictationUndoManager.undoLastDictation(invocation: invocation)
        Safety.log(
            "Undo attempt — source=\(invocation) outcome=\(outcome) retained=\(!outcome.consumesRecord)",
            category: .output
        )

        guard outcome != .undone else {
            statusText = NSLocalizedString("Dictation undone", comment: "")
            resultFeedback = .dictationUndone
            onToast?(.dictationUndone)
            return
        }

        let reason = Self.undoFailureReason(for: outcome, invocation: invocation)
        statusText = outcome == .nothingToUndo
            ? NSLocalizedString("Nothing to undo", comment: "")
            : NSLocalizedString("Couldn't undo", comment: "")
        resultFeedback = .dictationUndoUnavailable(reason: reason)
        onToast?(.dictationUndoUnavailable(reason: reason))
    }

    /// Precise, actionable text per outcome. A refusal that *retains* the record says so, and
    /// says what would let it succeed — previously every failure collapsed into the single
    /// unqualified title "Couldn't undo".
    static func undoFailureReason(
        for outcome: DictationUndoOutcome,
        invocation: DictationUndoInvocation
    ) -> String {
        switch outcome {
        case .undone:
            return "The last dictation was removed."
        case .nothingToUndo:
            return "No reversible dictation is available to undo."
        case .focusChanged:
            return invocation == .globalShortcut
                ? "That field isn't focused right now, so nothing was touched. Click back into it and press ⌃⌥⌘Z again — undo is still available."
                : "The saved field couldn't be confirmed, so nothing was touched. Undo is still available."
        case .contentChanged:
            return "That field's text changed after the dictation, so undo was withdrawn rather than risk deleting your own edits."
        case .cannotVerify:
            return "Accessibility couldn't confirm the field's contents, so nothing was touched. Undo is still available — try again in a moment."
        case .targetUnavailable:
            return "The field that received the dictation no longer exists, so it can't be undone."
        }
    }

    /// Feedback for the ⌃⌥⌘Z chord arriving while nothing reversible is armed. Deliberately
    /// does *not* claim an undo failed — nothing was attempted, and no Accessibility mutation
    /// happens on this path. Called from the main actor after the Quartz tap dispatches.
    public func reportUndoUnavailableForShortcut(now: Date = Date()) {
        // A real pending record can be armed between the tap's eligibility check and this
        // main-actor hop; don't contradict the visible button in that window.
        guard !dictationUndoManager.canUndoLastDictation else { return }
        // A second physical press landing while the first undo is still in flight loses the
        // eligibility claim and reaches here *after* that undo succeeded. Reporting "nothing
        // to undo" then would overwrite the confirmation the user just earned, making a
        // working undo look like it did nothing.
        if let lastUndoAttemptAt,
           now.timeIntervalSince(lastUndoAttemptAt) < undoUnavailableNoticeSuppressionWindow {
            return
        }
        statusText = NSLocalizedString("Nothing to undo", comment: "")
        let reason = "No recent reversible dictation to undo."
        resultFeedback = .dictationUndoUnavailable(reason: reason)
        onToast?(.dictationUndoUnavailable(reason: reason))
    }
}
