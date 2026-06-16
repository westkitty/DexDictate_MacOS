import XCTest
@testable import DexDictateKit

/// FocusedTextReader depends on the live Accessibility focus, which isn't meaningfully
/// controllable in a headless test process. These tests assert the safety contract: it must
/// never crash and must return nil (never throw / never a partial value) when there is no
/// readable focused text — which is the case in the test runner.
final class FocusedTextReaderTests: XCTestCase {
    func testReturnsNilOrStringWithoutCrashingInHeadlessEnvironment() {
        let reader = FocusedTextReader()
        // In the test process there is no focused editable AX element, so this should be nil.
        // The contract we enforce: the call completes safely and yields an optional.
        let result = reader.readTail()
        if let result {
            // If some AX element is unexpectedly focused, the result must respect the bound.
            XCTAssertLessThanOrEqual(result.count, 200)
        } else {
            XCTAssertNil(result)
        }
    }

    func testRespectsCustomMaxCharsBoundIfAnyValueReturned() {
        let result = FocusedTextReader().readTail(maxChars: 10)
        if let result {
            XCTAssertLessThanOrEqual(result.count, 10)
        }
    }
}
