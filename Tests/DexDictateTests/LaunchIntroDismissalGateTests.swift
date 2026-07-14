import XCTest
@testable import DexDictateKit

/// Regression coverage for the launch-intro popup that could get stuck on screen as a small
/// residual badge: `LaunchIntroController` (in the `DexDictate` executable target) had its
/// panel teardown driven by several independent callers — the exit fade's completion handler,
/// a fallback timer, a hard-deadline timer, and app shutdown — plus whatever stale callback
/// might fire after one of those already tore the panel down. `LaunchIntroDismissalGate` is the
/// single idempotency guarantee behind all of them: exactly one caller performs real work, and
/// every other caller (including anything stale) safely no-ops.
///
/// Tests the gate's pure logic only — it never constructs a real `NSPanel`/`AVPlayer`, matching
/// `FloatingHUDVisibilityTests`'s reasoning for keeping this suite free of real AppKit windows
/// in a headless test run.
final class LaunchIntroDismissalGateTests: XCTestCase {

    func testFirstCallerWinsAndFires() {
        let gate = LaunchIntroDismissalGate()
        XCTAssertTrue(gate.fireOnce(), "the first caller must be told to perform teardown")
    }

    /// Models the fade-completion handler and the hard-deadline timer both racing to tear the
    /// panel down: whichever calls first does the work, the other (a stale callback relative to
    /// the first) must be a no-op.
    func testSecondCallerIsANoOp() {
        let gate = LaunchIntroDismissalGate()
        XCTAssertTrue(gate.fireOnce())
        XCTAssertFalse(gate.fireOnce(), "a second caller (e.g. a stale callback) must not re-fire teardown")
        XCTAssertFalse(gate.fireOnce(), "repeated calls after the first must stay harmless")
    }

    func testHasFiredAlreadyReflectsState() {
        let gate = LaunchIntroDismissalGate()
        XCTAssertFalse(gate.hasFiredAlready)
        gate.fireOnce()
        XCTAssertTrue(gate.hasFiredAlready)
    }

    /// A later app launch reusing the same controller instance must be able to arm the gate
    /// again rather than being permanently latched from a previous run.
    func testResetRearmsForANewIntroRun() {
        let gate = LaunchIntroDismissalGate()
        XCTAssertTrue(gate.fireOnce())
        XCTAssertTrue(gate.hasFiredAlready)

        gate.reset()
        XCTAssertFalse(gate.hasFiredAlready, "reset() must clear the fired state")
        XCTAssertTrue(gate.fireOnce(), "a fresh run must be able to fire teardown again")
    }

    func testEachInstanceTracksItsOwnState() {
        let first = LaunchIntroDismissalGate()
        let second = LaunchIntroDismissalGate()

        XCTAssertTrue(first.fireOnce())
        XCTAssertTrue(second.fireOnce(), "a separate gate instance must not be affected by another's state")
    }
}
