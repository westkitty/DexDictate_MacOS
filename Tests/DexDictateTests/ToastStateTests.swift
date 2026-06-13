import XCTest
@testable import DexDictateKit

@MainActor
final class ToastStateTests: XCTestCase {

    // MARK: - Initial state

    func testInitialCurrentIsNil() {
        let state = ToastState()
        XCTAssertNil(state.current)
    }

    // MARK: - show()

    func testShowSetsCurrentImmediately() {
        let state = ToastState(dismissAfter: 60)
        state.show(.outputInserted)
        XCTAssertEqual(state.current, .outputInserted)
    }

    func testShowReplacesCurrentWithoutDelay() {
        let state = ToastState(dismissAfter: 60)
        state.show(.outputInserted)
        state.show(.outputSavedOnly)
        XCTAssertEqual(state.current, .outputSavedOnly)
    }

    func testShowCanDisplayAllEventCases() {
        let state = ToastState(dismissAfter: 60)
        let events: [ToastEvent] = [
            .commandExecuted(name: "Scratch That"),
            .customCommandExecuted(keyword: "hello"),
            .outputInserted,
            .clipboardFallback(reason: "Sensitive field"),
            .outputSavedOnly,
        ]
        for event in events {
            state.show(event)
            XCTAssertEqual(state.current, event, "Expected \(event) to be set as current")
        }
    }

    // MARK: - clear()

    func testClearSetsCurrentToNil() {
        let state = ToastState(dismissAfter: 60)
        state.show(.outputInserted)
        state.clear()
        XCTAssertNil(state.current)
    }

    func testClearOnEmptyStateIsNoop() {
        let state = ToastState()
        state.clear()   // must not crash
        XCTAssertNil(state.current)
    }

    // MARK: - Auto-dismiss

    func testAutoDismissAfterTimeout() async throws {
        let dismissDelay: TimeInterval = 0.05
        let state = ToastState(dismissAfter: dismissDelay)
        state.show(.outputInserted)
        XCTAssertEqual(state.current, .outputInserted)

        // Wait a bit longer than the dismiss delay.
        try await Task.sleep(nanoseconds: UInt64((dismissDelay + 0.10) * 1_000_000_000))
        XCTAssertNil(state.current, "Toast should have auto-dismissed after \(dismissDelay)s")
    }

    func testNewShowCancelsOldDismissTimer() async throws {
        let dismissDelay: TimeInterval = 0.08
        let state = ToastState(dismissAfter: dismissDelay)

        // Show first toast.
        state.show(.outputInserted)

        // After half the dismiss window, replace it with a new toast.
        try await Task.sleep(nanoseconds: UInt64(dismissDelay * 0.5 * 1_000_000_000))
        state.show(.outputSavedOnly)
        XCTAssertEqual(state.current, .outputSavedOnly)

        // The original timer should have been cancelled; new toast is still visible
        // just before the full dismiss window of the replacement would expire.
        try await Task.sleep(nanoseconds: UInt64(dismissDelay * 0.6 * 1_000_000_000))
        XCTAssertEqual(state.current, .outputSavedOnly,
            "Replacement toast should still be visible — its own timer hasn't expired yet")

        // After the full replacement dismiss window expires, the toast should be gone.
        try await Task.sleep(nanoseconds: UInt64(dismissDelay * 0.6 * 1_000_000_000))
        XCTAssertNil(state.current, "Replacement toast should have auto-dismissed")
    }

    // MARK: - ToastEvent properties

    func testCommandExecutedLabel() {
        let event = ToastEvent.commandExecuted(name: "Scratch That")
        XCTAssertEqual(event.label, "Command: Scratch That")
        XCTAssertFalse(event.symbolName.isEmpty)
    }

    func testCustomCommandExecutedLabel() {
        let event = ToastEvent.customCommandExecuted(keyword: "salut")
        XCTAssertEqual(event.label, "Dex salut")
        XCTAssertFalse(event.symbolName.isEmpty)
    }

    func testOutputInsertedLabel() {
        XCTAssertEqual(ToastEvent.outputInserted.label, "Inserted")
    }

    func testClipboardFallbackLabel() {
        let event = ToastEvent.clipboardFallback(reason: "Password field")
        XCTAssertEqual(event.label, "Copied to clipboard")
    }

    func testOutputSavedOnlyLabel() {
        XCTAssertEqual(ToastEvent.outputSavedOnly.label, "Saved to history")
    }

    // MARK: - Equatability

    func testEventEquatability() {
        XCTAssertEqual(ToastEvent.outputInserted, .outputInserted)
        XCTAssertEqual(
            ToastEvent.commandExecuted(name: "Scratch That"),
            .commandExecuted(name: "Scratch That")
        )
        XCTAssertNotEqual(
            ToastEvent.commandExecuted(name: "Scratch That"),
            .commandExecuted(name: "Other")
        )
        XCTAssertNotEqual(ToastEvent.outputInserted, .outputSavedOnly)
    }
}
