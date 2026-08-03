import AppKit
import ApplicationServices
import Foundation

// The Accessibility insertion strategies, split out of `OutputCoordinator.swift` to keep both
// files readable. `extension` rather than `private extension` only because these members now
// live in a separate file within the same module.

extension OutputCoordinator {
    enum AccessibilityInsertionAttempt {
        /// Nothing was written: no strategy was available, or the setter itself refused. The
        /// field is untouched, so the caller may safely fall through to clipboard paste.
        case failed
        /// The setter reported success and the field came back **byte-identical** to what it
        /// was beforehand — the host accepted the write and did nothing with it. Measured
        /// against Brave, which advertises `kAXSelectedTextAttribute` as settable, returns
        /// `.success`, and leaves the composer unchanged. Because nothing landed, this is
        /// safe to fall through to clipboard paste; treating it as a mutation is precisely
        /// what suppressed the fallback and delivered no text at all.
        case noOp
        /// The field changed, but not into the value we expected. Something landed and we
        /// cannot say what, so a second delivery attempt could duplicate text. No paste.
        case mutatedButUnverified
        case confirmed(previousValue: String, replacementRange: NSRange, element: AXUIElement)
    }

    /// Attempts to insert text at the current cursor position via the Accessibility API.
    /// Preflights each attribute with `AXUIElementIsAttributeSettable` before attempting
    /// a set, and logs each failed strategy with the returned `AXError`.
    func insertViaAccessibility(_ text: String) -> AccessibilityInsertionAttempt {
        guard let element = axOperator.focusedElement() else {
            Safety.log("insertViaAccessibility() — no focused AX element", category: .output)
            return .failed
        }

        let snapshot = axOperator.editableTextSnapshot(element: element)
        // Settability is logged because it selects the strategy below, and because the first
        // round of this repair had to guess at it. Shapes and result codes only — no content.
        let settability = "valueSettable=\(axOperator.isSettable(kAXValueAttribute as CFString, element: element))"
            + " selectedTextSettable=\(axOperator.isSettable(kAXSelectedTextAttribute as CFString, element: element))"
        Safety.log("insertViaAccessibility() — target \(snapshot.diagnosticSummary) \(settability)", category: .output)

        guard let currentValue = snapshot.committedValue,
              let selectedRange = snapshot.logicalRange else {
            // Ambiguous or unreadable: refuse to touch a value we cannot vouch for and let the
            // caller fall through to clipboard paste, whose payload is only ever the
            // transcription. No AX setter runs on this path.
            Safety.log(
                "insertViaAccessibility() — editable state ambiguous or unreadable; falling back to clipboard paste",
                category: .output
            )
            return .failed
        }

        // Strategy order is a safety property, not a preference.
        //
        // Writing a *reconstructed whole field value* is only ever safe when the field is
        // provably empty, because that reconstruction is built from the raw `kAXValueAttribute`
        // — and an empty Chromium composer reports its placeholder there. Measured against
        // Brave: `AXPlaceholderValue` is not exposed at all and `AXNumberOfCharacters` equals
        // the placeholder's own length, so such a composer is bit-for-bit indistinguishable
        // from a field genuinely holding that many characters. No classifier can separate
        // them, so the previous "detect the placeholder" approach could not work in principle.
        //
        // The fix is to stop reconstructing. Everything below writes *only* the transcription:
        // a whole-value write when the field is confirmed empty (where the transcription IS
        // the whole value), and otherwise a selected-text write, which the host splices into
        // its own real content. A placeholder can no longer reach the setter by any route.
        if snapshot.emptiness == AccessibilityTextEmptiness.confirmedEmpty {
            if let attempt = attemptEmptyFieldValueInsertion(text, element: element) {
                return attempt
            }
        }
        if let attempt = attemptSelectedTextInsertion(
            text,
            currentValue: currentValue,
            selectedRange: selectedRange,
            element: element
        ) {
            return attempt
        }

        Safety.log("insertViaAccessibility() — no safe AX strategy available; falling back to clipboard paste", category: .output)
        return .failed
    }

