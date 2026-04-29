import XCTest
@testable import DexDictateKit

final class AppInsertionOverridesManagerTests: XCTestCase {
    private let storageKey = "appInsertionOverrides_v1"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        super.tearDown()
    }

    func testMatchingBundleUsesPerAppOverrideInsteadOfGlobalMode() {
        let manager = AppInsertionOverridesManager()
        manager.overrides = []
        manager.add(
            AppInsertionOverride(
                bundleID: "com.example.zoomchat",
                displayName: "Zoom Chat",
                mode: .clipboardOnly
            )
        )

        let effectiveMode = manager.effectiveMode(for: "com.example.zoomchat")

        XCTAssertEqual(effectiveMode, .clipboardOnly)
    }

    func testOverrideDoesNotLeakToUnrelatedApps() {
        let manager = AppInsertionOverridesManager()
        manager.overrides = []
        manager.add(
            AppInsertionOverride(
                bundleID: "com.example.zoomchat",
                displayName: "Zoom Chat",
                mode: .clipboardOnly
            )
        )

        XCTAssertNil(manager.effectiveMode(for: "com.other.editor"))
    }

    func testUseGlobalOverrideResolvesToNilEffectiveMode() {
        let manager = AppInsertionOverridesManager()
        manager.overrides = []
        manager.add(
            AppInsertionOverride(
                bundleID: "com.example.editor",
                displayName: "Editor",
                mode: .useGlobal
            )
        )

        XCTAssertNil(manager.effectiveMode(for: "com.example.editor"))
    }

    func testAddReplacesExistingEntryForSameBundle() {
        let manager = AppInsertionOverridesManager()
        manager.overrides = []

        manager.add(
            AppInsertionOverride(
                bundleID: "com.example.editor",
                displayName: "Editor",
                mode: .clipboardPaste
            )
        )
        manager.add(
            AppInsertionOverride(
                bundleID: "com.example.editor",
                displayName: "Editor",
                mode: .accessibilityAPI
            )
        )

        XCTAssertEqual(manager.overrides.count, 1)
        XCTAssertEqual(manager.effectiveMode(for: "com.example.editor"), .accessibilityAPI)
    }
}
