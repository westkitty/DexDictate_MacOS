import CoreGraphics
import XCTest
@testable import DexDictateKit

final class InputMonitorTests: XCTestCase {
    func testUndoChordPassesThroughWhenEligibilityIsUnavailable() {
        let snapshot = DictationUndoEligibilitySnapshot()
        var requestCount = 0

        let disposition = handle(snapshot: snapshot) {
            requestCount += 1
        }

        XCTAssertEqual(disposition, .passThrough)
        XCTAssertEqual(requestCount, 0)
    }

    func testEligibleInitialUndoChordConsumesAndRequestsOnce() {
        let snapshot = DictationUndoEligibilitySnapshot()
        snapshot.setEligible(true)
        var requestCount = 0

        let disposition = handle(snapshot: snapshot) {
            requestCount += 1
        }

        XCTAssertEqual(disposition, .consume)
        XCTAssertEqual(requestCount, 1)
    }

    func testAutorepeatPassesThroughWithoutClaimingEligibility() {
        let snapshot = DictationUndoEligibilitySnapshot()
        snapshot.setEligible(true)
        var requestCount = 0

        let disposition = handle(snapshot: snapshot, isAutorepeat: true) {
            requestCount += 1
        }

        XCTAssertEqual(disposition, .passThrough)
        XCTAssertEqual(requestCount, 0)
        XCTAssertTrue(snapshot.claimIfEligible(), "Autorepeat must not consume the pending eligibility claim")
    }

    func testClaimedEligibilityCannotRequestASecondUndo() {
        let snapshot = DictationUndoEligibilitySnapshot()
        snapshot.setEligible(true)
        var requestCount = 0
        let requestUndo = { requestCount += 1 }

        let first = handle(snapshot: snapshot, requestUndo: requestUndo)
        let second = handle(snapshot: snapshot, requestUndo: requestUndo)

        XCTAssertEqual(first, .consume)
        XCTAssertEqual(second, .passThrough)
        XCTAssertEqual(requestCount, 1)
    }

    private func handle(
        snapshot: DictationUndoEligibilitySnapshot,
        isAutorepeat: Bool = false,
        requestUndo: () -> Void
    ) -> UndoShortcutEventDisposition {
        UndoShortcutEventPolicy.handle(
            input: UndoShortcutEventInput(
                type: .keyDown,
                keyCode: InputMonitor.undoDictationKeyCode,
                modifiers: InputMonitor.undoDictationModifierMask,
                isAutorepeat: isAutorepeat
            ),
            claimEligibility: snapshot.claimIfEligible,
            requestUndo: requestUndo
        )
    }
}
