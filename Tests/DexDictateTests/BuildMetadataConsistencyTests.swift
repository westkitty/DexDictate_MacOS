import XCTest

final class BuildMetadataConsistencyTests: XCTestCase {
    private let expectedBundleIdentifier = "com.westkitty.dexdictate.macos"
    private let sourceInfoPath = "Sources/DexDictate/Info.plist"
    private let templateInfoPath = "templates/Info.plist.template"

    func testBuildScriptAndSourceInfoPlistShareCanonicalBundleIdentifier() throws {
        let buildScript = try String(contentsOfFile: "build.sh", encoding: .utf8)
        let sourceInfoPlist = try String(contentsOfFile: sourceInfoPath, encoding: .utf8)
        let templateInfoPlist = try String(contentsOfFile: templateInfoPath, encoding: .utf8)

        XCTAssertTrue(buildScript.contains("BUNDLE_IDENTIFIER=\"\(expectedBundleIdentifier)\""))
        XCTAssertTrue(sourceInfoPlist.contains("<string>\(expectedBundleIdentifier)</string>"))
        XCTAssertTrue(templateInfoPlist.contains("<string>{{BUNDLE_IDENTIFIER}}</string>"))
    }

    func testSourceAndTemplatePlistsStayAlignedOnMetadataAndPermissionKeys() throws {
        let source = try plistDictionary(atPath: sourceInfoPath)
        let template = try plistDictionary(atPath: templateInfoPath)

        assertEqual(source, template, key: "CFBundlePackageType")
        assertEqual(source, template, key: "LSUIElement")
        assertEqual(source, template, key: "LSMinimumSystemVersion")
        assertEqual(source, template, key: "NSMicrophoneUsageDescription")
        assertEqual(source, template, key: "NSAccessibilityUsageDescription")

        XCTAssertNil(source["NSAppleEventsUsageDescription"])
        XCTAssertNil(template["NSAppleEventsUsageDescription"])
        XCTAssertNil(source["NSSpeechRecognitionUsageDescription"])
        XCTAssertNil(template["NSSpeechRecognitionUsageDescription"])

        XCTAssertNil(source["CFBundleDisplayName"])
        XCTAssertNil(template["CFBundleDisplayName"])
        XCTAssertNil(source["LSApplicationCategoryType"])
        XCTAssertNil(template["LSApplicationCategoryType"])
    }

    private func plistDictionary(atPath path: String) throws -> [String: Any] {
        guard let dictionary = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            XCTFail("Unable to load plist dictionary at path: \(path)")
            return [:]
        }
        return dictionary
    }

    private func assertEqual(_ lhs: [String: Any], _ rhs: [String: Any], key: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs[key] as? NSObject, rhs[key] as? NSObject, "Mismatch for key \(key)", file: file, line: line)
    }
}
