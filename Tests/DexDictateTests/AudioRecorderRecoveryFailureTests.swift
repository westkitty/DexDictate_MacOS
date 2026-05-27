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
            underlyingError: DictationError.audioEngineSetupFailed("generic error")
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
                    throw DictationError.audioEngineSetupFailed("generic error")
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

    func testAudioErrorClassifierIdentifiesCoreAudioDeviceStall() {
        let error1 = NSError(domain: "com.apple.coreaudio", code: -10868, userInfo: nil)
        let error2 = DictationError.audioEngineSetupFailed("coreaudio.avfaudio error -10868")
        let error3 = DictationError.audioEngineSetupFailed("kAudioOutputUnitErr_InvalidDevice")
        let error4 = DictationError.audioEngineSetupFailed("some generic error")
        let error5 = NSError(domain: NSOSStatusErrorDomain, code: -10868, userInfo: nil)
        let error6 = NSError(domain: "com.example", code: -10868, userInfo: nil) // Generic, no audio info
        let error7 = NSError(domain: "com.example", code: -10868, userInfo: [NSLocalizedDescriptionKey: "CoreAudio avfaudio error"]) // Generic with audio info

        XCTAssertTrue(AudioErrorClassifier.isCoreAudioDeviceStall(error1))
        XCTAssertTrue(AudioErrorClassifier.isCoreAudioDeviceStall(error2))
        XCTAssertTrue(AudioErrorClassifier.isCoreAudioDeviceStall(error3))
        XCTAssertFalse(AudioErrorClassifier.isCoreAudioDeviceStall(error4))
        XCTAssertTrue(AudioErrorClassifier.isCoreAudioDeviceStall(error5))
        XCTAssertFalse(AudioErrorClassifier.isCoreAudioDeviceStall(error6))
        XCTAssertTrue(AudioErrorClassifier.isCoreAudioDeviceStall(error7))
    }

    func testLocalizedDescriptionIncludesCoreAudioResetFor10868() {
        let failure = AudioRecorderRecoveryFailure(
            reason: .initialStart,
            requestedPreferredUID: "mic-a",
            preferredInputDeviceID: nil,
            retryCount: 2,
            recoveryNotice: nil,
            shouldClearStoredPreferredUID: false,
            underlyingError: NSError(domain: "com.apple.coreaudio", code: -10868, userInfo: nil)
        )

        XCTAssertTrue(failure.localizedDescription.contains("Core Audio error -10868 detected"))
        XCTAssertTrue(failure.localizedDescription.contains("sudo killall -9 coreaudiod"))
    }

    func testRecoveryNoticeIncludesCoreAudioResetFor10868() {
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
                    throw NSError(domain: "com.apple.coreaudio", code: -10868, userInfo: nil)
                case .systemDefault:
                    return AudioRecorderStartedInput(uid: "", deviceID: nil)
                }
            }
        )

        let report = try? planner.execute(preferredUID: "mic-a", reason: .initialStart)

        XCTAssertTrue(report?.recoveryNotice?.contains("Core Audio error -10868 detected") ?? false)
        XCTAssertTrue(report?.recoveryNotice?.contains("sudo killall -9 coreaudiod") ?? false)
    }
}
