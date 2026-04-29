import XCTest
@testable import DexDictateKit

final class DictationExplicitStopPolicyTests: XCTestCase {
    func testSilenceTimeoutDoesNotStopActiveDictation() {
        XCTAssertFalse(
            DictationStopPolicy.shouldStopActivelyDictating(for: .silenceTimeout)
        )
    }

    func testExplicitSignalsStillStopActiveDictation() {
        XCTAssertTrue(
            DictationStopPolicy.shouldStopActivelyDictating(for: .explicitTriggerRelease)
        )
        XCTAssertTrue(
            DictationStopPolicy.shouldStopActivelyDictating(for: .explicitToggleOff)
        )
    }
}
