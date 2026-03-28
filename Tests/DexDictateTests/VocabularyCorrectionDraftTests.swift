import XCTest
@testable import DexDictateKit

final class VocabularyCorrectionDraftTests: XCTestCase {
    func testDraftRequiresBothFields() {
        XCTAssertFalse(VocabularyCorrectionDraft().isValid)
        XCTAssertFalse(VocabularyCorrectionDraft(incorrectPhrase: "wrong", correctPhrase: "").isValid)
        XCTAssertTrue(VocabularyCorrectionDraft(incorrectPhrase: "wrong", correctPhrase: "right").isValid)
    }
}
