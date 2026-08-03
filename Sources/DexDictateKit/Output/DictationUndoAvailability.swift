import Foundation

/// Where an undo request came from. The two sources have genuinely different focus
/// expectations, so the verification strategy differs — see `DictationUndoManager`.
public enum DictationUndoInvocation: Equatable, Sendable {
    /// The fixed ⌃⌥⌘Z chord. The user is still in the target app, so the saved element must
    /// also be the globally focused one.
    case globalShortcut
    /// The popover control. Opening the menu-bar popover moves focus to DexDictate itself,
    /// so "is the saved field still globally focused" cannot be a precondition — the saved
    /// `AXUIElement` is verified and mutated directly instead.
    case popoverButton
}

/// Why undo is not currently offered. Surfaced verbatim in the disabled control's help and
/// accessibility text, so the user is never left guessing why nothing happened.
public enum DictationUndoUnavailableReason: Equatable, Sendable {
    /// Nothing has been dictated yet this session.
    case noDictationYet
    /// The last dictation was not delivered by a verified Accessibility insertion (clipboard
    /// paste, copied-only, saved-only, blocked, or failed), so there is nothing exact to reverse.
    case deliveryNotReversible(String)
    case consumedBySuccessfulUndo
    /// The field's contents changed since the insertion — reversing it could now destroy
    /// text the user wrote.
    case invalidatedByContentChange
    /// The saved target field no longer exists.
    case targetNoLongerExists
    case supersededByNewerDictation
    case engineStopped

    /// A short form that fits on the always-visible status line under the undo control in a
    /// 320pt popover. `message` stays the full explanation for help text and VoiceOver; this
    /// exists so the reason can be *read on screen* rather than only discovered by hovering.
    public var shortMessage: String {
        switch self {
        case .noDictationYet:
            return "nothing has been dictated yet."
        case .deliveryNotReversible:
            return "this result used an unverified paste."
        case .consumedBySuccessfulUndo:
            return "the last dictation was already undone."
        case .invalidatedByContentChange:
            return "that field changed after the dictation."
        case .targetNoLongerExists:
            return "the target field no longer exists."
        case .supersededByNewerDictation:
            return "a newer dictation replaced it."
        case .engineStopped:
            return "dictation was stopped."
        }
    }

    public var message: String {
        switch self {
        case .noDictationYet:
            return "No dictation has been inserted yet, so there is nothing to undo."
        case .deliveryNotReversible(let detail):
            return "The last result can't be undone: \(detail)"
        case .consumedBySuccessfulUndo:
            return "The last dictation has already been undone."
        case .invalidatedByContentChange:
            return "That field's text changed after the dictation, so undo was withdrawn rather than risk deleting your own edits."
        case .targetNoLongerExists:
            return "The field that received the last dictation no longer exists."
        case .supersededByNewerDictation:
            return "A newer dictation replaced the one that could be undone."
        case .engineStopped:
            return "Dictation was stopped, which discarded the pending undo."
        }
    }
}

/// The single published description of undo state. `TranscriptionEngine` republishes exactly
/// this value from `DictationUndoManager`, and the UI renders exactly this value — so the
/// control's enabled state and its explanation can never disagree with the authoritative record.
public struct DictationUndoAvailability: Equatable, Sendable {
    public let canUndo: Bool
    /// Always `nil` when `canUndo` is true.
    public let unavailableReason: DictationUndoUnavailableReason?

    public static let available = DictationUndoAvailability(canUndo: true, unavailableReason: nil)

    public static func unavailable(_ reason: DictationUndoUnavailableReason) -> DictationUndoAvailability {
        DictationUndoAvailability(canUndo: false, unavailableReason: reason)
    }

    private init(canUndo: Bool, unavailableReason: DictationUndoUnavailableReason?) {
        self.canUndo = canUndo
        self.unavailableReason = unavailableReason
    }
}
