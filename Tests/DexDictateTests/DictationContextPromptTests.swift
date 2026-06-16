import XCTest
@testable import DexDictateKit

final class DictationContextPromptTests: XCTestCase {
    func testBothNilReturnsNil() {
        XCTAssertNil(DictationContextPrompt.combine(domainBias: nil, focusedContext: nil))
    }

    func testEmptyAndWhitespaceTreatedAsNil() {
        XCTAssertNil(DictationContextPrompt.combine(domainBias: "", focusedContext: "   \n"))
    }

    func testDomainBiasOnly() {
        XCTAssertEqual(
            DictationContextPrompt.combine(domainBias: "Xcode SwiftUI", focusedContext: nil),
            "Xcode SwiftUI"
        )
    }

    func testFocusedContextOnly() {
        XCTAssertEqual(
            DictationContextPrompt.combine(domainBias: nil, focusedContext: "Dear Dr. Okafor,"),
            "Dear Dr. Okafor,"
        )
    }

    func testCombinesDomainThenContext() {
        XCTAssertEqual(
            DictationContextPrompt.combine(domainBias: "SwiftUI", focusedContext: "The meeting with"),
            "SwiftUI The meeting with"
        )
    }

    func testTrimsWhitespaceOnEachPart() {
        XCTAssertEqual(
            DictationContextPrompt.combine(domainBias: "  SwiftUI ", focusedContext: " hello "),
            "SwiftUI hello"
        )
    }

    func testBoundsToMaxCharsKeepingTail() {
        // The most recent context (the tail) must survive truncation.
        let bias = String(repeating: "A", count: 300)
        let context = "RECENT_TAIL"
        let result = DictationContextPrompt.combine(domainBias: bias, focusedContext: context, maxChars: 20)
        XCTAssertEqual(result?.count, 20)
        XCTAssertTrue(result?.hasSuffix("RECENT_TAIL") ?? false, "Tail (recent context) must be preserved")
    }

    func testZeroMaxCharsReturnsNil() {
        XCTAssertNil(DictationContextPrompt.combine(domainBias: "x", focusedContext: "y", maxChars: 0))
    }
}
