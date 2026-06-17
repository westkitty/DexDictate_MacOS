import XCTest
@testable import DexDictateKit

final class CrashReporterTests: XCTestCase {
    func testFormatsNameReasonAndStack() {
        let message = CrashReporter.formatMessage(
            name: "NSRangeException",
            reason: "index 5 beyond bounds",
            stack: ["0  frameA", "1  frameB"]
        )
        XCTAssertTrue(message.hasPrefix("UNCAUGHT EXCEPTION: NSRangeException: index 5 beyond bounds"))
        XCTAssertTrue(message.contains("0  frameA"))
        XCTAssertTrue(message.contains("1  frameB"))
    }

    func testHandlesMissingReason() {
        let message = CrashReporter.formatMessage(name: "SomeException", reason: nil, stack: [])
        XCTAssertEqual(message, "UNCAUGHT EXCEPTION: SomeException: (no reason)")
    }

    func testHandlesEmptyReasonString() {
        let message = CrashReporter.formatMessage(name: "X", reason: "", stack: [])
        XCTAssertEqual(message, "UNCAUGHT EXCEPTION: X: (no reason)")
    }

    func testNoStackOmitsTrailingNewline() {
        let message = CrashReporter.formatMessage(name: "X", reason: "y", stack: [])
        XCTAssertFalse(message.contains("\n"))
    }
}
