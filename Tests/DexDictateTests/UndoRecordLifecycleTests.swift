import ApplicationServices
import XCTest
@testable import DexDictateKit

/// Covers the runtime defect: a harmless failed verification consumed the record, so the
/// control disappeared permanently — and the reason was never stated. These tests pin the
/// retention policy, the invocation-specific targeting rules, and the invariant that the
/// manager, the published availability, and the event-tap eligibility can never disagree.
@MainActor
final class UndoRecordLifecycleTests: XCTestCase {
    private let savedElement = AXUIElementCreateSystemWide()

    // MARK: - Retention policy

    func testTransientFocusChangeRetainsTheRecordAndRestoresEligibility() {
        // A different element holds focus: the shortcut must refuse, but the record survives.
        let other = AXUIElementCreateApplication(1)
        let manager = makeManager(focusedElement: other, currentValue: "hello world")
        manager.record(makeRecord())

        let outcome = manager.undoLastDictation(invocation: .globalShortcut)

        XCTAssertEqual(outcome, .focusChanged)
        XCTAssertTrue(manager.canUndoLastDictation, "A temporary focus change must not destroy undo")
        XCTAssertTrue(manager.availability.canUndo)
        XCTAssertTrue(manager.eligibilitySnapshot.claimIfEligible(), "Shortcut eligibility must be restored")
    }

    func testTransientVerificationFailureRetainsTheRecord() {
        // Value unreadable, but the element is still alive (fake defaults to alive).
        let manager = makeManager(focusedElement: savedElement, currentValue: nil)
        manager.record(makeRecord())

        let outcome = manager.undoLastDictation(invocation: .globalShortcut)

        XCTAssertEqual(outcome, .cannotVerify)
        XCTAssertTrue(manager.canUndoLastDictation)
        XCTAssertTrue(manager.availability.canUndo)
    }

    func testRetainedRecordCanSucceedOnRetry() {
        let fake = UndoFakeOperator(focusedElement: savedElement, currentValue: nil)
        let manager = DictationUndoManager(axOperator: fake, focusProvider: { self.snapshot() })
        manager.record(makeRecord())

        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .cannotVerify)
        XCTAssertTrue(manager.canUndoLastDictation)

