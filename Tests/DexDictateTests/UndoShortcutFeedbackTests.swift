import CoreGraphics
import XCTest
@testable import DexDictateKit

/// Covers the repair for "⌃⌥⌘Z did nothing": a matched chord with nothing armed still passes
/// through to the frontmost app, but no longer does so silently.
final class UndoShortcutFeedbackTests: XCTestCase {
    func testIneligibleChordPassesThroughAndSchedulesOneNotice() {
        let snapshot = DictationUndoEligibilitySnapshot()
        var undoRequests = 0
        var notices = 0

        let disposition = handle(snapshot: snapshot, requestUndo: { undoRequests += 1 }, notifyUnavailable: { notices += 1 })

        XCTAssertEqual(disposition, .passThrough)
        XCTAssertEqual(undoRequests, 0, "Nothing was armed — no undo may be attempted")
        XCTAssertEqual(notices, 1)
    }

    func testAutorepeatSchedulesNoNoticeAndNoUndo() {
        let snapshot = DictationUndoEligibilitySnapshot()
        var undoRequests = 0
        var notices = 0

        let disposition = handle(
            snapshot: snapshot,
            isAutorepeat: true,
            requestUndo: { undoRequests += 1 },
            notifyUnavailable: { notices += 1 }
        )

        XCTAssertEqual(disposition, .passThrough)
        XCTAssertEqual(undoRequests, 0)
        XCTAssertEqual(notices, 0, "Holding the chord must not spam feedback")
    }

    func testAutorepeatWithArmedUndoDoesNotConsumeTheClaim() {
        let snapshot = DictationUndoEligibilitySnapshot()
        snapshot.setEligible(true)
        var undoRequests = 0
        var notices = 0

        let disposition = handle(
            snapshot: snapshot,
            isAutorepeat: true,
            requestUndo: { undoRequests += 1 },
            notifyUnavailable: { notices += 1 }
        )

        XCTAssertEqual(disposition, .passThrough)
        XCTAssertEqual(undoRequests, 0)
        XCTAssertEqual(notices, 0)
        XCTAssertTrue(snapshot.claimIfEligible(), "Autorepeat must leave the pending claim intact")
    }

    func testNonMatchingEventsScheduleNothing() {
        let snapshot = DictationUndoEligibilitySnapshot()
        var undoRequests = 0
        var notices = 0
        let record: (UndoShortcutEventInput) -> UndoShortcutEventDisposition = { input in
            UndoShortcutEventPolicy.handle(
                input: input,
                claimEligibility: snapshot.claimIfEligible,
                requestUndo: { undoRequests += 1 },
                notifyUnavailable: { notices += 1 }
            )
        }

        let wrongKey = record(UndoShortcutEventInput(
            type: .keyDown,
            keyCode: 0x00,
            modifiers: InputMonitor.undoDictationModifierMask,
            isAutorepeat: false
        ))
        let wrongModifiers = record(UndoShortcutEventInput(
            type: .keyDown,
            keyCode: InputMonitor.undoDictationKeyCode,
            modifiers: CGEventFlags.maskCommand.rawValue,
            isAutorepeat: false
        ))
        let keyUp = record(UndoShortcutEventInput(
            type: .keyUp,
            keyCode: InputMonitor.undoDictationKeyCode,
            modifiers: InputMonitor.undoDictationModifierMask,
            isAutorepeat: false
        ))

        XCTAssertEqual(wrongKey, .notMatched)
        XCTAssertEqual(wrongModifiers, .notMatched)
        XCTAssertEqual(keyUp, .notMatched)
        XCTAssertEqual(undoRequests, 0)
        XCTAssertEqual(notices, 0)
    }

    func testEligibleChordStillConsumesAndRequestsExactlyOnce() {
        let snapshot = DictationUndoEligibilitySnapshot()
        snapshot.setEligible(true)
        var undoRequests = 0
        var notices = 0

        let disposition = handle(snapshot: snapshot, requestUndo: { undoRequests += 1 }, notifyUnavailable: { notices += 1 })

        XCTAssertEqual(disposition, .consume)
        XCTAssertEqual(undoRequests, 1)
        XCTAssertEqual(notices, 0)
    }

    func testRapidDuplicateKeyDownsCannotClaimTheSameUndoTwice() {
        let snapshot = DictationUndoEligibilitySnapshot()
        snapshot.setEligible(true)
        var undoRequests = 0
        var notices = 0
        let requestUndo = { undoRequests += 1 }
        let notifyUnavailable = { notices += 1 }

        let first = handle(snapshot: snapshot, requestUndo: requestUndo, notifyUnavailable: notifyUnavailable)
        let second = handle(snapshot: snapshot, requestUndo: requestUndo, notifyUnavailable: notifyUnavailable)
        let third = handle(snapshot: snapshot, requestUndo: requestUndo, notifyUnavailable: notifyUnavailable)

        XCTAssertEqual(first, .consume)
        XCTAssertEqual(second, .passThrough)
        XCTAssertEqual(third, .passThrough)
        XCTAssertEqual(undoRequests, 1, "Only the first key-down may schedule an undo")
        XCTAssertEqual(notices, 2, "Later presses correctly report that nothing is armed")
    }

    // MARK: - Rate limiting

    func testRateLimiterAllowsFirstNoticeThenSuppressesWithinTheInterval() {
        let limiter = UndoUnavailableNoticeRateLimiter(minimumInterval: 1.5)
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(limiter.shouldNotify(now: start))
        XCTAssertFalse(limiter.shouldNotify(now: start.addingTimeInterval(0.1)))
        XCTAssertFalse(limiter.shouldNotify(now: start.addingTimeInterval(1.4)))
    }

    func testRateLimiterAllowsAnotherNoticeAfterTheInterval() {
        let limiter = UndoUnavailableNoticeRateLimiter(minimumInterval: 1.5)
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(limiter.shouldNotify(now: start))
        XCTAssertTrue(limiter.shouldNotify(now: start.addingTimeInterval(1.5)))
        XCTAssertFalse(limiter.shouldNotify(now: start.addingTimeInterval(1.6)))
    }

    // MARK: - Engine-side feedback

    @MainActor
    func testEngineReportsFactualUnavailableFeedbackWithoutClaimingFailure() {
        let engine = TranscriptionEngine()

        engine.reportUndoUnavailableForShortcut()

        guard case .dictationUndoUnavailable(let reason) = engine.resultFeedback else {
            return XCTFail("Expected dictationUndoUnavailable, got \(engine.resultFeedback)")
        }
        XCTAssertEqual(reason, "No recent reversible dictation to undo.")
        XCTAssertFalse(engine.canUndoLastDictation)
    }

    // MARK: - Helpers

    private func handle(
        snapshot: DictationUndoEligibilitySnapshot,
        isAutorepeat: Bool = false,
        requestUndo: () -> Void,
        notifyUnavailable: () -> Void
    ) -> UndoShortcutEventDisposition {
        UndoShortcutEventPolicy.handle(
            input: UndoShortcutEventInput(
                type: .keyDown,
                keyCode: InputMonitor.undoDictationKeyCode,
                modifiers: InputMonitor.undoDictationModifierMask,
                isAutorepeat: isAutorepeat
            ),
            claimEligibility: snapshot.claimIfEligible,
            requestUndo: requestUndo,
            notifyUnavailable: notifyUnavailable
        )
    }
}
