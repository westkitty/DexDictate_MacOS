import ApplicationServices
import XCTest
@testable import DexDictateKit

@MainActor
final class DeliveryUndoSupersessionTests: XCTestCase {
    private let targetElement = AXUIElementCreateSystemWide()

    func testConfirmedReversibleDeliveryArmsUndo() {
        let engine = TranscriptionEngine()
        engine.pendingFocusSnapshot = focusSnapshot()

        engine.applyDeliveryDecision(confirmedDecision(), modified: false)

        XCTAssertTrue(engine.canUndoLastDictation)
        XCTAssertEqual(engine.resultFeedback, .pastedToActiveApp(modified: false))
    }

    func testEveryNonReversibleDeliveryClearsStaleUndo() {
        let engine = TranscriptionEngine()
        let deliveries: [OutputDelivery] = [
            .savedOnly,
            .copiedOnly(reason: "Copy only"),
            .blocked(reason: "Focus invalidated"),
            .failed(reason: "Delivery failed"),
            .requestedButUnverified
        ]

        for delivery in deliveries {
            engine.pendingFocusSnapshot = focusSnapshot()
            engine.applyDeliveryDecision(confirmedDecision(), modified: false)
            XCTAssertTrue(engine.canUndoLastDictation)

            engine.applyDeliveryDecision(OutputDeliveryDecision(delivery: delivery), modified: false)
            XCTAssertFalse(engine.canUndoLastDictation, "Stale undo survived \(delivery)")
        }
    }

    func testStartingLaterDeliveryCycleClearsStaleUndo() {
        let engine = TranscriptionEngine()
        engine.pendingFocusSnapshot = focusSnapshot()
        engine.applyDeliveryDecision(confirmedDecision(), modified: false)
        XCTAssertTrue(engine.canUndoLastDictation)

        engine.beginDeliveryCycle()

        XCTAssertFalse(engine.canUndoLastDictation)
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
