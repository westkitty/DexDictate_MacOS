import XCTest
@testable import DexDictateKit

/// Regression coverage: the Silence Timeout auto-stop must never fire during Hold-to-Talk,
/// whose entire documented contract ("records only while the trigger is pressed") means the
/// user — not a timer — controls when recording stops. Previously
/// `TranscriptionEngine.startSilenceCountdownIfNeeded()` ran unconditionally whenever
/// `AppSettings.silenceTimeout > 0`, regardless of trigger mode, so a natural pause while
/// still holding the key would silently stop the recording out from under the user.
@MainActor
final class SilenceCountdownTriggerModeTests: XCTestCase {

    func testSilenceCountdownNeverRunsInHoldToTalkEvenWithATimeoutConfigured() {
        XCTAssertFalse(
            TranscriptionEngine.shouldRunSilenceCountdown(triggerMode: .holdToTalk, timeout: 5),
            "Hold-to-Talk must never be auto-stopped by the silence timer — only key release should end it"
        )
    }

    func testSilenceCountdownDoesNotRunInHoldToTalkEvenWithMaxTimeout() {
        XCTAssertFalse(TranscriptionEngine.shouldRunSilenceCountdown(triggerMode: .holdToTalk, timeout: 15))
    }

    func testSilenceCountdownRunsInToggleModeWithATimeoutConfigured() {
        XCTAssertTrue(
            TranscriptionEngine.shouldRunSilenceCountdown(triggerMode: .toggle, timeout: 5),
            "Toggle mode has no release gesture — the timeout is its intended safety net"
        )
    }

    func testSilenceCountdownDoesNotRunInToggleModeWhenTimeoutIsDisabled() {
        XCTAssertFalse(TranscriptionEngine.shouldRunSilenceCountdown(triggerMode: .toggle, timeout: 0))
    }

    func testSilenceCountdownDoesNotRunInHoldToTalkWhenTimeoutIsAlsoDisabled() {
        XCTAssertFalse(TranscriptionEngine.shouldRunSilenceCountdown(triggerMode: .holdToTalk, timeout: 0))
    }
}
