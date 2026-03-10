import XCTest
@testable import DexDictateKit

final class SafeModePresetTests: XCTestCase {
    func testSafeModePresetAppliesLowerRiskDefaults() {
        var preferences = SafeModePreferences(
            triggerModeRawValue: AppSettings.TriggerMode.toggle.rawValue,
            autoPaste: true,
            playStartSound: true,
            playStopSound: true,
            selectedStartSoundRawValue: AppSettings.SystemSound.glass.rawValue,
            selectedStopSoundRawValue: AppSettings.SystemSound.bottle.rawValue
        )

        preferences.applySafeMode()

        XCTAssertEqual(preferences.triggerMode, .holdToTalk)
        XCTAssertFalse(preferences.autoPaste)
        XCTAssertFalse(preferences.playStartSound)
        XCTAssertFalse(preferences.playStopSound)
        XCTAssertEqual(preferences.selectedStartSound, .none)
        XCTAssertEqual(preferences.selectedStopSound, .none)
    }
}
