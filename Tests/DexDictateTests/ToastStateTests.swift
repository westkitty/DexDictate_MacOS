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
        // Uses a virtual clock instead of real sleeps: the previous version of
        // this test polled real wall-clock delays with ~16-32ms margins, which
        // CI scheduling jitter could violate in either direction. Advancing
        // the clock only makes the dismiss Task *ready*; `settle()` yields
        // cooperatively (no real time elapses) until it has actually run.
        let clock = ManualClock()
        let dismissDelay: TimeInterval = 0.08
        let state = ToastState(dismissAfter: dismissDelay, clock: clock)

        // Show first toast.
        state.show(.outputInserted)

        // After half the dismiss window, replace it with a new toast. This
        // should cancel the original timer outright.
        clock.advance(by: .seconds(dismissDelay * 0.5))
        await settleTurns()
        state.show(.outputSavedOnly)
        XCTAssertEqual(state.current, .outputSavedOnly)
        await settleTurns() // let the cancelled timer's cancellation handler finish removing it

        // Advance to just before the replacement's own dismiss window elapses.
        // If the original (cancelled) timer were still active it would have
        // fired well before this point, so this proves cancellation worked.
        clock.advance(by: .seconds(dismissDelay * 0.9))
        await settleTurns()
        XCTAssertEqual(state.current, .outputSavedOnly,
            "Replacement toast should still be visible — its own timer hasn't expired yet")

        // Advance past the replacement's full dismiss window.
        clock.advance(by: .seconds(dismissDelay * 0.2))
        await settleUntil { state.current == nil }
        XCTAssertNil(state.current, "Replacement toast should have auto-dismissed")
    }

    /// Cooperatively yields a fixed number of scheduler turns. No real time
    /// elapses, so this is immediate regardless of system load — unlike a
    /// real sleep, it never races against CI scheduling jitter.
    private func settleTurns(_ turns: Int = 10) async {
        for _ in 0..<turns {
            await Task.yield()
        }
    }

    /// Cooperatively yields until `condition` holds or the turn budget runs
    /// out (in which case the subsequent assertion reports the real failure).
    private func settleUntil(maxTurns: Int = 100, _ condition: () -> Bool) async {
        for _ in 0..<maxTurns {
            if condition() { return }
            await Task.yield()
        }
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
