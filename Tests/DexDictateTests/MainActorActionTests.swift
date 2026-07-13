import XCTest
@testable import DexDictateKit

@MainActor
final class MainActorActionTests: XCTestCase {
    func testRunSyncExecutesAsynchronouslyOnMainActor() async {
        var events: [String] = []

        MainActorAction.run {
            XCTAssertTrue(Thread.isMainThread)
            events.append("action")
        }

        events.append("after")
        XCTAssertEqual(events, ["after"])

        await Task.yield()
        XCTAssertEqual(events, ["after", "action"])
    }

    /// Regression coverage: this used to poll `events` via a bounded `Task.yield()` loop,
    /// assuming each yield would let the action's unstructured `Task` (spawned inside
    /// `MainActorAction.run`'s async overload) advance by exactly one phase. That assumption
    /// is not part of Swift Concurrency's contract — `Task.yield()` only offers the executor
    /// a scheduling opportunity, it does not bound how much of another ready task's work
    /// completes before control returns. Under executor contention (verified by a stress
    /// harness running this same body under 8 competing yield-looping tasks), the action's
    /// task could run through *both* of its phases — including its own internal
    /// `await Task.yield()` — before the test's first polling loop ever observed the
    /// intermediate "action-start" state, intermittently failing the first assertion below
    /// with `events` already containing "action-end" too (~1/8 full-suite runs empirically).
    ///
    /// Fixed with a two-way handshake instead of a poll: the action signals each checkpoint
    /// via an `XCTestExpectation` (same idiom as `MainActorDispatchTests`, with the same
    /// `timeout:` safety net) and then *blocks* on `proceedStream` until the test explicitly
    /// acknowledges the intermediate checkpoint. This makes "the action cannot have reached
    /// action-end yet" a structural guarantee rather than a scheduling guess: the action
    /// literally cannot proceed past `startExpectation.fulfill()` until
    /// `proceedContinuation.yield(())` below runs, which only happens after the intermediate
    /// assertion has already passed.
    func testRunAsyncExecutesOnMainActor() async {
        var events: [String] = []
        let startExpectation = expectation(description: "action reached the intermediate checkpoint")
        let endExpectation = expectation(description: "action finished")
        let (proceedStream, proceedContinuation) = AsyncStream<Void>.makeStream()

        MainActorAction.run {
            XCTAssertTrue(Thread.isMainThread)
            events.append("action-start")
            startExpectation.fulfill()

            var proceedIterator = proceedStream.makeAsyncIterator()
            _ = await proceedIterator.next()

            events.append("action-end")
            endExpectation.fulfill()
        }

        events.append("after")
        XCTAssertEqual(events, ["after"])

        await fulfillment(of: [startExpectation], timeout: 1.0)
        XCTAssertEqual(events, ["after", "action-start"])

        proceedContinuation.yield(())
        proceedContinuation.finish()

        await fulfillment(of: [endExpectation], timeout: 1.0)
        XCTAssertEqual(events, ["after", "action-start", "action-end"])
    }
}
