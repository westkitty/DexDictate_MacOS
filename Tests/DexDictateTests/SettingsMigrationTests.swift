import XCTest
@testable import DexDictateKit

final class SettingsMigrationTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SettingsMigrationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testMigrationCopiesLegacyHUDSettingAndSetsSchemaVersion() {
        defaults.set(true, forKey: "showVisualHUD")

        SettingsMigrationCoordinator(store: defaults).migrateIfNeeded()

        XCTAssertEqual(defaults.object(forKey: SettingsMigrationCoordinator.schemaVersionKey) as? Int,
                       SettingsMigrationCoordinator.currentSchemaVersion)
        XCTAssertEqual(defaults.object(forKey: "showFloatingHUD") as? Bool, true)
    }

    func testMigrationNormalizesInvalidStoredValues() throws {
        defaults.set("Bad Theme", forKey: "appearanceTheme_stored")
        defaults.set("Bad Engine", forKey: "selectedEngine")
        defaults.set(Data("not-json".utf8), forKey: "userShortcutData")

        SettingsMigrationCoordinator(store: defaults).migrateIfNeeded()

        XCTAssertEqual(defaults.string(forKey: "appearanceTheme_stored"), AppSettings.AppearanceTheme.system.rawValue)
        XCTAssertEqual(defaults.string(forKey: "selectedEngine"), AppSettings.TranscriptionEngineType.whisper.rawValue)

        let shortcutData = try XCTUnwrap(defaults.data(forKey: "userShortcutData"))
        let decoded = try JSONDecoder().decode(AppSettings.UserShortcut.self, from: shortcutData)
        XCTAssertEqual(decoded, .defaultMiddleMouse)
    }
}
