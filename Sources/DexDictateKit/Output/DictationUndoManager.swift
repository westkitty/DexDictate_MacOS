import AppKit
import ApplicationServices
import Foundation

/// A single reversible dictation insertion, kept only in memory for as long as it takes the
/// user to potentially trigger "Undo Last Dictation" — never persisted to disk, and replaced
/// (not stacked) by the next successful insertion.
struct DictationUndoRecord: Equatable {
    /// AX snapshot of the focused field captured at trigger-down, before this insertion
    /// happened — the "previous cursor context" used to confirm the same field is still
    /// focused before attempting to reverse it. `nil` when Accessibility was unavailable at
    /// trigger time.
    let focusSnapshot: FocusedElementSnapshot?
    let context: DictationUndoContext
    let timestamp: Date
}

enum DictationUndoOutcome: Equatable {
    /// No dictation has been inserted since the last undo (or ever).
    case nothingToUndo
    /// The insertion was reversed.
    case undone
    /// Focus moved to a different app/field since the insertion; refused to touch it blindly.
    case focusChanged
    /// The focused field's content no longer matches what this insertion produced (the user
    /// likely edited it since); refused to touch it blindly.
    case contentChanged
    /// Accessibility could not confirm anything about the current focused element; refused
    /// to guess.
    case cannotVerify
}

protocol DictationUndoPerforming: AnyObject {
    var canUndoLastDictation: Bool { get }
    func record(_ record: DictationUndoRecord)
    @discardableResult
    func undoLastDictation() -> DictationUndoOutcome
}

/// Reverses the single most recent successful dictation insertion — without touching the
/// target app's clipboard or its own undo stack. Three strategies, tried in order of
/// precision, each gated by a verification step so a mismatch always aborts instead of
/// guessing:
///
/// 1. **Exact restore**: the field's current value still matches exactly what this insertion
///    produced — set the field back to its pre-insertion value and restore the cursor.
/// 2. **Verified trim**: the current value's tail still matches the inserted text ending at
///    the live cursor — remove just that tail (via AX when settable, otherwise Backspace,
///    now with confidence instead of a guess).
/// 3. **Unverified Backspace fallback**: only when Accessibility can confirm the same field
///    is still focused but cannot read its text value at all (common for custom-drawn text
///    views) — send one synthetic Backspace per character actually inserted. This never
///    touches the pasteboard or the target app's own undo history.
final class DictationUndoManager: DictationUndoPerforming {
    static let shared = DictationUndoManager()

    private var pendingRecord: DictationUndoRecord?
    private let axOperator: AccessibilityElementOperating
    private let focusProvider: () -> FocusedElementSnapshot?