        // The field becomes readable again — the retained record now reverses cleanly.
        fake.currentValue = "hello world"
        fake.selectedRange = NSRange(location: 11, length: 0)

        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .undone)
        XCTAssertEqual(fake.setValues.last, "hello")
        XCTAssertFalse(manager.canUndoLastDictation, "A successful undo consumes the record")
        XCTAssertEqual(manager.availability.unavailableReason, .consumedBySuccessfulUndo)
    }

    func testGenuineContentChangeDestroysTheRecord() {
        // Neither exact restore nor exact trim matches: the user edited the field.
        let manager = makeManager(
            focusedElement: savedElement,
            currentValue: "hello world and my own typing",
            selectedRange: NSRange(location: 29, length: 0)
        )
        manager.record(makeRecord())

        let outcome = manager.undoLastDictation(invocation: .globalShortcut)

        XCTAssertEqual(outcome, .contentChanged)
        XCTAssertFalse(manager.canUndoLastDictation, "Editing the field must permanently invalidate undo")
        XCTAssertEqual(manager.availability.unavailableReason, .invalidatedByContentChange)
        XCTAssertFalse(manager.eligibilitySnapshot.claimIfEligible())
    }

    func testDestroyedTargetElementDestroysTheRecord() {
        let fake = UndoFakeOperator(focusedElement: savedElement, currentValue: nil)
        fake.elementIsAlive = false
        let manager = DictationUndoManager(axOperator: fake, focusProvider: { self.snapshot() })
        manager.record(makeRecord())

        let outcome = manager.undoLastDictation(invocation: .globalShortcut)

        XCTAssertEqual(outcome, .targetUnavailable)
        XCTAssertFalse(manager.canUndoLastDictation)
        XCTAssertEqual(manager.availability.unavailableReason, .targetNoLongerExists)
    }

    func testSuccessfulUndoDestroysTheRecord() {
        let manager = makeManager(
            focusedElement: savedElement,
            currentValue: "hello world",
            selectedRange: NSRange(location: 11, length: 0)
        )
        manager.record(makeRecord())

        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .undone)
        XCTAssertFalse(manager.canUndoLastDictation)
        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .nothingToUndo)
    }

    // MARK: - Invocation-specific targeting

    /// The popover steals focus, so requiring the saved field to still be globally focused
    /// would refuse every button press. The button verifies the saved element directly.
    func testButtonInvocationSucceedsWhileDexDictateHoldsFocus() {
        let dexDictateElement = AXUIElementCreateApplication(99)
        let fake = UndoFakeOperator(focusedElement: dexDictateElement, currentValue: "hello world")
        fake.selectedRange = NSRange(location: 11, length: 0)
        // Focus now reports a different app entirely — as it does when the popover is open.
        let manager = DictationUndoManager(
            axOperator: fake,
            focusProvider: {
                FocusedElementSnapshot(
                    role: "AXGroup",
                    processIdentifier: 99,
                    bundleIdentifier: "com.westkitty.dexdictate.macos"
                )
            }
        )
        manager.record(makeRecord())

        let outcome = manager.undoLastDictation(invocation: .popoverButton)

        XCTAssertEqual(outcome, .undone)
        XCTAssertEqual(fake.setValues.last, "hello")
        XCTAssertEqual(
            fake.mutatedElements.count, 1,
            "Exactly one element may be mutated"
        )
        XCTAssertTrue(
            CFEqual(fake.mutatedElements[0], savedElement),
            "The button must mutate the saved element, never the currently focused one"
        )
        XCTAssertEqual(fake.focusedElementCallCount, 0, "The button path must never consult global focus")
    }

    /// Same focus situation, but the saved field's contents no longer match: the button must
    /// still refuse. Losing the focus precondition must not lose the content precondition.
    func testButtonInvocationStillRefusesWhenSavedFieldContentChanged() {
        let fake = UndoFakeOperator(focusedElement: savedElement, currentValue: "totally different text")
        let manager = DictationUndoManager(axOperator: fake, focusProvider: { nil })
        manager.record(makeRecord())

        let outcome = manager.undoLastDictation(invocation: .popoverButton)

        XCTAssertEqual(outcome, .contentChanged)
        XCTAssertTrue(fake.setValues.isEmpty, "Nothing may be written when content does not match")
    }

    func testButtonInvocationRefusesWhenSavedFieldIsNotSettable() {
        let fake = UndoFakeOperator(focusedElement: savedElement, currentValue: "hello world")
        fake.settableAttributes = []
        let manager = DictationUndoManager(axOperator: fake, focusProvider: { nil })
        manager.record(makeRecord())

        let outcome = manager.undoLastDictation(invocation: .popoverButton)

        XCTAssertEqual(outcome, .cannotVerify)
        XCTAssertTrue(fake.setValues.isEmpty)
    }

    /// The shortcut keeps the strict rule: the user is still in the app, so a different
    /// focused element means refuse.
    func testShortcutInvocationRefusesADifferentTarget() {
        let other = AXUIElementCreateApplication(7)
        let fake = UndoFakeOperator(focusedElement: other, currentValue: "hello world")
        let manager = DictationUndoManager(axOperator: fake, focusProvider: { self.snapshot() })
        manager.record(makeRecord())

        let outcome = manager.undoLastDictation(invocation: .globalShortcut)

        XCTAssertEqual(outcome, .focusChanged)
        XCTAssertTrue(fake.setValues.isEmpty, "A different field must never be mutated")
    }

    func testReadbackMismatchIsNotReportedAsUndone() {
        let fake = UndoFakeOperator(focusedElement: savedElement, currentValue: "hello world")
        fake.selectedRange = NSRange(location: 11, length: 0)
        fake.contradictReadback = true
        let manager = DictationUndoManager(axOperator: fake, focusProvider: { nil })
        manager.record(makeRecord())

        let outcome = manager.undoLastDictation(invocation: .popoverButton)

        XCTAssertNotEqual(outcome, .undone)
        XCTAssertEqual(outcome, .cannotVerify)
    }

    // MARK: - Helpers

    private func makeManager(
        focusedElement: AXUIElement,
        currentValue: String?,
        selectedRange: NSRange = NSRange(location: 11, length: 0)
    ) -> DictationUndoManager {
        let fake = UndoFakeOperator(focusedElement: focusedElement, currentValue: currentValue)
        fake.selectedRange = selectedRange
        return DictationUndoManager(axOperator: fake, focusProvider: { self.snapshot() })
    }

    private func makeRecord() -> DictationUndoRecord {
        DictationUndoRecord(
            focusSnapshot: snapshot(),
            context: DictationUndoContext(
                insertedText: " world",
                previousFieldValue: "hello",
                replacementRange: NSRange(location: 5, length: 0),
                targetApplication: OutputTargetApplication(
                    bundleIdentifier: "com.example.editor",
                    processIdentifier: 4242
                ),
                targetElement: savedElement
            ),
            timestamp: Date(timeIntervalSince1970: 1_000)
        )
    }

    private func snapshot() -> FocusedElementSnapshot {
        FocusedElementSnapshot(
            role: "AXTextField",
            processIdentifier: 4242,
            bundleIdentifier: "com.example.editor"
        )
    }
}

/// Engine-level half of the lifecycle contract: the manager record, the published
/// availability, and the event-tap eligibility snapshot must never disagree.
@MainActor
final class UndoStateConsistencyTests: XCTestCase {
    private let savedElement = AXUIElementCreateSystemWide()

