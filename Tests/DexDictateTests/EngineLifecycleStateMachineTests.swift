import XCTest
@testable import DexDictateKit

final class EngineLifecycleStateMachineTests: XCTestCase {
    func testHappyPathTransitionsReachReadyAgain() {
        var machine = EngineLifecycleStateMachine()

        XCTAssertEqual(machine.apply(.startSystemRequested)?.to, .initializing)
        XCTAssertEqual(machine.apply(.inputMonitorActivated)?.to, .ready)
        XCTAssertEqual(machine.apply(.listeningStarted)?.to, .listening)
        XCTAssertEqual(machine.apply(.transcriptionStarted)?.to, .transcribing)
        XCTAssertEqual(machine.apply(.transcriptionCompleted)?.to, .ready)
    }

    func testInputMonitorRecoveryFromErrorReturnsToReady() {
        var machine = EngineLifecycleStateMachine(state: .initializing)

        XCTAssertEqual(machine.apply(.inputMonitorFailed)?.to, .error)
        XCTAssertEqual(machine.apply(.inputMonitorActivated)?.to, .ready)
    }

    func testAudioCaptureFailureReturnsToReady() {
        var machine = EngineLifecycleStateMachine(state: .ready)

        XCTAssertEqual(machine.apply(.listeningStarted)?.to, .listening)
        XCTAssertEqual(machine.apply(.audioCaptureFailed)?.to, .ready)
    }

    func testImportedFileTranscriptionCanStartFromReady() {
        var machine = EngineLifecycleStateMachine(state: .ready)

        XCTAssertEqual(machine.apply(.transcriptionStarted)?.to, .transcribing)
        XCTAssertEqual(machine.apply(.transcriptionCompleted)?.to, .ready)
    }

    func testInvalidTransitionsAreRejected() {
        var machine = EngineLifecycleStateMachine()

        XCTAssertNil(machine.apply(.transcriptionStarted))
        XCTAssertEqual(machine.state, .stopped)

        XCTAssertEqual(machine.apply(.startSystemRequested)?.to, .initializing)
        XCTAssertNil(machine.apply(.transcriptionCompleted))
        XCTAssertEqual(machine.state, .initializing)
    }

    func testSystemStoppedIsAlwaysAllowed() {
        for state in EngineState.allCases {
            var machine = EngineLifecycleStateMachine(state: state)
            XCTAssertEqual(machine.apply(.systemStopped)?.to, .stopped)
            XCTAssertEqual(machine.state, .stopped)
        }
    }
}
