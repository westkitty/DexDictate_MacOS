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
        settings.menuBarDisplayMode = .customIcon
        settings.localizationMode = .aussie
        settings.adaptiveTailDelayEnabled = false
        settings.autoRetrySuspiciousResults = false
        settings.dictationDomainMode = .coding
        settings.showFlavorTicker = false
        settings.animateFlavorTicker = false
        settings.selectedMenuBarIconIdentifier = "Gemini_Generated_Image_9999b99999b99999.png"
        settings.selectedMenuBarEmoji = "🔥"

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
        XCTAssertEqual(settings.menuBarDisplayMode, .micAndText)
        XCTAssertEqual(settings.localizationMode, .standard)
        XCTAssertTrue(settings.adaptiveTailDelayEnabled)
        XCTAssertTrue(settings.autoRetrySuspiciousResults)
        XCTAssertEqual(settings.dictationDomainMode, .automatic)
        XCTAssertTrue(settings.showFlavorTicker)
        XCTAssertTrue(settings.animateFlavorTicker)
        XCTAssertTrue(settings.enableTrailingTrimExperiment)
        XCTAssertFalse(settings.enableSilenceTrim)
        XCTAssertEqual(settings.selectedMenuBarIconIdentifier, "")
        XCTAssertEqual(settings.selectedMenuBarEmoji, "🐶")
        XCTAssertEqual(settings.userShortcut, .defaultMiddleMouse)
    }

    /// Regression coverage for the Restore Defaults confirmation gate shared by Settings →
    /// General's button and the classic popover footer's link (`RestoreDefaultsPrompt` in the
    /// `DexDictate` app target). The gate itself lives in `DexDictateKit` so it can be
    /// exercised here with an injected confirm closure instead of a real `NSAlert`.
    func testDecliningConfirmationDoesNotReset() {
        let settings = AppSettings()
        settings.triggerMode = .toggle
        settings.inputDeviceUID = "external-mic"

        let didReset = settings.restoreDefaults { false }

        XCTAssertFalse(didReset)
        XCTAssertEqual(settings.triggerMode, .toggle)
        XCTAssertEqual(settings.inputDeviceUID, "external-mic")
    }

    func testConfirmingResetsExactlyOnce() {
        let settings = AppSettings()
        settings.triggerMode = .toggle
        settings.inputDeviceUID = "external-mic"

        let didReset = settings.restoreDefaults { true }

        XCTAssertTrue(didReset)
        XCTAssertEqual(settings.triggerMode, .holdToTalk)
        XCTAssertEqual(settings.inputDeviceUID, "")
    }

    /// Merely presenting the confirmation (calling `confirm`) must never itself perform a
    /// reset — only a `true` return value may. This is what distinguishes "opening the
    /// dialog" from "confirming" at the architecture level: the gate reads the closure's
    /// return value rather than reacting to the closure being invoked.
    func testConfirmationCallbackAloneDoesNotResetBeforeReturning() {
        let settings = AppSettings()
        settings.triggerMode = .toggle

        var triggerModeDuringPrompt: AppSettings.TriggerMode?
        _ = settings.restoreDefaults {
            triggerModeDuringPrompt = settings.triggerMode
            return false
        }

        XCTAssertEqual(triggerModeDuringPrompt, .toggle, "Settings must be untouched while the confirmation is still being decided")
    }

    /// The gate calls `confirm()` exactly once per invocation — guards against a future
    /// refactor accidentally re-entering the prompt or resetting twice for one user action.
    func testConfirmClosureIsInvokedExactlyOnce() {
        let settings = AppSettings()
        var confirmCallCount = 0

        _ = settings.restoreDefaults {
            confirmCallCount += 1
            return true
        }

        XCTAssertEqual(confirmCallCount, 1)
    }
}
