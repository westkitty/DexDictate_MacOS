import CoreGraphics
import Foundation

/// A detected problem with a user's chosen trigger shortcut.
public struct TriggerShortcutConflict: Equatable {
    public enum Severity: Equatable {
        /// Collides with a well-known macOS system shortcut; the trigger may never fire
        /// (the system consumes the event first).
        case systemReserved
        /// A keyboard key with no modifiers — it will fire during normal typing.
        case firesWhileTyping
    }

    public let severity: Severity
    public let message: String

    public init(severity: Severity, message: String) {
        self.severity = severity
        self.message = message
    }
}

/// Pure, unit-testable detection of trigger shortcuts that are likely to be "dead" — either
/// because macOS reserves the combination system-wide, or because a bare key would fire while
/// the user is simply typing. Kept free of AppKit/event-tap state so it can run in tests.
///
/// Modifier bits use `CGEventFlags` raw values, matching how `AppSettings.UserShortcut.modifiers`
/// is stored and how `InputMonitor` compares them.
public enum TriggerShortcutConflictChecker {
    // Standard device-independent modifier bits (shared raw values between NSEvent and CGEventFlags).
    private static let standardModifierMask: UInt64 =
        CGEventFlags.maskCommand.rawValue
        | CGEventFlags.maskShift.rawValue
        | CGEventFlags.maskControl.rawValue
        | CGEventFlags.maskAlternate.rawValue

    private struct KnownShortcut {
        let keyCode: UInt16
        let modifiers: UInt64
        let name: String
    }

    // HID/virtual key codes (kVK_*).
    private enum Key {
        static let space: UInt16 = 0x31
        static let tab: UInt16 = 0x30
        static let q: UInt16 = 0x0C
        static let w: UInt16 = 0x0D
        static let h: UInt16 = 0x04
        static let m: UInt16 = 0x2E
        static let three: UInt16 = 0x14
        static let four: UInt16 = 0x15
        static let five: UInt16 = 0x17
        static let escape: UInt16 = 0x35
    }

    private static let cmd = CGEventFlags.maskCommand.rawValue
    private static let shift = CGEventFlags.maskShift.rawValue
    private static let control = CGEventFlags.maskControl.rawValue
    private static let option = CGEventFlags.maskAlternate.rawValue

    private static let knownSystemShortcuts: [KnownShortcut] = [
        KnownShortcut(keyCode: Key.space, modifiers: cmd, name: "Spotlight (⌘Space)"),
        KnownShortcut(keyCode: Key.space, modifiers: control | cmd, name: "Emoji & Symbols (⌃⌘Space)"),
        KnownShortcut(keyCode: Key.tab, modifiers: cmd, name: "App Switcher (⌘Tab)"),
        KnownShortcut(keyCode: Key.q, modifiers: cmd, name: "Quit (⌘Q)"),
        KnownShortcut(keyCode: Key.w, modifiers: cmd, name: "Close Window (⌘W)"),
        KnownShortcut(keyCode: Key.h, modifiers: cmd, name: "Hide (⌘H)"),
        KnownShortcut(keyCode: Key.m, modifiers: cmd, name: "Minimize (⌘M)"),
        KnownShortcut(keyCode: Key.three, modifiers: cmd | shift, name: "Screenshot (⌘⇧3)"),
        KnownShortcut(keyCode: Key.four, modifiers: cmd | shift, name: "Screenshot Region (⌘⇧4)"),
        KnownShortcut(keyCode: Key.five, modifiers: cmd | shift, name: "Screenshot Bar (⌘⇧5)"),
        KnownShortcut(keyCode: Key.escape, modifiers: cmd | option, name: "Force Quit (⌥⌘Esc)"),
    ]

    /// Returns a conflict for the given shortcut, or `nil` if it appears safe to use as a trigger.
    public static func conflict(for shortcut: AppSettings.UserShortcut) -> TriggerShortcutConflict? {
        // Mouse-button triggers do not collide with the keyboard system shortcuts below.
        guard let keyCode = shortcut.keyCode else { return nil }

        let normalized = shortcut.modifiers & standardModifierMask

        if let match = knownSystemShortcuts.first(where: { $0.keyCode == keyCode && $0.modifiers == normalized }) {
            return TriggerShortcutConflict(
                severity: .systemReserved,
                message: "This shortcut is reserved by macOS for \(match.name) and may never reach DexDictate. Choose a different trigger."
            )
        }

        if normalized == 0 {
            return TriggerShortcutConflict(
                severity: .firesWhileTyping,
                message: "A trigger with no modifier keys will fire while you type. Add a modifier (⌘, ⌥, ⌃) or use a mouse button."
            )
        }

        return nil
    }
}
