import XCTest
@testable import DexDictateKit

final class OnboardingValidationTests: XCTestCase {
    func testTriggerValidationMessagesRemainDistinct() {
        XCTAssertNotEqual(TriggerValidationState.missingAccessibility.headline,
                          TriggerValidationState.missingInputMonitoring.headline)
        XCTAssertNotEqual(TriggerValidationState.missingInputMonitoring.detail,
                          TriggerValidationState.eventTapUnavailable.detail)
        XCTAssertTrue(TriggerValidationState.ready.isSuccess)
        XCTAssertFalse(TriggerValidationState.eventTapUnavailable.isSuccess)
    }

    func testMicrophoneValidationMessagesRemainDistinct() {
        XCTAssertEqual(MicrophoneValidationState.permissionRequired.headline,
                       "Microphone permission is still missing")
        XCTAssertEqual(MicrophoneValidationState.noDevicesAvailable.headline,
                       "No microphone devices were found")
        XCTAssertEqual(MicrophoneValidationState.noInputDetected.headline,
                       "No microphone activity was detected")
        XCTAssertEqual(MicrophoneValidationState.recorderFailed("boom").headline,
                       "Microphone test could not start")
        XCTAssertTrue(MicrophoneValidationState.ready.isSuccess)
        XCTAssertFalse(MicrophoneValidationState.running.isSuccess)
    }
}
