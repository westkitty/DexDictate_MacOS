import XCTest

final class BuildMetadataConsistencyTests: XCTestCase {
    private let expectedBundleIdentifier = "com.westkitty.dexdictate.macos"
    private let sourceInfoPath = "Sources/DexDictate/Info.plist"
    private let templateInfoPath = "templates/Info.plist.template"

    func testBuildScriptAndSourceInfoPlistShareCanonicalBundleIdentifier() throws {
        // build.sh is a shell script, not a plist — this one check stays string-based.
        let buildScript = try String(contentsOfFile: "build.sh", encoding: .utf8)
        XCTAssertTrue(buildScript.contains("BUNDLE_IDENTIFIER=\"\(expectedBundleIdentifier)\""))

        let source = try plistDictionary(atPath: sourceInfoPath)
        XCTAssertEqual(source["CFBundleIdentifier"] as? String, expectedBundleIdentifier)

        let template = try plistDictionary(atPath: templateInfoPath)
        XCTAssertEqual(
            template["CFBundleIdentifier"] as? String, "{{BUNDLE_IDENTIFIER}}",
            "Template must keep the placeholder, never a hardcoded identifier"
        )
    }

    func testSourceAndTemplatePlistsStayAlignedOnMetadataAndPermissionKeys() throws {
        let source = try plistDictionary(atPath: sourceInfoPath)
        let template = try plistDictionary(atPath: templateInfoPath)

        assertEqual(source, template, key: "CFBundlePackageType")
        assertEqual(source, template, key: "LSUIElement")
        assertEqual(source, template, key: "LSMinimumSystemVersion")
        assertEqual(source, template, key: "NSMicrophoneUsageDescription")
        assertEqual(source, template, key: "NSAccessibilityUsageDescription")
        assertEqual(source, template, key: "NSSpeechRecognitionUsageDescription")
        assertEqual(source, template, key: "NSAppleEventsUsageDescription")

        // Keys DexDictate has no use for (no document types, no custom URL scheme, no
        // Sparkle-style auto-update feed, no App Store category) — forbidden in both plists
        // so a copy-pasted boilerplate key doesn't silently reappear.
        for forbiddenKey in [
            "CFBundleDisplayName", "LSApplicationCategoryType",
            "CFBundleDocumentTypes", "CFBundleURLTypes", "SUFeedURL"
        ] {
            XCTAssertNil(source[forbiddenKey], "Unexpected key '\(forbiddenKey)' in \(sourceInfoPath)")
            XCTAssertNil(template[forbiddenKey], "Unexpected key '\(forbiddenKey)' in \(templateInfoPath)")
        }
    }

    /// `CFBundleDevelopmentRegion` and `NSHighResolutionCapable` have been present in
    /// `Sources/DexDictate/Info.plist` since the project's first commit (Xcode's default
    /// macOS-app boilerplate) but were never carried into `templates/Info.plist.template` —
    /// the file `assemble_bundle()` in build.sh actually turns into the shipped bundle's
    /// Info.plist. This is deliberate, not drift:
    ///  - `CFBundleDevelopmentRegion` only affects which `.lproj` directory macOS falls back to
    ///    for localized resources. DexDictate ships zero `.lproj` directories (English-only, not
    ///    localized), so the key has nothing to affect either way.
    ///  - `NSHighResolutionCapable` only mattered during the pre-Retina transition (OS X
    ///    10.6-10.8); every OS DexDictate can run on (`LSMinimumSystemVersion` 14.0) treats every
    ///    app as Retina-capable regardless of this key's presence.
    /// Pinning this down here means a future contributor sees a passing, documented test instead
    /// of independently re-deriving "is this gap safe to leave alone?" from scratch — and if
    /// localization resources are ever added, the `.lproj` assertion below fails first and forces
    /// that decision to be revisited.
    func testLegacySourceOnlyKeysAreDeliberatelyAbsentFromTemplate() throws {
        let source = try plistDictionary(atPath: sourceInfoPath)
        let template = try plistDictionary(atPath: templateInfoPath)

        XCTAssertEqual(source["CFBundleDevelopmentRegion"] as? String, "en")
        XCTAssertNil(template["CFBundleDevelopmentRegion"])

        XCTAssertEqual(source["NSHighResolutionCapable"] as? Bool, true)
        XCTAssertNil(template["NSHighResolutionCapable"])

        XCTAssertFalse(repoContainsAnyLprojDirectory(), "CFBundleDevelopmentRegion's absence from the template stops being harmless once localization resources exist — revisit this test if this starts failing")
    }

