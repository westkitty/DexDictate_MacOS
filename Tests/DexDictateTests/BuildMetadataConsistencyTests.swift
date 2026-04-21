import XCTest

final class BuildMetadataConsistencyTests: XCTestCase {
    private let expectedBundleIdentifier = "com.westkitty.dexdictate.macos"

    func testBuildScriptAndSourceInfoPlistShareCanonicalBundleIdentifier() throws {
        let buildScript = try String(contentsOfFile: "build.sh", encoding: .utf8)
        let sourceInfoPlist = try String(contentsOfFile: "Sources/DexDictate/Info.plist", encoding: .utf8)
        let templateInfoPlist = try String(contentsOfFile: "templates/Info.plist.template", encoding: .utf8)

        XCTAssertTrue(buildScript.contains("BUNDLE_IDENTIFIER=\"\(expectedBundleIdentifier)\""))
        XCTAssertTrue(sourceInfoPlist.contains("<string>\(expectedBundleIdentifier)</string>"))
        XCTAssertTrue(templateInfoPlist.contains("<string>{{BUNDLE_IDENTIFIER}}</string>"))
    }
}
