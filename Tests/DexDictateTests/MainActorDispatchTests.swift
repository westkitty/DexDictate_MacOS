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
        XCTAssertEqual(eventLog.events, ["after"])

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(eventLog.events, ["after", "action"])
    }
}

private final class EventLog: @unchecked Sendable {
    var events: [String] = []
}
