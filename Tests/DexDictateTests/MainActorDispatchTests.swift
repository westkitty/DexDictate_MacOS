import XCTest
@testable import DexDictateKit

final class MainActorDispatchTests: XCTestCase {
    func testAsyncRunsOnMainThreadAsynchronously() async {
        let expectation = expectation(description: "main actor dispatch")
        let eventLog = EventLog()

        MainActorDispatch.async {
            XCTAssertTrue(Thread.isMainThread)
            eventLog.events.append("action")
            expectation.fulfill()
        }

        eventLog.events.append("after")

        // No assertion here: whether "after" has been appended by the time this line runs is
        // inherently racy to observe synchronously (DispatchQueue.main.async only guarantees
        // the block runs once this scope yields, not that it can never have already fired by
        // the time we get here). The awaited assertion below is what actually proves the
        // dispatch is asynchronous and ordered — if `body()` ran synchronously/out of order,
        // the array would be `["action", "after"]` or lack "after" entirely, failing it.
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(eventLog.events, ["after", "action"])
    }
}

private final class EventLog: @unchecked Sendable {
    var events: [String] = []
}
