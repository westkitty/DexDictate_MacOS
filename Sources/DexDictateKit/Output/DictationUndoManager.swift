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
    /// Transient — the record is retained so the user can return and retry.
    case focusChanged
    /// The focused field's content no longer matches what this insertion produced (the user
    /// likely edited it since); refused to touch it blindly. Permanent — retrying could only
    /// ever destroy text the user wrote.
    case contentChanged
    /// Accessibility could not confirm anything about the target element; refused to guess.
    /// Transient — retained unless the element is proven destroyed.
    case cannotVerify
    /// The saved target element is definitively gone. Permanent.
    case targetUnavailable

    /// Whether this outcome permanently invalidates the saved record. Refusals that are only
    /// *temporarily* unverifiable must not destroy an otherwise valid undo — that is what made
    /// the control disappear for good after one harmless failed attempt.
    var consumesRecord: Bool {
        switch self {
        case .undone, .contentChanged, .targetUnavailable:
            return true
        case .nothingToUndo, .focusChanged, .cannotVerify:
            return false
        }
    }

    /// The permanent reason to publish once this outcome has consumed the record.
    var unavailableReason: DictationUndoUnavailableReason? {
        switch self {
        case .undone: return .consumedBySuccessfulUndo
        case .contentChanged: return .invalidatedByContentChange
        case .targetUnavailable: return .targetNoLongerExists
        case .nothingToUndo, .focusChanged, .cannotVerify: return nil
        }
    }
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
    /// The single authoritative description of undo state. `TranscriptionEngine` publishes
    /// exactly this, so the manager, the published value, and the UI cannot drift apart.
    var availability: DictationUndoAvailability { get }
    var eligibilitySnapshot: DictationUndoEligibilitySnapshot { get }
    func record(_ record: DictationUndoRecord)
    func clear(reason: DictationUndoUnavailableReason)
    @discardableResult
    func undoLastDictation(invocation: DictationUndoInvocation) -> DictationUndoOutcome
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

    /// Derived from `pendingRecord` plus the reason the last record went away, so this and
    /// `canUndoLastDictation` are two views of one state rather than two states.
    private(set) var availability: DictationUndoAvailability = .unavailable(.noDictationYet)

    func record(_ record: DictationUndoRecord) {
        pendingRecord = record
        eligibilitySnapshot.setEligible(true)
        availability = .available
    }

    func clear(reason: DictationUndoUnavailableReason) {
        eligibilitySnapshot.setEligible(false)
        pendingRecord = nil
        availability = .unavailable(reason)
    }

    /// Re-arms a record that a *transient* refusal could not verify. Every safety gate still
    /// runs on the next attempt, so retention can never turn into a blind mutation.
    private func retain() {
        eligibilitySnapshot.setEligible(true)
        availability = .available
    }

    @discardableResult
    func undoLastDictation(invocation: DictationUndoInvocation) -> DictationUndoOutcome {
        guard let record = pendingRecord else { return .nothingToUndo }
        // Claim the record for the duration of this attempt so a second event can't run the
        // same undo concurrently, then let the outcome decide whether it is truly consumed.
        eligibilitySnapshot.setEligible(false)
        pendingRecord = nil

        var outcome = attemptUndo(record, invocation: invocation)

        // A refusal we could not verify is only worth discarding when the system gives
        // definitive evidence the saved field is gone.
        if outcome == .cannotVerify,
           let expectedElement = record.context.targetElement?.element,
           !axOperator.isElementAlive(expectedElement) {
            outcome = .targetUnavailable
        }

        if outcome.consumesRecord {
            availability = .unavailable(outcome.unavailableReason ?? .consumedBySuccessfulUndo)
        } else {
            pendingRecord = record
            retain()
        }
        return outcome
    }

    /// The saved element is the only thing either invocation is ever allowed to mutate.
    /// Which element currently holds *global* focus is evidence, never a target.
    private func verifyTarget(
        _ record: DictationUndoRecord,
        invocation: DictationUndoInvocation
    ) -> DictationUndoOutcome? {
        guard let expectedElement = record.context.targetElement?.element else { return .cannotVerify }

        switch invocation {
        case .globalShortcut:
            // The user is still in the target app, so global focus must corroborate the
            // saved element — this is what stops a mistimed chord hitting a different field.
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
            guard let element = axOperator.focusedElement() else { return .cannotVerify }
            guard CFEqual(expectedElement, element) else { return .focusChanged }
            return nil

        case .popoverButton:
            // Clicking the menu-bar popover moves focus to DexDictate itself, so requiring
            // the saved field to still be globally focused would refuse every button press.
            // Instead: prove the saved element still exists, and rely on the exact value,
            // range, settability, and readback checks below. Never consult `focusedElement()`.
            guard axOperator.isElementAlive(expectedElement) else { return .targetUnavailable }
            return nil
        }
    }

    private func attemptUndo(
        _ record: DictationUndoRecord,
        invocation: DictationUndoInvocation
    ) -> DictationUndoOutcome {
        if let refusal = verifyTarget(record, invocation: invocation) { return refusal }
        guard let element = record.context.targetElement?.element else { return .cannotVerify }

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
