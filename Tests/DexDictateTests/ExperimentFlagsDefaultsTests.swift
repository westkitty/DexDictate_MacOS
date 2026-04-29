import XCTest
@testable import DexDictateKit

final class ExperimentFlagsDefaultsTests: XCTestCase {
    func testTrimDefaultsKeepLeadingTrimOffAndTrailingTrimOn() {
        XCTAssertFalse(ExperimentFlags.enableSilenceTrim)
        XCTAssertTrue(ExperimentFlags.enableTrailingTrim)
    }
}
