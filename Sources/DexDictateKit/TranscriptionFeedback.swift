import Foundation

public enum TranscriptionFeedbackTone: Equatable {
    case neutral
    case success
    case warning
}

public enum TranscriptionFeedback: Equatable {
    case idle
    case noSpeechDetected
    case nothingToDelete
    case deletedPreviousHistory
    case restoredPreviousHistory
    case discardedCurrentUtterance
    case savedToHistory(modified: Bool)
    case copiedOnlySensitiveContext(modified: Bool, reason: String)
    case pastedToActiveApp(modified: Bool)
    case pasteRequestedUnverified(modified: Bool)
    case deliveryBlocked(modified: Bool, reason: String)
    case deliveryFailed(modified: Bool, reason: String)
    case dictationUndone
    case dictationUndoUnavailable(reason: String)

    public var title: String {
        switch self {
        case .idle:
            return ""
        case .noSpeechDetected:
            return "No speech detected"
        case .nothingToDelete:
            return "Nothing to remove"
        case .deletedPreviousHistory:
            return "Previous entry removed"
        case .restoredPreviousHistory:
            return "Previous entry restored"
        case .discardedCurrentUtterance:
            return "Current utterance discarded"
        case .savedToHistory(let modified):
            return modified ? "Saved with changes" : "Saved to history"
        case .copiedOnlySensitiveContext(let modified, _):
            // Reached for any copy-without-paste outcome, not only secure fields — the
            // specific reason travels alongside and is rendered in the detail text.
            return modified ? "Copied with changes" : "Copied"
        case .pastedToActiveApp(let modified):
            // A confirmed Accessibility write, which is an insertion — no paste was involved.
            return modified ? "Inserted with changes" : "Inserted"
        case .pasteRequestedUnverified(let modified):
            return modified ? "Paste requested with changes" : "Paste requested"
        case .deliveryBlocked:
            return "Paste blocked"
        case .deliveryFailed:
            return "Delivery failed"
        case .dictationUndone:
            return "Dictation undone"
        case .dictationUndoUnavailable:
            return "Couldn't undo"
        }
    }

    public var detail: String {
        switch self {
        case .idle:
            return ""
        case .noSpeechDetected:
            return "DexDictate finished listening, but Whisper returned no usable text."
        case .nothingToDelete:
            return "The destructive voice command was heard, but there was no history entry available to remove."
        case .deletedPreviousHistory:
            return "The last history entry was removed because the utterance was only \"scratch that\"."
        case .restoredPreviousHistory:
            return "The most recently removed history entry was restored."
        case .discardedCurrentUtterance:
            return "The current spoken segment was discarded by the voice command."
        case .savedToHistory(let modified):
            return modified
                ? "The result was kept locally after vocabulary or filter changes."
                : "The result was kept locally without auto-paste."
        case .copiedOnlySensitiveContext(let modified, let reason):
            // Must not assert a sensitive field: this also covers auto-paste being off and an
            // insertion that could not be verified. The reason states which it actually was.
            return modified
                ? "The result was adjusted locally, then copied instead of pasted — \(reason)."
                : "The result was copied instead of pasted — \(reason)."
        case .pastedToActiveApp(let modified):
            return modified
                ? "The result was adjusted locally, then inserted into the active app."
                : "The result was pasted into the active app."
        case .pasteRequestedUnverified(let modified):
            return modified
                ? "The adjusted result was sent to macOS for pasting, but insertion could not be confirmed."
                : "The result was sent to macOS for pasting, but insertion could not be confirmed."
        case .deliveryBlocked(_, let reason):
            return reason
        case .deliveryFailed(_, let reason):
            return reason
        case .dictationUndone:
            return "The most recently inserted dictation was removed from the target app, without touching its clipboard or undo history."
        case .dictationUndoUnavailable(let reason):
            return reason
        }
    }

    public var symbolName: String {
        switch self {
        case .idle:
            return "circle"
        case .noSpeechDetected:
            return "waveform.badge.xmark"
        case .nothingToDelete:
            return "exclamationmark.arrow.trianglehead.counterclockwise"
        case .deletedPreviousHistory, .discardedCurrentUtterance:
            return "arrow.uturn.backward.circle"
        case .restoredPreviousHistory:
            return "arrow.uturn.backward.circle.fill"
        case .savedToHistory:
            return "tray.and.arrow.down"
        case .copiedOnlySensitiveContext:
            return "doc.on.doc"
        case .pastedToActiveApp, .pasteRequestedUnverified:
            return "doc.on.clipboard"
        case .deliveryBlocked, .deliveryFailed:
            return "exclamationmark.triangle"
        case .dictationUndone:
            return "arrow.uturn.backward.circle.fill"
        case .dictationUndoUnavailable:
            return "exclamationmark.arrow.trianglehead.counterclockwise"
        }
    }

    public var tone: TranscriptionFeedbackTone {
        switch self {
        case .idle:
            return .neutral
        case .noSpeechDetected, .nothingToDelete, .deletedPreviousHistory, .discardedCurrentUtterance,
             .deliveryBlocked, .deliveryFailed, .dictationUndoUnavailable:
            return .warning
        case .restoredPreviousHistory, .savedToHistory, .copiedOnlySensitiveContext,
             .pastedToActiveApp, .dictationUndone:
            return .success
        case .pasteRequestedUnverified:
            return .neutral
        }
    }
}
