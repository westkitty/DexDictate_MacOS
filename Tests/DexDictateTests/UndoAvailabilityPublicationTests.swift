import ApplicationServices
import Combine
import XCTest
@testable import DexDictateKit

/// Covers the repair for the user-visible failure "no Undo Last Dictation button": the
/// engine now publishes undo availability instead of exposing a computed property backed by
/// a non-observable manager, so SwiftUI is guaranteed a refresh on arm and on clear.
@MainActor
final class UndoAvailabilityPublicationTests: XCTestCase {
    private let targetElement = AXUIElementCreateSystemWide()
    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testConfirmedReversibleDeliveryPublishesAvailabilityTrue() {
        let engine = TranscriptionEngine()
        XCTAssertFalse(engine.canUndoLastDictation)

        engine.pendingFocusSnapshot = focusSnapshot()
        engine.applyDeliveryDecision(confirmedDecision(), modified: false)

        XCTAssertTrue(engine.canUndoLastDictation)
    }

    func testLaterDeliveryCyclePublishesAvailabilityFalse() {
        let engine = armedEngine()

        engine.beginDeliveryCycle()

        XCTAssertFalse(engine.canUndoLastDictation)
    }

    func testNonReversibleDeliveryPublishesAvailabilityFalse() {
        let deliveries: [OutputDelivery] = [
            .savedOnly,
            .copiedOnly(reason: "Copy only"),
            .blocked(reason: "Focus invalidated"),
            .failed(reason: "Delivery failed"),
            .requestedButUnverified
        ]

        for delivery in deliveries {
            let engine = armedEngine()
            engine.applyDeliveryDecision(OutputDeliveryDecision(delivery: delivery), modified: false)
            XCTAssertFalse(
                engine.canUndoLastDictation,
                "Published availability survived non-reversible delivery \(delivery)"
            )
        }
    }

    func testUndoAttemptLeavesAvailabilityFalse() {
        let engine = armedEngine()

        // No real AX target exists in the test process, so this resolves to a refusal —
        // which must still consume the one-shot record and republish availability.
        engine.undoLastDictation()

        XCTAssertFalse(engine.canUndoLastDictation)
    }

    func testStoppingTheSystemPublishesAvailabilityFalse() {
        let engine = armedEngine()

        engine.stopSystem()

        XCTAssertFalse(engine.canUndoLastDictation)
    }

    func testObjectWillChangeEmitsForBothArmAndClearTransitions() {
        let engine = TranscriptionEngine()
        engine.pendingFocusSnapshot = focusSnapshot()

        var armEmissions = 0
        engine.objectWillChange
            .sink { _ in armEmissions += 1 }
            .store(in: &cancellables)

        engine.applyDeliveryDecision(confirmedDecision(), modified: false)
        XCTAssertTrue(engine.canUndoLastDictation)
        XCTAssertGreaterThan(armEmissions, 0, "Arming undo must publish a SwiftUI update")

        // `beginDeliveryCycle()` touches no other @Published property, so any emission here
        // proves the availability mirror — not an incidental `resultFeedback` write — is
        // what refreshes the view.
        var clearEmissions = 0
        let clearObserver = engine.objectWillChange.sink { _ in clearEmissions += 1 }
        engine.beginDeliveryCycle()
        clearObserver.cancel()

        XCTAssertFalse(engine.canUndoLastDictation)
        XCTAssertGreaterThan(clearEmissions, 0, "Clearing undo must publish a SwiftUI update")
    }

    // MARK: - Active slim-popover presentation contract

    /// `PopoverResultView` renders `UndoLastDictationButton`, which renders exactly this
    /// model. The SwiftUI hierarchy itself is not unit-testable here (the test target does
    /// not depend on the app executable target), so the rendered pixels remain a manual
    /// check — but the visibility rule and its copy are pinned.
    func testUndoControlModelIsVisibleOnlyWhenUndoIsAvailable() {
        XCTAssertTrue(UndoControlModel(canUndoLastDictation: true).isVisible)
        XCTAssertFalse(UndoControlModel(canUndoLastDictation: false).isVisible)
    }

    func testUndoControlModelCopyIsActionOrientedAndFactual() {
        let model = UndoControlModel(canUndoLastDictation: true)
        XCTAssertEqual(model.title, "Undo Last Dictation")
        XCTAssertFalse(model.accessibilityLabel.isEmpty)
        XCTAssertFalse(model.helpText.isEmpty)
    }

    // MARK: - Late callback protection

    func testStaleDeliveryCallbackCannotOverwriteNewerState() {
        let engine = TranscriptionEngine()

        // Cycle 1 is in flight with its own delivery identifier.
        engine.beginDeliveryCycle()
        let staleDeliveryID = UUID()
        engine.pendingDeliveryID = staleDeliveryID

        // Cycle 2 supersedes it and lands a confirmed, reversible insertion.
        engine.beginDeliveryCycle()
        let currentDeliveryID = UUID()
        engine.pendingDeliveryID = currentDeliveryID
        engine.pendingFocusSnapshot = focusSnapshot()
        engine.applyDeliveryCompletion(
            confirmedDecision(),
            deliveryID: currentDeliveryID,
            modified: false
        )
        XCTAssertTrue(engine.canUndoLastDictation)
        XCTAssertEqual(engine.resultFeedback, .pastedToActiveApp(modified: false))

        // Cycle 1's callback finally fires. It must be dropped entirely.
        engine.applyDeliveryCompletion(
            OutputDeliveryDecision(delivery: .failed(reason: "Stale cycle")),
            deliveryID: staleDeliveryID,
            modified: true
        )

        XCTAssertTrue(engine.canUndoLastDictation, "Stale callback cleared newer undo state")
        XCTAssertEqual(
            engine.resultFeedback,
            .pastedToActiveApp(modified: false),
            "Stale callback overwrote newer feedback"
        )
    }

    func testCurrentDeliveryCallbackStillApplies() {
        let engine = TranscriptionEngine()
        let deliveryID = UUID()
        engine.pendingDeliveryID = deliveryID

        engine.applyDeliveryCompletion(
            OutputDeliveryDecision(delivery: .requestedButUnverified),
            deliveryID: deliveryID,
            modified: false
        )

        XCTAssertEqual(engine.resultFeedback, .pasteRequestedUnverified(modified: false))
    }

    // MARK: - Helpers

    private func armedEngine() -> TranscriptionEngine {
        let engine = TranscriptionEngine()
        engine.pendingFocusSnapshot = focusSnapshot()
        engine.applyDeliveryDecision(confirmedDecision(), modified: false)
        XCTAssertTrue(engine.canUndoLastDictation, "Precondition: undo should be armed")
        return engine
    }

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
                targetElement: targetElement
            )
        )
    }

    private func focusSnapshot() -> FocusedElementSnapshot {
        FocusedElementSnapshot(
            role: "AXTextField",
            processIdentifier: 4242,
            bundleIdentifier: "com.example.editor"
        )
    }
}
