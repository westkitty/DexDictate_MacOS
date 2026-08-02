import Foundation

/// "Undo Last Dictation" glue for `TranscriptionEngine`, split into its own file so this
/// feature's code doesn't grow `TranscriptionEngine.swift`'s already-oversized type body.
/// Reads/writes `dictationUndoManager` and `pendingFocusSnapshot`, both declared internal
/// (not `private`) in the main file for exactly this reason.
extension TranscriptionEngine {
    /// Republishes `canUndoLastDictation` from the authoritative manager. Every mutation of
    /// the undo record goes through `armUndo`/`disarmUndo`/`undoLastDictation()`, all of
    /// which end here, so the published value cannot drift from the manager.
    func syncUndoAvailability() {
        let available = dictationUndoManager.canUndoLastDictation
        if canUndoLastDictation != available {
            canUndoLastDictation = available
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
    func disarmUndo() {
        dictationUndoManager.clear()
        syncUndoAvailability()
    }

    /// Supersedes both a pending delivery callback and any older undo record as soon as a
    /// later delivery cycle begins, including cycles that are later cancelled or fail.
    func beginDeliveryCycle() {
        pendingDeliveryID = nil
        disarmUndo()
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
    func applyDeliveryDecision(_ decision: OutputDeliveryDecision, modified: Bool) {
        recordDictationUndoIfNeeded(decision)

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

    private func recordDictationUndoIfNeeded(_ decision: OutputDeliveryDecision) {
        disarmUndo()
        guard decision.delivery == .pastedToActiveApp,
              let undoContext = decision.undoContext,
              undoContext.previousFieldValue != nil,
              undoContext.replacementRange != nil,
              undoContext.targetElement != nil,
              let pendingFocusSnapshot else { return }
        armUndo(
            DictationUndoRecord(
                focusSnapshot: pendingFocusSnapshot,
                context: undoContext,
                timestamp: Date()
            )
        )
    }

    /// Reverses the most recently pasted dictation directly in the target app — without
    /// touching its clipboard or its own undo stack. See `DictationUndoManager` for the
    /// verification strategies this goes through before it will actually delete anything.
    public func undoLastDictation() {
        // `DictationUndoManager` consumes the record one-shot, whatever the outcome, so the
        // published mirror must be refreshed on every branch below.
        defer { syncUndoAvailability() }
        switch dictationUndoManager.undoLastDictation() {
        case .undone:
            statusText = NSLocalizedString("Dictation undone", comment: "")
            resultFeedback = .dictationUndone
            onToast?(.dictationUndone)
        case .nothingToUndo:
            statusText = NSLocalizedString("Nothing to undo", comment: "")
            let reason = "No recent dictation to undo."
            resultFeedback = .dictationUndoUnavailable(reason: reason)
            onToast?(.dictationUndoUnavailable(reason: reason))
        case .focusChanged:
            statusText = NSLocalizedString("Couldn't undo", comment: "")
            let reason = "The focused field changed since that dictation was inserted."
            resultFeedback = .dictationUndoUnavailable(reason: reason)
            onToast?(.dictationUndoUnavailable(reason: reason))
        case .contentChanged:
            statusText = NSLocalizedString("Couldn't undo", comment: "")
            let reason = "That field's content changed since the dictation was inserted."
            resultFeedback = .dictationUndoUnavailable(reason: reason)
            onToast?(.dictationUndoUnavailable(reason: reason))
        case .cannotVerify:
            statusText = NSLocalizedString("Couldn't undo", comment: "")
            let reason = "Couldn't confirm the target field via Accessibility."
            resultFeedback = .dictationUndoUnavailable(reason: reason)
            onToast?(.dictationUndoUnavailable(reason: reason))
        }
    }

    /// Feedback for the ⌃⌥⌘Z chord arriving while nothing reversible is armed. Deliberately
    /// does *not* claim an undo failed — nothing was attempted, and no Accessibility mutation
    /// happens on this path. Called from the main actor after the Quartz tap dispatches.
    public func reportUndoUnavailableForShortcut() {
        // A real pending record can be armed between the tap's eligibility check and this
        // main-actor hop; don't contradict the visible button in that window.
        guard !dictationUndoManager.canUndoLastDictation else { return }
        statusText = NSLocalizedString("Nothing to undo", comment: "")
        let reason = "No recent reversible dictation to undo."
        resultFeedback = .dictationUndoUnavailable(reason: reason)
        onToast?(.dictationUndoUnavailable(reason: reason))
    }
}
