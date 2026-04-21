import CoreAudio
import XCTest
@testable import DexDictateKit

final class AudioRecorderRecoveryPlannerTests: XCTestCase {
    func testPreferredInputStillPresentAfterRouteChangeStaysOnPreferredMic() throws {
        let planner = makePlanner(
            resolutionSequence: [.available(AudioInputDeviceMatch(uid: "mic-a", deviceID: 11, hasInputChannels: true))],
            startHandler: { selection, _, _ in
                guard case .preferred(let match) = selection else {
                    return self.XCTFailingStartedInput("Expected preferred input selection")
                }
                return AudioRecorderStartedInput(uid: match.uid, deviceID: match.deviceID)
            }
        )

        let report = try planner.execute(preferredUID: "mic-a", reason: .routeRecovery)

        XCTAssertEqual(report.activeInputUID, "mic-a")
        XCTAssertEqual(report.activeInputDeviceID, AudioDeviceID(11))
        XCTAssertFalse(report.usedSystemDefault)
        XCTAssertEqual(report.retryCount, 0)
        XCTAssertNil(report.recoveryNotice)
    }

    func testPreferredInputTemporarilyUnavailableThenRecoverableRetriesPreferredFirst() throws {
        let planner = makePlanner(
            resolutionSequence: [
                .missing(uid: "mic-a"),
                .missing(uid: "mic-a"),
                .available(AudioInputDeviceMatch(uid: "mic-a", deviceID: 22, hasInputChannels: true))
            ],
            startHandler: { selection, _, attemptIndex in
                guard case .preferred(let match) = selection else {
                    return self.XCTFailingStartedInput("Expected preferred input selection on attempt \(attemptIndex + 1)")
                }
                return AudioRecorderStartedInput(uid: match.uid, deviceID: match.deviceID)
            }
        )

        let report = try planner.execute(preferredUID: "mic-a", reason: .routeRecovery)

        XCTAssertEqual(report.activeInputUID, "mic-a")
        XCTAssertFalse(report.usedSystemDefault)
        XCTAssertEqual(report.retryCount, 2)
        XCTAssertFalse(report.shouldClearStoredPreferredUID)
    }

    func testPreferredInputMissingFallsBackToSystemDefaultAndClearsStoredSelection() throws {
        let planner = makePlanner(
            resolutionSequence: [
                .missing(uid: "missing-mic"),
                .missing(uid: "missing-mic"),
                .missing(uid: "missing-mic")
            ],
            startHandler: { selection, _, _ in
                guard case .systemDefault = selection else {
                    return self.XCTFailingStartedInput("Expected system-default fallback")
                }
                return AudioRecorderStartedInput(uid: "", deviceID: nil)
            }
        )

        let report = try planner.execute(preferredUID: "missing-mic", reason: .routeRecovery)

        XCTAssertTrue(report.usedSystemDefault)
        XCTAssertEqual(report.activeInputUID, "")
        XCTAssertEqual(report.retryCount, 2)
        XCTAssertTrue(report.shouldClearStoredPreferredUID)
        XCTAssertEqual(
            report.recoveryNotice,
            "Selected microphone is unavailable. DexDictate switched to System Default input."
        )
    }

    func testPreferredInputThatStillExistsButCannotOpenFallsBackWithoutClearingPreference() throws {
        let planner = makePlanner(
            resolutionSequence: [
                .available(AudioInputDeviceMatch(uid: "mic-a", deviceID: 42, hasInputChannels: true)),
                .available(AudioInputDeviceMatch(uid: "mic-a", deviceID: 42, hasInputChannels: true)),
                .available(AudioInputDeviceMatch(uid: "mic-a", deviceID: 42, hasInputChannels: true))
            ],
            startHandler: { selection, _, _ in
                switch selection {
                case .preferred:
                    throw DictationError.audioEngineSetupFailed("coreaudio.avfaudio error -10868")
                case .systemDefault:
                    return AudioRecorderStartedInput(uid: "", deviceID: nil)
                }
            }
        )

        let report = try planner.execute(preferredUID: "mic-a", reason: .routeRecovery)

        XCTAssertTrue(report.usedSystemDefault)
        XCTAssertFalse(report.shouldClearStoredPreferredUID)
        XCTAssertEqual(report.retryCount, 2)
        XCTAssertNotNil(report.recoveryNotice)
    }

    func testRepeatedRouteRecoveriesDoNotAddDuplicatePreferredAttempts() throws {
        var startSelections: [AudioRecorderSelectedInput] = []
        let planner = AudioRecorderRecoveryPlanner(
            retryDelays: [0, 0.1, 0.2],
            sleep: { _ in },
            log: { _ in },
            resolvePreferredInput: { _ in
                .available(AudioInputDeviceMatch(uid: "mic-a", deviceID: 7, hasInputChannels: true))
            },
            startAttempt: { selection, _, _ in
                startSelections.append(selection)
                switch selection {
                case .preferred(let match):
                    return AudioRecorderStartedInput(uid: match.uid, deviceID: match.deviceID)
                case .systemDefault:
                    return AudioRecorderStartedInput(uid: "", deviceID: nil)
                }
            }
        )

        _ = try planner.execute(preferredUID: "mic-a", reason: .routeRecovery)
        _ = try planner.execute(preferredUID: "mic-a", reason: .routeRecovery)

        XCTAssertEqual(startSelections.count, 2)
        XCTAssertEqual(startSelections, [
            .preferred(AudioInputDeviceMatch(uid: "mic-a", deviceID: 7, hasInputChannels: true)),
            .preferred(AudioInputDeviceMatch(uid: "mic-a", deviceID: 7, hasInputChannels: true))
        ])
    }

    private func makePlanner(
        resolutionSequence: [AudioInputDeviceResolution],
        startHandler: @escaping (AudioRecorderSelectedInput, AudioRecorderStartReason, Int) throws -> AudioRecorderStartedInput
    ) -> AudioRecorderRecoveryPlanner {
        var resolutions = resolutionSequence
        return AudioRecorderRecoveryPlanner(
            retryDelays: [0, 0.1, 0.2],
            sleep: { _ in },
            log: { _ in },
            resolvePreferredInput: { _ in
                if resolutions.count > 1 {
                    return resolutions.removeFirst()
                }
                return resolutions[0]
            },
            startAttempt: startHandler
        )
    }

    private func XCTFailingStartedInput(_ message: String) -> AudioRecorderStartedInput {
        XCTFail(message)
        return AudioRecorderStartedInput(uid: "", deviceID: nil)
    }
}
