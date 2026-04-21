import CoreAudio
import XCTest
@testable import DexDictateKit

final class AudioDeviceManagerTests: XCTestCase {
    func testResolveInputDeviceReturnsAvailableMatchForInputCapableDevice() {
        let resolution = AudioDeviceManager.resolveInputDevice(
            forUID: "built-in-mic",
            deviceRecords: [
                AudioHardwareDeviceRecord(deviceID: AudioDeviceID(101), uid: "built-in-mic", hasInputChannels: true)
            ]
        )

        guard case .available(let match) = resolution else {
            return XCTFail("Expected available input match, got \(resolution)")
        }

        XCTAssertEqual(match.uid, "built-in-mic")
        XCTAssertEqual(match.deviceID, AudioDeviceID(101))
        XCTAssertTrue(match.hasInputChannels)
    }

    func testResolveInputDeviceRejectsOutputOnlyDevice() {
        let resolution = AudioDeviceManager.resolveInputDevice(
            forUID: "speaker-only",
            deviceRecords: [
                AudioHardwareDeviceRecord(deviceID: AudioDeviceID(77), uid: "speaker-only", hasInputChannels: false)
            ]
        )

        XCTAssertEqual(
            resolution,
            .unavailableAsInput(uid: "speaker-only", deviceID: AudioDeviceID(77))
        )
    }

    func testResolveInputDeviceReturnsMissingWhenUIDIsAbsent() {
        let resolution = AudioDeviceManager.resolveInputDevice(
            forUID: "missing",
            deviceRecords: [
                AudioHardwareDeviceRecord(deviceID: AudioDeviceID(1), uid: "other", hasInputChannels: true)
            ]
        )

        XCTAssertEqual(resolution, .missing(uid: "missing"))
    }
}