    /// Whole-value write, used **only** for a field proved empty by `emptiness`. The value
    /// written is the transcription itself — nothing is reconstructed from `kAXValueAttribute`,
    /// so there is no raw string in which a placeholder could ride along.
    func attemptEmptyFieldValueInsertion(
        _ text: String,
        element: AXUIElement
    ) -> AccessibilityInsertionAttempt? {
        guard axOperator.isSettable(kAXValueAttribute as CFString, element: element) else {
            Safety.log("insertViaAccessibility() — empty-field write skipped: kAXValueAttribute not settable", category: .output)
            return nil
        }

        let preAttemptRawValue = axOperator.editableTextSnapshot(element: element).rawValue
        let result = axOperator.set(text as CFTypeRef, for: kAXValueAttribute as CFString, element: element)
        guard result == .success else {
            Safety.log("insertViaAccessibility() — empty-field write failed: AXError \(result.rawValue)", category: .output)
            return nil
        }

        let expectedCursor = accessibilityCharacterCount(text)
        guard didFieldChange(element: element, from: preAttemptRawValue) else {
            Safety.log("insertViaAccessibility() — empty-field write outcome=noOp (selection left intact)", category: .output)
            return .noOp
        }
        _ = axOperator.setCursor(location: expectedCursor, element: element)
        let verdict = mutationVerdict(
            element: element,
            expectedValue: text,
            expectedCursor: expectedCursor,
            preAttemptRawValue: preAttemptRawValue
        )
        Safety.log("insertViaAccessibility() — empty-field write \(verdict.diagnosticSummary)", category: .output)
        guard verdict.isConfirmed else { return verdict.unconfirmedOutcome }
        // The pre-insertion committed value of a confirmed-empty field is "", at {0, 0} —
        // undo therefore restores emptiness and the host renders its placeholder again.
        return .confirmed(previousValue: "", replacementRange: NSRange(location: 0, length: 0), element: element)
    }

    /// Writes **only** the transcription into the host's current selection and lets the host
    /// splice it into its own real content. This is what makes the delivery placeholder-proof
    /// without having to classify the field: whatever `kAXValueAttribute` claimed, it is never
    /// part of what gets written.
    ///
    /// `expectedValue` is still reconstructed, but purely to *verify* — never to write. When
    /// the host was in fact showing a placeholder, the reconstruction won't match the readback,
    /// so the insertion is left unconfirmed and undo is not armed; the field content is still
    /// correct because only the transcription was ever sent.
    func attemptSelectedTextInsertion(
        _ text: String,
        currentValue: String,
        selectedRange: NSRange,
        element: AXUIElement
    ) -> AccessibilityInsertionAttempt? {
        guard axOperator.isSettable(kAXSelectedTextAttribute as CFString, element: element),
              let expectedValue = accessibilityReplacingText(in: currentValue, range: selectedRange, with: text) else {
            Safety.log("insertViaAccessibility() — selected-text write skipped: attribute not settable or range unavailable/invalid", category: .output)
            return nil
        }

        let preAttemptRawValue = axOperator.editableTextSnapshot(element: element).rawValue
        let result = axOperator.set(text as CFTypeRef, for: kAXSelectedTextAttribute as CFString, element: element)
        guard result == .success else {
            Safety.log("insertViaAccessibility() — selected-text write failed: AXError \(result.rawValue)", category: .output)
            return nil
        }

        let expectedCursor = selectedRange.location + accessibilityCharacterCount(text)
        // The cursor is only moved once the write is known to have landed.
        //
        // Chromium accepts this write, returns `.success`, and changes nothing. Moving the
        // caret anyway *collapsed the user's selection*, so the clipboard fallback's Cmd-V
        // then inserted at a caret instead of replacing what they had selected — measured in
        // production as `outcome=noOp` immediately followed by `unexplainedChange` on every
        // selection paste. Leaving the selection untouched lets the fallback replace it
        // natively, which is both the correct edit and the shape verification can confirm.
        guard didFieldChange(element: element, from: preAttemptRawValue) else {
            Safety.log("insertViaAccessibility() — selected-text write outcome=noOp (selection left intact)", category: .output)
            return .noOp
        }
        _ = axOperator.setCursor(location: expectedCursor, element: element)
        let verdict = mutationVerdict(
            element: element,
            expectedValue: expectedValue,
            expectedCursor: expectedCursor,
            preAttemptRawValue: preAttemptRawValue
        )
        Safety.log("insertViaAccessibility() — selected-text write \(verdict.diagnosticSummary)", category: .output)
        guard verdict.isConfirmed else { return verdict.unconfirmedOutcome }
        return .confirmed(previousValue: currentValue, replacementRange: selectedRange, element: element)
    }