    /// Replicates build.sh's exact `assemble_bundle()` substitution
    /// (`sed -e "s/{{X}}/$X/g" ... "$INFO_TEMPLATE" > "$BUNDLE/Contents/Info.plist"`) in pure
    /// Swift against the real template file, then parses the result exactly as `plutil`/
    /// `PropertyListSerialization` would on the actual shipped bundle. This is the closest
    /// hermetic proxy for "what does the installed app's Info.plist actually contain" without
    /// depending on a real `./build.sh` run or an installed `/Applications/DexDictate.app`.
    func testTemplateProducesCorrectPlistAfterBuildSubstitution() throws {
        let template = try String(contentsOfFile: templateInfoPath, encoding: .utf8)
        let version = try String(contentsOfFile: "VERSION", encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(version.isEmpty, "VERSION file is empty")

        let resolved = template
            .replacingOccurrences(of: "{{APP_NAME}}", with: "DexDictate")
            .replacingOccurrences(of: "{{EXECUTABLE_NAME}}", with: "DexDictate")
            .replacingOccurrences(of: "{{BUNDLE_IDENTIFIER}}", with: expectedBundleIdentifier)
            .replacingOccurrences(of: "{{VERSION}}", with: version)

        XCTAssertFalse(resolved.contains("{{"), "Resolved plist must not contain any unsubstituted placeholder")

        guard let data = resolved.data(using: .utf8),
              let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return XCTFail("Substituted template did not parse as a valid plist")
        }

        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "DexDictate")
        XCTAssertEqual(plist["CFBundleName"] as? String, "DexDictate")
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, expectedBundleIdentifier)
        XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, version)
        XCTAssertEqual(plist["CFBundleVersion"] as? String, version)
        XCTAssertEqual(plist["LSUIElement"] as? Bool, true)
        XCTAssertEqual(plist["LSMinimumSystemVersion"] as? String, "14.0")
        XCTAssertEqual(plist["CFBundleIconFile"] as? String, "AppIcon")
        XCTAssertEqual(
            plist["NSMicrophoneUsageDescription"] as? String,
            "DexDictate needs microphone access to transcribe your speech into text."
        )
        XCTAssertEqual(
            plist["NSAccessibilityUsageDescription"] as? String,
            "DexDictate needs accessibility access to monitor global keyboard/mouse events."
        )
        XCTAssertEqual(
            plist["NSSpeechRecognitionUsageDescription"] as? String,
            "DexDictate uses on-device Speech Recognition for optional live transcription previews. Audio never leaves your Mac."
        )
        XCTAssertEqual(
            plist["NSAppleEventsUsageDescription"] as? String,
            "DexDictate uses Automation access to optionally pause and resume media playback in Chrome, Brave, or Edge tabs while you dictate. Denying access does not affect transcription."
        )

        for forbiddenKey in [
            "CFBundleDevelopmentRegion", "NSHighResolutionCapable", "CFBundleDisplayName",
            "LSApplicationCategoryType", "CFBundleDocumentTypes", "CFBundleURLTypes", "SUFeedURL"
        ] {
            XCTAssertNil(plist[forbiddenKey], "Shipped bundle plist must not contain unexpected key '\(forbiddenKey)'")
        }
    }

    /// Regression coverage for the Apple Events privacy description: BrowserMediaPauseService
    /// (Settings -> Dictation -> "Pause browser media during dictation") genuinely sends Apple
    /// Events to Chrome/Brave/Edge via `osascript`/`tell application id "..."`, so macOS requires
    /// this key to show a proper (rather than generic) Automation permission prompt.
    func testAppleEventsUsageDescriptionExplainsOptionalBrowserPauseFeature() throws {
        let source = try plistDictionary(atPath: sourceInfoPath)
        let template = try plistDictionary(atPath: templateInfoPath)

        let expected = "DexDictate uses Automation access to optionally pause and resume media playback in Chrome, Brave, or Edge tabs while you dictate. Denying access does not affect transcription."

        XCTAssertEqual(source["NSAppleEventsUsageDescription"] as? String, expected)
        XCTAssertEqual(template["NSAppleEventsUsageDescription"] as? String, expected)
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

    /// Repo root, derived from this file's location: Tests/DexDictateTests/<file> -> repo root.
    /// Mirrors the same derivation VersionConsistencyTests.swift already uses.
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // DexDictateTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
    }

    private func repoContainsAnyLprojDirectory() -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: repoRoot, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return false }

        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if name == ".build" || name == ".git" {
                enumerator.skipDescendants()
                continue
            }
            if name.hasSuffix(".lproj") { return true }
        }
        return false
    }
}
