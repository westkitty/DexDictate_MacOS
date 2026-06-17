import XCTest

/// Guards against the version skew that previously existed between the `VERSION` file
/// (used by build.sh via the template) and the static `Sources/DexDictate/Info.plist`.
/// These must agree, and the template must stay templated (not hardcode a version).
final class VersionConsistencyTests: XCTestCase {
    /// Repo root, derived from this file's location: Tests/DexDictateTests/<file> -> repo root.
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // DexDictateTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
    }

    private func read(_ relativePath: String) throws -> String {
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func plistVersions(_ relativePath: String) throws -> (short: String, bundle: String) {
        let url = repoRoot.appendingPathComponent(relativePath)
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let dict = try XCTUnwrap(plist as? [String: Any], "Info.plist is not a dictionary")
        let short = try XCTUnwrap(dict["CFBundleShortVersionString"] as? String)
        let bundle = try XCTUnwrap(dict["CFBundleVersion"] as? String)
        return (short, bundle)
    }

    func testVersionFileMatchesInfoPlist() throws {
        let version = try read("VERSION").trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(version.isEmpty, "VERSION file is empty")

        let (short, bundle) = try plistVersions("Sources/DexDictate/Info.plist")
        XCTAssertEqual(short, version, "CFBundleShortVersionString must match the VERSION file")
        XCTAssertEqual(bundle, version, "CFBundleVersion must match the VERSION file")
    }

    func testTemplateStaysTemplated() throws {
        // The shipped bundle's version comes from the template + VERSION at build time.
        // The template must use the {{VERSION}} placeholder, never a hardcoded version,
        // so there is exactly one source of truth.
        let template = try read("templates/Info.plist.template")
        XCTAssertTrue(
            template.contains("{{VERSION}}"),
            "templates/Info.plist.template must use the {{VERSION}} placeholder for versioning"
        )
    }

    func testMenuBarAppIsAccessory() throws {
        // DexDictate is a menu-bar app: LSUIElement must be true in both the static plist
        // and the template so no Dock icon appears (regression guard for the duplicate-icon fix).
        let template = try read("templates/Info.plist.template")
        XCTAssertTrue(
            template.contains("<key>LSUIElement</key><true/>"),
            "Template must set LSUIElement=true (menu-bar accessory app)"
        )

        let url = repoRoot.appendingPathComponent("Sources/DexDictate/Info.plist")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let dict = try XCTUnwrap(plist as? [String: Any])
        XCTAssertEqual(dict["LSUIElement"] as? Bool, true, "Info.plist must set LSUIElement=true")
    }
}
