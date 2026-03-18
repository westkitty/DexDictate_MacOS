import Foundation

protocol SettingsStore: AnyObject {
    func object(forKey defaultName: String) -> Any?
    func string(forKey defaultName: String) -> String?
    func data(forKey defaultName: String) -> Data?
    func bool(forKey defaultName: String) -> Bool
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: SettingsStore {}

struct SettingsMigrationCoordinator {
    static let currentSchemaVersion = 2
    static let schemaVersionKey = "settingsSchemaVersion"

    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
    }

    func migrateIfNeeded() {
        let currentVersion = store.object(forKey: Self.schemaVersionKey) as? Int ?? 0
        guard currentVersion < Self.currentSchemaVersion else { return }

        if currentVersion < 1 {
            migrateToVersion1()
        }

        if currentVersion < 2 {
            migrateToVersion2()
        }

        store.set(Self.currentSchemaVersion, forKey: Self.schemaVersionKey)
    }

    private func migrateToVersion1() {
        migrateLegacyHUDVisibility()
        normalizeAppearanceTheme()
        normalizeSelectedEngine()
        normalizeShortcutPayload()
    }

    private func migrateToVersion2() {
        normalizeLocalizationMode()
    }

    private func migrateLegacyHUDVisibility() {
        guard store.object(forKey: "showFloatingHUD") == nil,
              store.object(forKey: "showVisualHUD") != nil else {
            return
        }

        store.set(store.bool(forKey: "showVisualHUD"), forKey: "showFloatingHUD")
    }

    private func normalizeAppearanceTheme() {
        let storedTheme = store.string(forKey: "appearanceTheme_stored")
        guard AppSettings.AppearanceTheme(rawValue: storedTheme ?? "") == nil else {
            return
        }

        store.set(AppSettings.AppearanceTheme.system.rawValue, forKey: "appearanceTheme_stored")
    }

    private func normalizeSelectedEngine() {
        let storedEngine = store.string(forKey: "selectedEngine")
        guard AppSettings.TranscriptionEngineType(rawValue: storedEngine ?? "") == nil else {
            return
        }

        store.set(AppSettings.TranscriptionEngineType.whisper.rawValue, forKey: "selectedEngine")
    }

    private func normalizeShortcutPayload() {
        let current = store.data(forKey: "userShortcutData")
        if let current,
           (try? JSONDecoder().decode(AppSettings.UserShortcut.self, from: current)) != nil {
            return
        }

        let fallback = (try? JSONEncoder().encode(AppSettings.UserShortcut.defaultMiddleMouse)) ?? Data()
        store.set(fallback, forKey: "userShortcutData")
    }

    private func normalizeLocalizationMode() {
        let storedMode = store.string(forKey: "localizationMode_v1")
        guard AppProfile(rawValue: storedMode ?? "") == nil else {
            return
        }

        store.set(AppProfile.standard.rawValue, forKey: "localizationMode_v1")
    }
}