    /// Manager record, published availability, and event-tap eligibility must agree after
    /// every transition — they were three independent truth sources before this repair.
    func testManagerPublishedStateAndEligibilityAgreeAfterEveryTransition() {
        let engine = TranscriptionEngine()

        func assertConsistent(_ label: String) {
            let manager = engine.dictationUndoManager
            XCTAssertEqual(
                engine.undoAvailability, manager.availability,
                "Published availability drifted from the manager after \(label)"
            )
            XCTAssertEqual(
                engine.canUndoLastDictation, manager.canUndoLastDictation,
                "Published flag drifted from the manager record after \(label)"
            )
            // Peek at eligibility without permanently consuming it.
            let eligible = manager.eligibilitySnapshot.claimIfEligible()
            if eligible { manager.eligibilitySnapshot.setEligible(true) }
            XCTAssertEqual(
                eligible, manager.canUndoLastDictation,
                "Event-tap eligibility drifted from the manager record after \(label)"
            )
        }

        assertConsistent("initial state")

        engine.pendingFocusSnapshot = snapshot()
        engine.applyDeliveryDecision(confirmedDecision(), modified: false)
        assertConsistent("confirmed reversible delivery")

        engine.applyDeliveryDecision(
            OutputDeliveryDecision(delivery: .requestedButUnverified),
            modified: false
        )
        assertConsistent("non-reversible delivery")

        engine.pendingFocusSnapshot = snapshot()
        engine.applyDeliveryDecision(confirmedDecision(), modified: false)
        engine.beginDeliveryCycle()
        assertConsistent("new delivery cycle")

        engine.pendingFocusSnapshot = snapshot()
        engine.applyDeliveryDecision(confirmedDecision(), modified: false)
        engine.stopSystem()
        assertConsistent("engine stop")
    }

    func testNewerDeliverySupersedesARetainedRecord() {
        let engine = TranscriptionEngine()
        engine.pendingFocusSnapshot = snapshot()
        engine.applyDeliveryDecision(confirmedDecision(), modified: false)
        XCTAssertTrue(engine.canUndoLastDictation)

        // A refusal that retains the record...
        engine.undoLastDictation(invocation: .globalShortcut)

        // ...is still superseded by the next dictation.
        engine.beginDeliveryCycle()

        XCTAssertFalse(engine.canUndoLastDictation)
        XCTAssertEqual(engine.undoAvailability.unavailableReason, .supersededByNewerDictation)
    }

    /// A retained refusal must leave the control enabled — the whole point of the repair.
    func testRetainedRefusalKeepsTheControlEnabledAndSaysUndoIsStillAvailable() {
        let engine = TranscriptionEngine()
        engine.pendingFocusSnapshot = snapshot()
        engine.applyDeliveryDecision(confirmedDecision(), modified: false)

        engine.undoLastDictation(invocation: .globalShortcut)

        XCTAssertTrue(
            UndoControlModel(availability: engine.undoAvailability).isEnabled,
            "A harmless failed attempt must not disable the control"
        )
        guard case .dictationUndoUnavailable(let reason) = engine.resultFeedback else {
            return XCTFail("Expected a precise unavailable reason, got \(engine.resultFeedback)")
        }
        XCTAssertTrue(
            reason.lowercased().contains("still available"),
            "A retained refusal must tell the user undo is still available: \(reason)"
        )
    }

    func testEveryFailureOutcomeHasADistinctPreciseReason() {
        let outcomes: [DictationUndoOutcome] = [
            .nothingToUndo, .focusChanged, .contentChanged, .cannotVerify, .targetUnavailable
        ]
        let reasons = outcomes.map {
            TranscriptionEngine.undoFailureReason(for: $0, invocation: .globalShortcut)
        }

        XCTAssertEqual(Set(reasons).count, outcomes.count, "Each failure must state its own reason")
        for reason in reasons {
            XCTAssertFalse(reason.isEmpty)
            XCTAssertNotEqual(reason, "Couldn't undo.", "Reasons must be specific, not the generic title")
        }
    }

    // MARK: - Helpers

    private func confirmedDecision() -> OutputDeliveryDecision {
        OutputDeliveryDecision(
            delivery: .pastedToActiveApp,
            undoContext: DictationUndoContext(
                insertedText: " world",
                previousFieldValue: "hello",
                replacementRange: NSRange(location: 5, length: 0),
                targetApplication: OutputTargetApplication(
                    bundleIdentifier: "com.example.editor",
                    processIdentifier: 4242
                ),
                targetElement: savedElement
            )
        )
    }

    private func snapshot() -> FocusedElementSnapshot {
        FocusedElementSnapshot(
            role: "AXTextField",
            processIdentifier: 4242,
            bundleIdentifier: "com.example.editor"
        )
    }
}
