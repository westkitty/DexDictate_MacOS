import CoreGraphics
import XCTest
@testable import DexDictateKit

final class TriggerShortcutConflictCheckerTests: XCTestCase {
    private let cmd = CGEventFlags.maskCommand.rawValue
    private let shift = CGEventFlags.maskShift.rawValue
    private let control = CGEventFlags.maskControl.rawValue
    private let option = CGEventFlags.maskAlternate.rawValue

    private func keyShortcut(_ keyCode: UInt16, _ modifiers: UInt64) -> AppSettings.UserShortcut {
        AppSettings.UserShortcut(keyCode: keyCode, mouseButton: nil, modifiers: modifiers, displayString: "test")
    }

    func testMouseTriggerNeverConflicts() {
        let mouse = AppSettings.UserShortcut(keyCode: nil, mouseButton: 2, modifiers: 0, displayString: "Middle Mouse")
        XCTAssertNil(TriggerShortcutConflictChecker.conflict(for: mouse))
    }

    func testSpotlightIsSystemReserved() {
        let conflict = TriggerShortcutConflictChecker.conflict(for: keyShortcut(0x31, cmd))
        XCTAssertEqual(conflict?.severity, .systemReserved)
        XCTAssertTrue(conflict?.message.contains("Spotlight") ?? false)
    }

    func testScreenshotComboIsSystemReserved() {
        // Cmd+Shift+4
        let conflict = TriggerShortcutConflictChecker.conflict(for: keyShortcut(0x15, cmd | shift))
        XCTAssertEqual(conflict?.severity, .systemReserved)
    }

    func testForceQuitComboIsSystemReserved() {
        // Cmd+Option+Esc
        let conflict = TriggerShortcutConflictChecker.conflict(for: keyShortcut(0x35, cmd | option))
        XCTAssertEqual(conflict?.severity, .systemReserved)
    }

    func testBareKeyFiresWhileTyping() {
        // "Q" with no modifiers
        let conflict = TriggerShortcutConflictChecker.conflict(for: keyShortcut(0x0C, 0))
        XCTAssertEqual(conflict?.severity, .firesWhileTyping)
    }

    func testNonStandardBitsIgnoredWhenMatchingSystemShortcut() {
        // Spotlight (Cmd+Space) plus stray non-standard flag bits (e.g. caps lock / device bits)
        // must still be detected as the system shortcut.
        let noise: UInt64 = CGEventFlags.maskAlphaShift.rawValue | CGEventFlags.maskNonCoalesced.rawValue
        let conflict = TriggerShortcutConflictChecker.conflict(for: keyShortcut(0x31, cmd | noise))
        XCTAssertEqual(conflict?.severity, .systemReserved)
    }

    func testSafeShortcutHasNoConflict() {
        // Cmd+Option+D — not in the reserved table, has modifiers -> safe.
        let conflict = TriggerShortcutConflictChecker.conflict(for: keyShortcut(0x02, cmd | option))
        XCTAssertNil(conflict)
    }

    func testPlainCmdLetterNotInTableIsSafe() {
        // Cmd+D (0x02) is an app-level shortcut, not a global system one we reserve -> no conflict.
        let conflict = TriggerShortcutConflictChecker.conflict(for: keyShortcut(0x02, cmd))
        XCTAssertNil(conflict)
    }

    func testUndoChordExactAndSubsetModifierTriggersConflict() {
        let shadowedModifiers = [
            cmd,
            option | cmd,
            control | cmd,
            control | option | cmd
        ]

        for modifiers in shadowedModifiers {
            let conflict = TriggerShortcutConflictChecker.conflict(for: keyShortcut(0x06, modifiers))
            XCTAssertEqual(conflict?.severity, .shadowsUndoLastDictation)
        }
    }

    /// A trigger requiring *more* modifiers than the undo chord is still shadowed:
    /// `UndoShortcutEventPolicy` matches whenever the held flags contain ⌃⌥⌘, so pressing
    /// ⇧⌃⌥⌘Z is handled as undo and the trigger never fires. This previously asserted `nil`,
    /// which let such a trigger save cleanly and then silently never work.
    func testUndoChordShadowsTriggerRequiringAdditionalModifier() {
        let conflict = TriggerShortcutConflictChecker.conflict(
            for: keyShortcut(0x06, control | option | cmd | shift)
        )

        XCTAssertEqual(conflict?.severity, .shadowsUndoLastDictation)
    }

    /// The checker's shadowing predicate must agree with the event policy that actually
    /// consumes the chord, in both directions, for every modifier combination on the Z key.
    func testShadowPredicateAgreesWithEventPolicyForEveryModifierCombination() {
        let flags = [control, option, cmd, shift]

        for mask in 0..<(1 << flags.count) {
            var modifiers: UInt64 = 0
            for (index, flag) in flags.enumerated() where mask & (1 << index) != 0 {
                modifiers |= flag
            }

            // What the live tap does when the user physically presses this trigger.
            let policyConsumesTheTrigger = UndoShortcutEventPolicy.handle(
                input: UndoShortcutEventInput(
                    type: .keyDown,
                    keyCode: InputMonitor.undoDictationKeyCode,
                    modifiers: modifiers,
                    isAutorepeat: false
                ),
                claimEligibility: { false },
                requestUndo: {},
                notifyUnavailable: {}
            ) != .notMatched

            let flagged = TriggerShortcutConflictChecker
                .conflict(for: keyShortcut(0x06, modifiers))?
                .severity == .shadowsUndoLastDictation

            if policyConsumesTheTrigger {
                XCTAssertTrue(
                    flagged,
                    "Trigger modifiers \(modifiers) are consumed by the undo policy but were not flagged"
                )
            }
        }
    }
}
