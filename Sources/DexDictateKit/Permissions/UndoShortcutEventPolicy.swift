import CoreGraphics

enum UndoShortcutEventDisposition: Equatable {
    case notMatched
    case passThrough
    case consume
}

struct UndoShortcutEventInput {
    let type: CGEventType
    let keyCode: Int64
    let modifiers: UInt64
    let isAutorepeat: Bool
}

/// Pure synchronous policy for the fixed Undo Last Dictation chord. Eligibility is claimed
/// before the request is enqueued so two closely spaced key-down events cannot both schedule
/// an undo while the main actor is still handling the first request.
enum UndoShortcutEventPolicy {
    static func handle(
        input: UndoShortcutEventInput,
        claimEligibility: () -> Bool,
        requestUndo: () -> Void
    ) -> UndoShortcutEventDisposition {
        guard input.type == .keyDown,
              input.keyCode == InputMonitor.undoDictationKeyCode,
              TriggerShortcutConflictChecker.modifiersMatch(
                  required: InputMonitor.undoDictationModifierMask,
                  held: input.modifiers
              ) else {
            return .notMatched
        }
        guard !input.isAutorepeat, claimEligibility() else { return .passThrough }
        requestUndo()
        return .consume
    }
}
