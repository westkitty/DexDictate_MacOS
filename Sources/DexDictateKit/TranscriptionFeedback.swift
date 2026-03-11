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
            return modified ? "Copied only for secure field" : "Copied only instead of pasting"
        case .pastedToActiveApp(let modified):
            return modified ? "Pasted with changes" : "Pasted into active app"
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
            return modified
                ? "The result was adjusted locally, copied instead of pasted, and kept out of the focused field. \(reason)"
                : "The result was copied instead of pasted because the focused field looks sensitive. \(reason)"
        case .pastedToActiveApp(let modified):
            return modified
                ? "The result was adjusted locally, then pasted into the active app."
                : "The result was pasted into the active app."
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
        case .pastedToActiveApp:
            return "doc.on.clipboard"
        }
    }

    public var tone: TranscriptionFeedbackTone {
        switch self {
        case .idle:
            return .neutral
        case .noSpeechDetected, .nothingToDelete, .deletedPreviousHistory, .discardedCurrentUtterance:
            return .warning
        case .restoredPreviousHistory, .savedToHistory, .copiedOnlySensitiveContext, .pastedToActiveApp:
            return .success
        }
    }
}
