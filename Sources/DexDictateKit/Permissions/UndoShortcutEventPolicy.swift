import CoreGraphics
import Foundation
import os.lock

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

/// Thread-safe minimum-interval gate for the "nothing to undo" notice. The Quartz callback
/// can see the chord many times a second; without this, holding or hammering ⌃⌥⌘Z would
/// queue a toast per event.
final class UndoUnavailableNoticeRateLimiter: @unchecked Sendable {
    private var lock = os_unfair_lock()
    private var lastNoticeAt: Date?
    private let minimumInterval: TimeInterval

    init(minimumInterval: TimeInterval = 1.5) {
        self.minimumInterval = minimumInterval
    }

    /// Returns `true` at most once per `minimumInterval`, claiming the slot as it does.
    func shouldNotify(now: Date = Date()) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        if let lastNoticeAt, now.timeIntervalSince(lastNoticeAt) < minimumInterval {
            return false
        }
        lastNoticeAt = now
        return true
    }
}

/// Pure synchronous policy for the fixed Undo Last Dictation chord. Eligibility is claimed
/// before the request is enqueued so two closely spaced key-down events cannot both schedule
/// an undo while the main actor is still handling the first request.
enum UndoShortcutEventPolicy {
    static func handle(
        input: UndoShortcutEventInput,
        claimEligibility: () -> Bool,
        requestUndo: () -> Void,
        notifyUnavailable: () -> Void = {}
    ) -> UndoShortcutEventDisposition {
        guard input.type == .keyDown,
              input.keyCode == InputMonitor.undoDictationKeyCode,
              TriggerShortcutConflictChecker.modifiersMatch(
                  required: InputMonitor.undoDictationModifierMask,
                  held: input.modifiers
              ) else {
            return .notMatched
        }
        // Autorepeat never claims eligibility and never speaks: the first key-down already
        // decided this chord's outcome.
        guard !input.isAutorepeat else { return .passThrough }
        guard claimEligibility() else {
            // Still passes the chord through to the frontmost app, but no longer silently:
            // the caller schedules factual "nothing reversible to undo" feedback.
            notifyUnavailable()
            return .passThrough
        }
        requestUndo()
        return .consume
    }
}
