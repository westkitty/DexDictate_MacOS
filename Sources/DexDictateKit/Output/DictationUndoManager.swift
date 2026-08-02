import AppKit
import ApplicationServices
import Foundation
import os.lock

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

/// Thread-safe, single-claim view of whether the authoritative undo manager currently has
/// a pending record. The Quartz event-tap callback uses this Boolean reservation only; the
/// record itself remains owned and mutated by `DictationUndoManager` on the main actor.
final class DictationUndoEligibilitySnapshot: @unchecked Sendable {
    private var lock = os_unfair_lock()
    private var isEligible = false

    func setEligible(_ eligible: Bool) {
        os_unfair_lock_lock(&lock)
        isEligible = eligible
        os_unfair_lock_unlock(&lock)
    }

    func claimIfEligible() -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        guard isEligible else { return false }
        isEligible = false
        return true
    }
}

protocol DictationUndoPerforming: AnyObject {
    var canUndoLastDictation: Bool { get }
    var eligibilitySnapshot: DictationUndoEligibilitySnapshot { get }
    func record(_ record: DictationUndoRecord)
    func clear()
    @discardableResult
    func undoLastDictation() -> DictationUndoOutcome
}

/// Reverses the single most recent successful dictation insertion — without touching the
/// target app's clipboard or its own undo stack. Two strategies are allowed, both gated by
/// exact element, range, content, and mutation-readback verification:
///
/// 1. **Exact restore**: the field's current value still matches exactly what this insertion
///    produced — set the field back to its pre-insertion value and restore the cursor.
/// 2. **Verified trim**: only for an original zero-length insertion when the exact saved
///    range still contains the exact inserted text and the cursor is at its end.
final class DictationUndoManager: DictationUndoPerforming {
    static let shared = DictationUndoManager()

    private var pendingRecord: DictationUndoRecord?
    private let axOperator: AccessibilityElementOperating
    private let focusProvider: () -> FocusedElementSnapshot?
    let eligibilitySnapshot = DictationUndoEligibilitySnapshot()

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
        eligibilitySnapshot.setEligible(true)
    }

    func clear() {
        eligibilitySnapshot.setEligible(false)
        pendingRecord = nil
    }

    @discardableResult
    func undoLastDictation() -> DictationUndoOutcome {
        guard let record = pendingRecord else { return .nothingToUndo }
        // One-shot: consumed whether or not the attempt below actually succeeds, so a failed
        // undo can't be silently retried against now-stale state.
        eligibilitySnapshot.setEligible(false)
        pendingRecord = nil

        if let focusSnapshot = record.focusSnapshot {
            guard let currentFocus = focusProvider() else { return .cannotVerify }
            guard FocusedElementIdentityMatcher.isSameContext(
                focusSnapshot,
                currentFocus,
                targetBundleID: record.context.targetApplication?.bundleIdentifier
            ) else {
                return .focusChanged
            }
        }

        guard let expectedElement = record.context.targetElement?.element,
              let element = axOperator.focusedElement() else { return .cannotVerify }
        guard CFEqual(expectedElement, element) else { return .focusChanged }

        guard let currentValue = axOperator.getString(kAXValueAttribute as CFString, element: element),
              let previousValue = record.context.previousFieldValue,
              let replacementRange = record.context.replacementRange,
              isValidAccessibilityRange(replacementRange, in: previousValue),
              let expectedCurrentValue = accessibilityReplacingText(
                  in: previousValue,
                  range: replacementRange,
                  with: record.context.insertedText
              ) else { return .cannotVerify }

        let valueSettable = axOperator.isSettable(kAXValueAttribute as CFString, element: element)

        // Strategy 1: exact restore.
        if currentValue == expectedCurrentValue {
            guard valueSettable else { return .cannotVerify }
            return restoreAndVerify(
                previousValue,
                cursor: replacementRange.location,
                element: element
            )
        }

        // Strategy 2: trim only the exact original zero-length insertion range.
        guard replacementRange.length == 0,
              valueSettable,
              let selectedRange = axOperator.getSelectedRange(element: element),
              let trimmed = Self.exactInsertionRemoved(
                  record.context.insertedText,
                  from: currentValue,
                  insertionLocation: replacementRange.location,
                  selectedRange: selectedRange
              ) else { return .contentChanged }

        return restoreAndVerify(trimmed.newValue, cursor: trimmed.newCursor, element: element)
    }

    private func restoreAndVerify(
        _ value: String,
        cursor: Int,
        element: AXUIElement
    ) -> DictationUndoOutcome {
        guard axOperator.set(
            value as CFTypeRef,
            for: kAXValueAttribute as CFString,
            element: element
        ) == .success else { return .cannotVerify }
        _ = axOperator.setCursor(location: cursor, element: element)
        guard axOperator.getString(kAXValueAttribute as CFString, element: element) == value,
              axOperator.getSelectedRange(element: element) == NSRange(location: cursor, length: 0) else {
            return .cannotVerify
        }
        return .undone
    }

    private static func exactInsertionRemoved(
        _ insertedText: String,
        from currentValue: String,
        insertionLocation: Int,
        selectedRange: NSRange
    ) -> (newValue: String, newCursor: Int)? {
        guard !insertedText.isEmpty else { return nil }
        let currentNSString = currentValue as NSString
        let insertedLength = (insertedText as NSString).length
        let candidateRange = NSRange(location: insertionLocation, length: insertedLength)
        guard isValidAccessibilityRange(candidateRange, in: currentValue),
              selectedRange == NSRange(location: insertionLocation + insertedLength, length: 0) else {
            return nil
        }
        guard currentNSString.substring(with: candidateRange) == insertedText else { return nil }
        let newValue = currentNSString.replacingCharacters(in: candidateRange, with: "")
        return (newValue, candidateRange.location)
    }
}