    /// Testable hook for the Backspace fallback. Overridden in unit tests; production default
    /// posts synthetic Backspace keydown/keyup pairs — the same delivery mechanism
    /// `ClipboardManager` uses for its synthetic paste, but never touching `NSPasteboard` or
    /// the target app's Edit menu undo stack.
    static var backspaceSimulator: (_ count: Int, _ targetProcessIdentifier: pid_t?) -> Void = { count, targetProcessIdentifier in
        guard count > 0 else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let deleteKeyCode: CGKeyCode = 0x33 // kVK_Delete — the Mac keyboard's Backspace key.
        for _ in 0..<count {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: deleteKeyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: deleteKeyCode, keyDown: false)
            if let targetProcessIdentifier, targetProcessIdentifier > 0 {
                keyDown?.postToPid(targetProcessIdentifier)
                keyUp?.postToPid(targetProcessIdentifier)
            } else {
                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)
            }
        }
    }

    init(
        axOperator: AccessibilityElementOperating = SystemAccessibilityElementOperator(),
        focusProvider: @escaping () -> FocusedElementSnapshot? = FocusedElementSnapshot.captureFromSystem
    ) {
        self.axOperator = axOperator
        self.focusProvider = focusProvider
    }

    var canUndoLastDictation: Bool { pendingRecord != nil }

    func record(_ record: DictationUndoRecord) {
        pendingRecord = record
    }

    @discardableResult
    func undoLastDictation() -> DictationUndoOutcome {
        guard let record = pendingRecord else { return .nothingToUndo }
        // One-shot: consumed whether or not the attempt below actually succeeds, so a failed
        // undo can't be silently retried against now-stale state.
        pendingRecord = nil

        let currentFocus = focusProvider()
        if let focusSnapshot = record.focusSnapshot,
           !FocusedElementIdentityMatcher.isSameContext(
               focusSnapshot, currentFocus, targetBundleID: record.context.targetApplication?.bundleIdentifier
           ) {
            return .focusChanged
        }

        guard let element = axOperator.focusedElement() else {
            return .cannotVerify
        }

        guard let currentValue = axOperator.getString(kAXValueAttribute as CFString, element: element) else {
            // Focused element confirmed, but its text can't be read at all — the same
            // ambiguous case `ClipboardManager`'s editable-field heuristic already treats as
            // "probably a real text field" (custom-drawn views, some Electron apps). This is
            // the one strategy that can't verify before acting.
            Self.backspaceSimulator(record.context.insertedText.count, record.context.targetApplication?.processIdentifier)
            return .undone
        }

        let valueSettable = axOperator.isSettable(kAXValueAttribute as CFString, element: element)

        // Strategy 1: exact restore.
        if valueSettable,
           let previousValue = record.context.previousFieldValue,
           let replacementRange = record.context.replacementRange {
            let expectedCurrentValue = accessibilityReplacingText(
                in: previousValue, range: replacementRange, with: record.context.insertedText
            )
            if currentValue == expectedCurrentValue {
                let result = axOperator.set(previousValue as CFTypeRef, for: kAXValueAttribute as CFString, element: element)
                if result == .success {
                    axOperator.setCursor(location: replacementRange.location, element: element)
                    return .undone
                }
            }
        }

        // Strategy 2: verified trim — the inserted text still sits immediately before the
        // live cursor, with nothing else typed after it.
        if let selectedRange = axOperator.getSelectedRange(element: element),
           let trimmed = Self.trailingInsertionRemoved(
               record.context.insertedText, from: currentValue, endingAt: selectedRange.location
           ) {
            if valueSettable {
                let result = axOperator.set(trimmed.newValue as CFTypeRef, for: kAXValueAttribute as CFString, element: element)
                if result == .success {
                    axOperator.setCursor(location: trimmed.newCursor, element: element)
                    return .undone
                }
            } else {
                // Verified the exact tail matches, but this field doesn't accept a direct
                // value set — fall back to Backspace now with confidence instead of guessing.
                Self.backspaceSimulator(record.context.insertedText.count, record.context.targetApplication?.processIdentifier)
                return .undone
            }
        }

        return .contentChanged
    }

    /// Removes `insertedText` from the end of `currentValue` iff it exactly precedes
    /// `cursorLocation` — i.e. nothing else was typed after the dictation landed. Returns
    /// `nil` (no match, do nothing) rather than guessing when the tail doesn't line up.
    private static func trailingInsertionRemoved(
        _ insertedText: String, from currentValue: String, endingAt cursorLocation: Int
    ) -> (newValue: String, newCursor: Int)? {
        guard !insertedText.isEmpty else { return nil }
        let currentNSString = currentValue as NSString
        let insertedLength = (insertedText as NSString).length
        guard cursorLocation >= insertedLength, cursorLocation <= currentNSString.length else { return nil }
        let candidateRange = NSRange(location: cursorLocation - insertedLength, length: insertedLength)
        guard currentNSString.substring(with: candidateRange) == insertedText else { return nil }
        let newValue = currentNSString.replacingCharacters(in: candidateRange, with: "")
        return (newValue, candidateRange.location)
    }
}
