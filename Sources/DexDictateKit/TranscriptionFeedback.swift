import Foundation

public enum TranscriptionFeedbackTone: Equatable {
    case neutral
    case success
    case warning
}

public enum TranscriptionFeedback: Equatable {
    case idle
    case noSpeechDetected
    case deletedPreviousHistory
    case discardedCurrentUtterance
    case savedToHistory(modified: Bool)
    case pastedToActiveApp(modified: Bool)

    public var title: String {
        switch self {
        case .idle:
            return ""
        case .noSpeechDetected:
            return "No speech detected"
        case .deletedPreviousHistory:
            return "Previous entry removed"
        case .discardedCurrentUtterance:
            return "Current utterance discarded"
        case .savedToHistory(let modified):
            return modified ? "Saved with changes" : "Saved to history"
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
        case .deletedPreviousHistory:
            return "The last history entry was removed because the utterance was only \"scratch that\"."
        case .discardedCurrentUtterance:
            return "The current spoken segment was discarded by the voice command."
        case .savedToHistory(let modified):
            return modified
                ? "The result was kept locally after vocabulary or filter changes."
                : "The result was kept locally without auto-paste."
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
        case .deletedPreviousHistory, .discardedCurrentUtterance:
            return "arrow.uturn.backward.circle"
        case .savedToHistory:
            return "tray.and.arrow.down"
        case .pastedToActiveApp:
            return "doc.on.clipboard"
        }
    }

    public var tone: TranscriptionFeedbackTone {
        switch self {
        case .idle:
            return .neutral
        case .noSpeechDetected, .deletedPreviousHistory, .discardedCurrentUtterance:
            return .warning
        case .savedToHistory, .pastedToActiveApp:
            return .success
        }
    }
}
