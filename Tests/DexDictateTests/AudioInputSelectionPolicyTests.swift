import XCTest
@testable import DexDictateKit

final class AudioInputSelectionPolicyTests: XCTestCase {
    func testMissingPreferredDeviceFallsBackToSystemDefaultAfterGraceExpires() {
        let devices = [AudioInputDevice(uid: "mic-a", name: "Mic A")]

        let decision = AudioInputSelectionPolicy.resolve(
            preferredUID: "missing",
            availableDevices: devices,
            missingPreferredGraceExpired: true
        )

        XCTAssertEqual(decision.normalizedUID, "")
        XCTAssertTrue(decision.fellBackToSystemDefault)
        XCTAssertEqual(decision.status, .fellBackToSystemDefault)
        XCTAssertFalse(decision.shouldScheduleRecheck)
        XCTAssertEqual(
            decision.recoveryNotice,
            "Selected microphone is unavailable. DexDictate will use System Default until you choose another device."
        )
    }

    func testMissingPreferredDeviceIsRetainedDuringGracePeriod() {
        let devices = [AudioInputDevice(uid: "mic-a", name: "Mic A")]

        let decision = AudioInputSelectionPolicy.resolve(
            preferredUID: "missing",
            availableDevices: devices,
            missingPreferredGraceExpired: false
        )

        XCTAssertEqual(decision.normalizedUID, "missing")
        XCTAssertFalse(decision.fellBackToSystemDefault)
        XCTAssertEqual(decision.status, .preferredTemporarilyUnavailable)
        XCTAssertTrue(decision.shouldScheduleRecheck)
        XCTAssertEqual(
            decision.recoveryNotice,
            "Selected microphone is temporarily unavailable. DexDictate will keep trying it before falling back to System Default."
        )
    }

    func testAvailablePreferredDeviceIsPreserved() {
        let devices = [
            AudioInputDevice(uid: "mic-a", name: "Mic A"),
            AudioInputDevice(uid: "mic-b", name: "Mic B")
        ]

        let decision = AudioInputSelectionPolicy.resolve(preferredUID: "mic-b", availableDevices: devices)

        XCTAssertEqual(decision.normalizedUID, "mic-b")
        XCTAssertEqual(decision.status, .preferredAvailable)
        XCTAssertNil(decision.recoveryNotice)
        XCTAssertFalse(decision.shouldScheduleRecheck)
    }

    func testSystemDefaultSelectionRemainsUntouched() {
        let decision = AudioInputSelectionPolicy.resolve(preferredUID: "", availableDevices: [])

        XCTAssertEqual(decision.normalizedUID, "")
        XCTAssertEqual(decision.status, .systemDefault)
        XCTAssertNil(decision.recoveryNotice)
        XCTAssertFalse(decision.fellBackToSystemDefault)
        XCTAssertFalse(decision.shouldScheduleRecheck)
    }
}
