import XCTest
@testable import DexDictateKit

final class AudioRecorderRecoveryFailureTests: XCTestCase {
    func testLocalizedDescriptionPrefersRecoveryNotice() {
        let failure = AudioRecorderRecoveryFailure(
            reason: .initialStart,
            requestedPreferredUID: "mic-a",
            preferredInputDeviceID: nil,
            retryCount: 2,
            recoveryNotice: "Selected microphone is unavailable. DexDictate switched to System Default input.",
            shouldClearStoredPreferredUID: true,
            underlyingError: DictationError.audioEngineSetupFailed("coreaudio.avfaudio error -10868")
        )

        XCTAssertEqual(
            failure.localizedDescription,
            "Selected microphone is unavailable. DexDictate switched to System Default input."
        )
    }

    func testLocalizedDescriptionFallsBackToFriendlyInitialStartMessage() {
        let failure = AudioRecorderRecoveryFailure(
            reason: .initialStart,
            requestedPreferredUID: "mic-a",
            preferredInputDeviceID: nil,
            retryCount: 2,
            recoveryNotice: nil,
            shouldClearStoredPreferredUID: false,
            underlyingError: DictationError.audioEngineSetupFailed("coreaudio.avfaudio error -10868")
        )

        XCTAssertEqual(
            failure.localizedDescription,
            "DexDictate could not open the selected microphone. Audio engine setup failed: coreaudio.avfaudio error -10868\n\nThis is usually a macOS Core Audio problem, not a DexDictate settings problem.\nFix: open Terminal and run:\nsudo killall -9 coreaudiod\n\nThen try DexDictate again."
        )
    }
}
