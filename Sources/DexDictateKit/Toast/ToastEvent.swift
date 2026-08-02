import Foundation

/// Events that trigger a brief toast/HUD notification.
///
/// Emitted by `TranscriptionEngine` after each dictation cycle and delivered
/// to observers via `TranscriptionEngine.onToast`. UI layers convert these
/// events into a `ToastState` that auto-dismisses after ~2.5 seconds.
public enum ToastEvent: Equatable, Sendable {
    /// A built-in voice command was recognized and executed (e.g. "Scratch That").
    case commandExecuted(name: String)

    /// A user-defined "Dex [keyword]" custom command was executed.
    case customCommandExecuted(keyword: String)

    /// Text was successfully pasted into the active application.
    case outputInserted

    /// Synthetic paste events were posted, but macOS did not confirm insertion.
    case outputPasteUnverified

    /// Delivery was blocked before paste events were posted.
    case outputBlocked(reason: String)

    /// Delivery failed before a paste request could be completed.
    case outputFailed(reason: String)

    /// Text was copied to clipboard instead of pasted (sensitive context or per-app override).
    case clipboardFallback(reason: String)

    /// Auto-paste is off — text was saved to history only, no insertion attempted.
    case outputSavedOnly

    /// The most recently inserted dictation was removed from the target app.
    case dictationUndone

    /// "Undo Last Dictation" was requested but could not be safely performed.
    case dictationUndoUnavailable(reason: String)

    // MARK: - Display

    public var label: String {
        switch self {
        case .commandExecuted(let name):
            return "Command: \(name)"
        case .customCommandExecuted(let keyword):
            return "Dex \(keyword)"
        case .outputInserted:
            return "Inserted"
        case .outputPasteUnverified:
            return "Paste requested"
        case .outputBlocked:
            return "Paste blocked"
        case .outputFailed:
            return "Delivery failed"
        case .clipboardFallback:
            return "Copied to clipboard"
        case .outputSavedOnly:
            return "Saved to history"
        case .dictationUndone:
            return "Dictation undone"
        case .dictationUndoUnavailable:
            return "Couldn't undo"
        }
    }

    public var symbolName: String {
        switch self {
        case .commandExecuted, .customCommandExecuted:
            return "bolt.fill"
        case .outputInserted:
            return "checkmark.circle.fill"
        case .outputPasteUnverified:
            return "questionmark.circle"
        case .outputBlocked, .outputFailed:
            return "exclamationmark.triangle.fill"
        case .clipboardFallback:
            return "doc.on.doc.fill"
        case .outputSavedOnly:
            return "tray.and.arrow.down.fill"
        case .dictationUndone:
            return "arrow.uturn.backward.circle.fill"
        case .dictationUndoUnavailable:
            return "exclamationmark.arrow.trianglehead.counterclockwise"
        }
    }
}
