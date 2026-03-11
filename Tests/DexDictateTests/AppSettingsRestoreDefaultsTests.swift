import XCTest
@testable import DexDictateKit

final class AppSettingsRestoreDefaultsTests: XCTestCase {
    func testRestoreDefaultsMatchesDeclaredFactoryState() {
        let settings = AppSettings()

        settings.triggerMode = .toggle
        settings.inputDeviceUID = "external-mic"
        settings.playStartSound = true
        settings.playStopSound = true
        settings.selectedStartSound = .glass
        settings.selectedStopSound = .bottle
        settings.autoPaste = false
        settings.copyOnlyInSensitiveFields = false
        settings.profanityFilter = true
        settings.safeModeEnabled = true
        settings.launchAtLogin = true
        settings.selectedTheme = .retro
        settings.appearanceTheme = .highContrast
        settings.selectedEngine = .whisper

        settings.restoreDefaults()

        XCTAssertEqual(settings.triggerMode, .holdToTalk)
        XCTAssertEqual(settings.inputDeviceUID, "")
        XCTAssertFalse(settings.playStartSound)
        XCTAssertFalse(settings.playStopSound)
        XCTAssertEqual(settings.selectedStartSound, .none)
        XCTAssertEqual(settings.selectedStopSound, .none)
        XCTAssertTrue(settings.autoPaste)
        XCTAssertTrue(settings.copyOnlyInSensitiveFields)
        XCTAssertFalse(settings.profanityFilter)
        XCTAssertFalse(settings.safeModeEnabled)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertEqual(settings.selectedTheme, .custom)
        XCTAssertEqual(settings.appearanceTheme, .system)
        XCTAssertEqual(settings.appearanceThemeStored, AppSettings.AppearanceTheme.system.rawValue)
        XCTAssertEqual(settings.userShortcut, .defaultMiddleMouse)
    }
}
