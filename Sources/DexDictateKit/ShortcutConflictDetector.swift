// Sources/DexDictateKit/ShortcutConflictDetector.swift
import Foundation
import CoreGraphics
import AppKit

public struct ShortcutConflict {
    public let description: String
    public let source: ConflictSource

    public enum ConflictSource {
        case systemPreference
        case wellKnown
    }

    public init(description: String, source: ConflictSource) {
        self.description = description
        self.source = source
    }
}

public struct ShortcutConflictDetector {

    // Well-known macOS system shortcuts
    // Key codes: Space=49, Tab=48, H=4, M=46, W=13, Q=12, A=0, Z=6, C=8, V=9, X=7, Grave=50
    private static let wellKnown: [(keyCode: UInt16, modifiers: UInt64, description: String)] = [
        (49, CGEventFlags.maskCommand.rawValue,                                                   "Spotlight Search (Cmd+Space)"),
        (49, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue,                 "Show Character Viewer (Cmd+Shift+Space)"),
        (48, CGEventFlags.maskCommand.rawValue,                                                   "App Switcher (Cmd+Tab)"),
        (4,  CGEventFlags.maskCommand.rawValue,                                                   "Hide Application (Cmd+H)"),
        (4,  CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue,             "Hide Others (Cmd+Opt+H)"),
        (46, CGEventFlags.maskCommand.rawValue,                                                   "Minimise Window (Cmd+M)"),
        (13, CGEventFlags.maskCommand.rawValue,                                                   "Close Window (Cmd+W)"),
        (12, CGEventFlags.maskCommand.rawValue,                                                   "Quit Application (Cmd+Q)"),
        (0,  CGEventFlags.maskCommand.rawValue,                                                   "Select All (Cmd+A)"),
        (6,  CGEventFlags.maskCommand.rawValue,                                                   "Undo (Cmd+Z)"),
        (6,  CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue,                 "Redo (Cmd+Shift+Z)"),
        (8,  CGEventFlags.maskCommand.rawValue,                                                   "Copy (Cmd+C)"),
        (9,  CGEventFlags.maskCommand.rawValue,                                                   "Paste (Cmd+V)"),
        (7,  CGEventFlags.maskCommand.rawValue,                                                   "Cut (Cmd+X)"),
        (50, CGEventFlags.maskCommand.rawValue,                                                   "Show/Hide Menu Bar (Cmd+`)"),
        (20, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue,                 "Screenshot (Cmd+Shift+3)"),
        (21, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue,                 "Screenshot Selection (Cmd+Shift+4)"),
        (23, CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue,                 "Screenshot Tools (Cmd+Shift+5)"),
        (49, CGEventFlags.maskControl.rawValue,                                                   "Switch Input Source (Ctrl+Space)"),
        (49, CGEventFlags.maskControl.rawValue | CGEventFlags.maskCommand.rawValue,               "Show Character Viewer (Ctrl+Cmd+Space)"),
    ]

    /// Returns all detected conflicts for the given shortcut.
    public static func conflicts(for shortcut: AppSettings.UserShortcut) -> [ShortcutConflict] {
        guard let keyCode = shortcut.keyCode else {
            return [] // Mouse buttons don't conflict with system keyboard shortcuts
        }

        var results: [ShortcutConflict] = []

        // 1. Check well-known list
        for known in wellKnown {
            if known.keyCode == keyCode && modifiersMatch(known.modifiers, shortcut.modifiers) {
                results.append(ShortcutConflict(description: known.description, source: .wellKnown))
            }
        }

        // 2. Check system preferences plist (best-effort, returns [] on any error)
        results += systemPlistConflicts(keyCode: keyCode, modifiers: shortcut.modifiers)

        return results
    }

    private static func modifiersMatch(_ a: UInt64, _ b: UInt64) -> Bool {
        let mask: UInt64 = CGEventFlags.maskCommand.rawValue
                         | CGEventFlags.maskShift.rawValue
                         | CGEventFlags.maskAlternate.rawValue
                         | CGEventFlags.maskControl.rawValue
        return (a & mask) == (b & mask)
    }

    private static func systemPlistConflicts(keyCode: UInt16, modifiers: UInt64) -> [ShortcutConflict] {
        let plistURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Preferences/com.apple.symbolichotkeys.plist")

        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let hotkeys = plist["AppleSymbolicHotKeys"] as? [String: Any] else {
            return []
        }

        var results: [ShortcutConflict] = []

        for (hotkeyID, value) in hotkeys {
            guard let entry = value as? [String: Any],
                  let enabled = entry["enabled"] as? Bool, enabled,
                  let valueDict = entry["value"] as? [String: Any],
                  let params = valueDict["parameters"] as? [Any],
                  params.count >= 3,
                  let plistKeyCode = params[1] as? Int,
                  let plistModifiers = params[2] as? Int,
                  UInt16(plistKeyCode) == keyCode else { continue }

            let cgMods = nsModifiersToCGFlags(UInt(plistModifiers))
            if modifiersMatch(cgMods, modifiers) {
                let description = systemHotkeyName(for: hotkeyID) ?? "System Shortcut #\(hotkeyID)"
                results.append(ShortcutConflict(description: description, source: .systemPreference))
            }
        }

        return results
    }

    private static func nsModifiersToCGFlags(_ ns: UInt) -> UInt64 {
        var cg: UInt64 = 0
        if ns & 256     != 0 { cg |= CGEventFlags.maskShift.rawValue }
        if ns & 512     != 0 { cg |= CGEventFlags.maskControl.rawValue }
        if ns & 524288  != 0 { cg |= CGEventFlags.maskAlternate.rawValue }
        if ns & 1048576 != 0 { cg |= CGEventFlags.maskCommand.rawValue }
        return cg
    }

    private static func systemHotkeyName(for id: String) -> String? {
        let names: [String: String] = [
            "64": "Spotlight Search",
            "65": "Spotlight Window",
            "32": "All Windows (Mission Control)",
            "33": "Application Windows",
            "34": "Show Desktop",
            "36": "Dashboard",
            "59": "Show/Hide Dock",
            "60": "Show/Hide Menu Bar",
            "7":  "Change Input Source",
            "8":  "Change Input Source (previous)",
            "163": "Screenshot",
            "30":  "Select Previous Input Source",
            "31":  "Select Next Input Source",
        ]
        return names[id]
    }
}
