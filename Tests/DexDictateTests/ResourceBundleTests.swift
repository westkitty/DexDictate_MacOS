import XCTest
@testable import DexDictateKit

final class ResourceBundleTests: XCTestCase {
    func testResourceBundleContainsExpectedFiles() {
        let bundle = Safety.resourceBundle

        XCTAssertNotNil(bundle.url(forResource: "tiny.en", withExtension: "bin"))
        XCTAssertNotNil(bundle.url(forResource: "profanity_list", withExtension: "json"))
        XCTAssertNotNil(bundle.url(forResource: "Assets.xcassets/AppIcon.appiconset/icon", withExtension: "png"))
    }
}
