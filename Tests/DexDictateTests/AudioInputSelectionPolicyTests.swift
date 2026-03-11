import XCTest
@testable import DexDictateKit

final class AudioInputSelectionPolicyTests: XCTestCase {
    func testMissingPreferredDeviceFallsBackToSystemDefault() {
        let devices = [AudioInputDevice(uid: "mic-a", name: "Mic A")]

        let decision = AudioInputSelectionPolicy.resolve(preferredUID: "missing", availableDevices: devices)

        XCTAssertEqual(decision.normalizedUID, "")
        XCTAssertTrue(decision.fellBackToSystemDefault)
        XCTAssertEqual(
            decision.recoveryNotice,
            "Selected microphone is unavailable. DexDictate will use System Default until you choose another device."
        )
    }

    func testAvailablePreferredDeviceIsPreserved() {
        let devices = [
            AudioInputDevice(uid: "mic-a", name: "Mic A"),
            AudioInputDevice(uid: "mic-b", name: "Mic B")
        ]

        let decision = AudioInputSelectionPolicy.resolve(preferredUID: "mic-b", availableDevices: devices)

        XCTAssertEqual(decision.normalizedUID, "mic-b")
        XCTAssertNil(decision.recoveryNotice)
    }

    func testSystemDefaultSelectionRemainsUntouched() {
        let decision = AudioInputSelectionPolicy.resolve(preferredUID: "", availableDevices: [])

        XCTAssertEqual(decision.normalizedUID, "")
        XCTAssertNil(decision.recoveryNotice)
        XCTAssertFalse(decision.fellBackToSystemDefault)
    }
}
