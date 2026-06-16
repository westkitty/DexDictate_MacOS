import XCTest
@testable import DexDictateKit

/// Verifies the tap-state machine and the start/recovery overlap guard inside
/// `AudioRecorderService`, using the DEBUG-only seams that exercise the real
/// private code paths.
final class AudioRecorderTapStateTests: XCTestCase {
    func testTeardownClearsBelievedTapState() {
        let service = AudioRecorderService()

        // Simulate a tap having been installed, then run the real teardown path.
        service.setTapBelievedInstalledForTesting(true)
        XCTAssertTrue(service.isTapInstalledForTesting)

        service.teardownEngineForTesting()
        XCTAssertFalse(service.isTapInstalledForTesting, "Teardown must clear believed tap state")
    }

    func testTeardownIsIdempotentWhenNoTapInstalled() {
        let service = AudioRecorderService()
        XCTAssertFalse(service.isTapInstalledForTesting)

        // Running teardown repeatedly with no tap installed must not flip state or crash.
        service.teardownEngineForTesting()
        service.teardownEngineForTesting()
        XCTAssertFalse(service.isTapInstalledForTesting)
    }

    func testStartAttemptGuardRejectsOverlap() {
        let service = AudioRecorderService()

        XCTAssertFalse(service.isStartInProgressForTesting)
        XCTAssertTrue(service.beginStartAttemptForTesting(), "First attempt acquires the slot")
        XCTAssertTrue(service.isStartInProgressForTesting)

        // A second, overlapping attempt must be rejected — this is what prevents the
        // recovery planner from re-entering tap installation mid-start.
        XCTAssertFalse(service.beginStartAttemptForTesting(), "Overlapping attempt is rejected")

        service.endStartAttemptForTesting()
        XCTAssertFalse(service.isStartInProgressForTesting)

        // Once released, a fresh attempt may acquire the slot again.
        XCTAssertTrue(service.beginStartAttemptForTesting(), "Slot is reusable after release")
        service.endStartAttemptForTesting()
    }
}