    /// Which half of the post-mutation readback agreed, recorded separately so a refusal says
    /// *why* rather than collapsing to one boolean.
    struct MutationVerdict {
        let valueMatched: Bool
        /// `nil` when the host exposes no selected range to compare against.
        let cursorMatched: Bool?
        /// The field came back byte-identical to its pre-attempt raw value. `nil` when the raw
        /// value could not be read on one side of the write, which is itself indeterminate.
        let unchanged: Bool?

        /// What an unconfirmed write means for the caller. The distinction is the whole point:
        /// an untouched field is safe to deliver to by another route, a partially changed one
        /// is not.
        var unconfirmedOutcome: AccessibilityInsertionAttempt {
            unchanged == true ? .noOp : .mutatedButUnverified
        }

        /// Confirmation rests on the **value** matching exactly — that is the assertion undo
        /// depends on, and `DictationUndoManager` re-verifies the full value again at undo
        /// time before touching anything.
        ///
        /// Cursor agreement is recorded but not required. Measured against Brave, every one of
        /// 11 consecutive real insertions wrote the expected value and then reported a
        /// different selected range, so requiring both made *zero* insertions confirmable and
        /// left undo permanently disabled. A host that declines to report a caret where we put
        /// one is not evidence that the text landed wrong.
        var isConfirmed: Bool { valueMatched }

        var diagnosticSummary: String {
            let outcome = isConfirmed ? "confirmed" : (unchanged == true ? "noOp" : "mutatedButUnverified")
            return "valueMatched=\(valueMatched)"
                + " cursorMatched=\(cursorMatched.map(String.init) ?? "unavailable")"
                + " unchanged=\(unchanged.map(String.init) ?? "unknown")"
                + " outcome=\(outcome)"
        }
    }

    /// Compares the *committed* readback, so a host re-rendering its placeholder after the
    /// field empties isn't mistaken for our text surviving. The value comparison stays exact:
    /// if the host hands back the transcription with placeholder text fused to it, that fused
    /// string is the committed value, it will not equal `expectedValue`, and the insertion is
    /// refused confirmation rather than recorded as reversible.
    func mutationVerdict(
        element: AXUIElement,
        expectedValue: String,
        expectedCursor: Int,
        preAttemptRawValue: String?
    ) -> MutationVerdict {
        let readback = axOperator.editableTextSnapshot(element: element)
        let reportedRange = axOperator.getSelectedRange(element: element)
        // Compared on the **raw** value, not the committed one: "did anything at all change in
        // this field" is a question about the bytes the host reports, and normalising them
        // first would hide a host that swapped a placeholder for identical-looking content.
        let unchanged: Bool?
        if let preAttemptRawValue, let now = readback.rawValue {
            unchanged = (now == preAttemptRawValue)
        } else {
            unchanged = nil
        }
        return MutationVerdict(
            valueMatched: readback.committedValue == expectedValue,
            cursorMatched: reportedRange.map { $0 == NSRange(location: expectedCursor, length: 0) },
            unchanged: unchanged
        )
    }

    /// Whether the setter actually altered the field. `false` means the host reported success
    /// and did nothing, so no follow-up mutation (including a cursor move) may be performed.
    func didFieldChange(element: AXUIElement, from preAttemptRawValue: String?) -> Bool {
        guard let preAttemptRawValue,
              let now = axOperator.editableTextSnapshot(element: element).rawValue else {
            // Unreadable on either side: treat as changed so the normal verdict path decides,
            // rather than silently claiming a no-op we cannot actually prove.
            return true
        }
        return now != preAttemptRawValue
    }

    /// Accessibility `CFRange`/`NSRange` offsets follow NSString UTF-16 coordinates.
    func accessibilityCharacterCount(_ text: String) -> Int {
        (text as NSString).length
    }
}
