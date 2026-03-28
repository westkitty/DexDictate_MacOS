import XCTest
@testable import DexDictateKit

final class ShortcutConflictDetectorTests: XCTestCase {
    func testCmdSpaceConflictsWithSpotlight() {
        let shortcut = AppSettings.UserShortcut(
            keyCode: 49, // Space key
            mouseButton: nil,
            modifiers: CGEventFlags.maskCommand.rawValue,
            displayString: "Cmd+Space"
        )
        let conflicts = ShortcutConflictDetector.conflicts(for: shortcut)
        XCTAssertFalse(conflicts.isEmpty)
        XCTAssertTrue(conflicts[0].description.lowercased().contains("spotlight"))
    }

    func testMouseButtonHasNoBuiltInConflict() {
        let shortcut = AppSettings.UserShortcut(
            keyCode: nil,
            mouseButton: 2, // Middle mouse
            modifiers: 0,
            displayString: "Middle Mouse"
        )
        let conflicts = ShortcutConflictDetector.conflicts(for: shortcut)
        XCTAssertTrue(conflicts.isEmpty)
    }

    func testNoConflictForUnusedCombo() {
        let shortcut = AppSettings.UserShortcut(
            keyCode: 8, // C key
            mouseButton: nil,
            modifiers: CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskControl.rawValue,
            displayString: "Ctrl+Opt+C"
        )
        let conflicts = ShortcutConflictDetector.conflicts(for: shortcut)
        XCTAssertTrue(conflicts.isEmpty)
    }
}
