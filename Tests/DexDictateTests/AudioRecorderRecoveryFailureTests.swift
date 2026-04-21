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
            "DexDictate could not open the selected microphone. Try again."
        )
    }

    func testRecoveryNoticeOmitsUnderlyingErrorDump() {
        let planner = AudioRecorderRecoveryPlanner(
            retryDelays: [0],
            sleep: { _ in },
            log: { _ in },
            resolvePreferredInput: { _ in
                .available(AudioInputDeviceMatch(uid: "mic-a", deviceID: 1, hasInputChannels: true))
            },
            startAttempt: { selection, _, _ in
                switch selection {
                case .preferred:
                    throw DictationError.audioEngineSetupFailed("coreaudio.avfaudio error -10868")
                case .systemDefault:
                    return AudioRecorderStartedInput(uid: "", deviceID: nil)
                }
            }
        )

        let report = try? planner.execute(preferredUID: "mic-a", reason: .initialStart)

        XCTAssertEqual(
            report?.recoveryNotice,
            "Preferred microphone could not be opened. DexDictate switched to System Default input."
        )
    }
}
