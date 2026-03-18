import XCTest
@testable import DexDictateKit

final class ResourceBundleTests: XCTestCase {
    func testResourceBundleContainsExpectedFiles() {
        let bundle = Safety.resourceBundle

        XCTAssertNotNil(bundle.url(forResource: "tiny.en", withExtension: "bin"))
        XCTAssertNotNil(bundle.url(forResource: "profanity_list", withExtension: "json"))
        XCTAssertNotNil(bundle.url(forResource: "Assets.xcassets/AppIcon.appiconset/icon", withExtension: "png"))
        XCTAssertNotNil(bundle.url(forResource: "IntroAnimation", withExtension: "mp4"))
        XCTAssertNotNil(bundle.url(forResource: "IntroAnimation_AltPrepared", withExtension: "mp4"))
        XCTAssertNotNil(bundle.url(forResource: "dexdictate-icon-standard-11", withExtension: "png"))
        XCTAssertNotNil(bundle.url(forResource: "dexdictate-icon-canada-05", withExtension: "png"))
        XCTAssertNotNil(bundle.url(forResource: "dexdictate-icon-aussie-02", withExtension: "png"))
    }
}
