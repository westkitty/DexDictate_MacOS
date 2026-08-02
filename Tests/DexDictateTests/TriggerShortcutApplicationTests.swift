import CoreGraphics
import XCTest
@testable import DexDictateKit

/// Exercises the *production* trigger-save path — `AppSettings.applyTriggerShortcut(_:)`,
/// which every `ShortcutRecorder` surface calls — rather than the pure checker in isolation.
/// Before this repair, `TriggerShortcutConflictChecker.conflict(for:)` had no production
/// caller at all, so ⌃⌥⌘Z could be saved as the trigger and silently shadow undo.
@MainActor
final class TriggerShortcutApplicationTests: XCTestCase {
    private var settings: AppSettings!
    private var original: AppSettings.UserShortcut!

    override func setUp() {
        super.setUp()
        settings = AppSettings.shared
        original = settings.userShortcut
        settings.userShortcut = .defaultMiddleMouse
    }

    override func tearDown() {
        settings.userShortcut = original
        settings = nil
        original = nil
        super.tearDown()
    }

    func testUndoChordIsRejectedAndNotApplied() {
        let outcome = settings.applyTriggerShortcut(undoChordShortcut(modifiers: undoMask))

        XCTAssertFalse(outcome.didApply)
        XCTAssertEqual(outcome.conflict?.severity, .shadowsUndoLastDictation)
        XCTAssertEqual(
            settings.userShortcut,
            .defaultMiddleMouse,
            "A rejected trigger must leave the stored shortcut untouched"
        )
        if case .rejected = outcome {} else {
            XCTFail("Expected .rejected, got \(outcome)")
        }
    }

    func testModifierSubsetThatWouldShadowUndoIsAlsoRejected() {
        // InputMonitor matches on a modifier subset, so ⌘Z-with-Z-keycode would still be
        // shadowed by the undo chord being handled first.
        let outcome = settings.applyTriggerShortcut(
            undoChordShortcut(modifiers: CGEventFlags.maskCommand.rawValue)
        )

        XCTAssertFalse(outcome.didApply)
        XCTAssertEqual(outcome.conflict?.severity, .shadowsUndoLastDictation)
        XCTAssertEqual(settings.userShortcut, .defaultMiddleMouse)
    }

    func testValidKeyboardShortcutIsApplied() {
        let candidate = AppSettings.UserShortcut(
            keyCode: 0x11, // T
            mouseButton: nil,
            modifiers: CGEventFlags.maskControl.rawValue | CGEventFlags.maskAlternate.rawValue,
            displayString: "Ctrl+Opt+T"
        )

        let outcome = settings.applyTriggerShortcut(candidate)

        XCTAssertEqual(outcome, .applied)
        XCTAssertEqual(settings.userShortcut, candidate)
    }

    func testMouseShortcutRemainsUnaffected() {
        let candidate = AppSettings.UserShortcut(
            keyCode: nil,
            mouseButton: 3,
            modifiers: 0,
            displayString: "Mouse 3"
        )

        let outcome = settings.applyTriggerShortcut(candidate)

        XCTAssertEqual(outcome, .applied)
        XCTAssertEqual(settings.userShortcut, candidate)
    }

    func testAdvisoryConflictIsAppliedButStillSurfaced() {
        // A bare key fires while typing: worth warning about, but not worth refusing —
        // only the undo-shadowing conflict blocks application.
        let candidate = AppSettings.UserShortcut(
            keyCode: 0x0C,
            mouseButton: nil,
            modifiers: 0,
            displayString: "Q"
        )

        let outcome = settings.applyTriggerShortcut(candidate)

        XCTAssertTrue(outcome.didApply)
        XCTAssertEqual(outcome.conflict?.severity, .firesWhileTyping)
        XCTAssertNotNil(outcome.conflict?.message)
        XCTAssertEqual(settings.userShortcut, candidate)
    }

    // MARK: - Helpers

    private var undoMask: UInt64 { InputMonitor.undoDictationModifierMask }

    private func undoChordShortcut(modifiers: UInt64) -> AppSettings.UserShortcut {
        AppSettings.UserShortcut(
            keyCode: UInt16(InputMonitor.undoDictationKeyCode),
            mouseButton: nil,
            modifiers: modifiers,
            displayString: "Ctrl+Opt+Cmd+Z"
        )
    }
}
