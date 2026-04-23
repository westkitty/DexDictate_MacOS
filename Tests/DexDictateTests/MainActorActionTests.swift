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

    func testRunAsyncExecutesOnMainActor() async {
        var events: [String] = []

        MainActorAction.run {
            XCTAssertTrue(Thread.isMainThread)
            events.append("action-start")
            await Task.yield()
            events.append("action-end")
        }

        events.append("after")
        XCTAssertEqual(events, ["after"])

        await Task.yield()
        XCTAssertEqual(events, ["after", "action-start"])

        for _ in 0..<5 where events.count < 3 {
            await Task.yield()
        }
        XCTAssertEqual(events, ["after", "action-start", "action-end"])
    }
}
