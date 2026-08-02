import Foundation

/// "Undo Last Dictation" glue for `TranscriptionEngine`, split into its own file so this
/// feature's code doesn't grow `TranscriptionEngine.swift`'s already-oversized type body.
/// Reads/writes `dictationUndoManager` and `pendingFocusSnapshot`, both declared internal
/// (not `private`) in the main file for exactly this reason.
extension TranscriptionEngine {
    /// True when a dictation was pasted into a target app and hasn't been undone (or
    /// superseded by a newer dictation) yet. Drives the "Undo Last Dictation" button/hotkey.
    public var canUndoLastDictation: Bool { dictationUndoManager.canUndoLastDictation }

    /// Called from `finalizeTranscription` right after a `.pastedToActiveApp` delivery.
    func recordDictationUndoIfNeeded(_ undoContext: DictationUndoContext?) {
        guard let undoContext else { return }
        dictationUndoManager.record(
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
}
