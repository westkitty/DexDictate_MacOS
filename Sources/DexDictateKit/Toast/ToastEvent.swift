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

    /// Text was copied to clipboard instead of pasted (sensitive context or per-app override).
    case clipboardFallback(reason: String)

    /// Auto-paste is off — text was saved to history only, no insertion attempted.
    case outputSavedOnly

    // MARK: - Display

    public var label: String {
        switch self {
        case .commandExecuted(let name):
            return "Command: \(name)"
        case .customCommandExecuted(let keyword):
            return "Dex \(keyword)"
        case .outputInserted:
            return "Inserted"
        case .clipboardFallback:
            return "Copied to clipboard"
        case .outputSavedOnly:
            return "Saved to history"
        }
    }

    public var symbolName: String {
        switch self {
        case .commandExecuted, .customCommandExecuted:
            return "bolt.fill"
        case .outputInserted:
            return "checkmark.circle.fill"
        case .clipboardFallback:
            return "doc.on.doc.fill"
        case .outputSavedOnly:
            return "tray.and.arrow.down.fill"
        }
    }
}
