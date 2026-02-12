import SwiftUI

/// Persistent user preferences, backed by `UserDefaults` via `@AppStorage`.
///
/// A singleton (`Settings.shared`) is used throughout the app because most settings are
/// read inside Quartz event-tap callbacks where dependency injection is impractical.
/// All properties are `@Published` so bound SwiftUI controls update reactively.
class Settings: ObservableObject {
    static let shared = Settings()

    // MARK: - Interaction

    /// Whether the trigger operates in hold-to-talk or click-to-toggle mode.
    @AppStorage("triggerMode") var triggerMode: TriggerMode = .holdToTalk

    /// Legacy enum for the built-in input button selector (superseded by `userShortcut`).
    @AppStorage("inputButton") var inputButton: InputButton = .middleMouse

    /// Seconds of silence before auto-stopping; `0` disables the timeout.
    @AppStorage("silenceTimeout") var silenceTimeout: Double = 0.0

    /// Preferred input device UID; empty string uses the system default device.
    @AppStorage("inputDeviceUID") var inputDeviceUID: String = ""

    // MARK: - Feedback

    /// Whether to play a sound when recording starts.
    @AppStorage("playStartSound") var playStartSound: Bool = true

    /// Whether to play a sound when recording stops.
    @AppStorage("playStopSound") var playStopSound: Bool = true

    /// Whether to display a visual HUD overlay during recording (reserved for future use).
    @AppStorage("showVisualHUD") var showVisualHUD: Bool = false

    /// System sound played when recording starts (`None` plays nothing).
    @AppStorage("selectedStartSound") var selectedStartSound: SystemSound = .none

    /// System sound played when recording stops (`None` plays nothing).
    @AppStorage("selectedStopSound") var selectedStopSound: SystemSound = .none

    // MARK: - Output

    /// When `true`, transcribed text is automatically pasted into the frontmost app via Cmd+V.
    @AppStorage("autoPaste") var autoPaste: Bool = true

    /// When `true`, transcribed text is passed through `ProfanityFilter` before use.
    @AppStorage("profanityFilter") var profanityFilter: Bool = false

    /// Reserved for a future mode that appends to existing text instead of replacing it.
    @AppStorage("appendMode") var appendMode: Bool = false

    // MARK: - System

    /// Whether the app registers itself as a login item via `ServiceManagement`.
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    // MARK: - Enums

    /// Controls how the trigger shortcut activates recording.
    enum TriggerMode: String, CaseIterable, Identifiable {
        /// Hold the trigger down to record; release to stop.
        case holdToTalk = "Hold to Talk"
        /// Press once to start recording, press again to stop.
        case toggle = "Click to Toggle"
        var id: String { rawValue }
    }

    /// Built-in input button options (currently only middle mouse is supported).
    enum InputButton: String, CaseIterable, Identifiable {
        case middleMouse = "Middle Mouse"
        var id: String { rawValue }
    }

    /// macOS system sounds available as audio feedback cues.
    enum SystemSound: String, CaseIterable, Identifiable {
        case none = "None"
        case tink = "Tink"
        case pop = "Pop"
        case basso = "Basso"
        case bottle = "Bottle"
        case frog = "Frog"
        case funk = "Funk"
        case glass = "Glass"
        case hero = "Hero"
        case morse = "Morse"
        case ping = "Ping"
        case purr = "Purr"
        case sosumi = "Sosumi"
        
        var id: String { self.rawValue }
    }
    /// A user-configured input shortcut — either a keyboard key+modifiers combo or a
    /// mouse button+modifiers combo.
    ///
    /// Stored as JSON in `UserDefaults` via the `userShortcutData` backing property so it
    /// survives app restarts.
    struct UserShortcut: Codable, Equatable {
        /// HID key code for keyboard shortcuts; `nil` when the trigger is a mouse button.
        var keyCode: UInt16?
        /// Mouse button number (0 = left, 1 = right, 2 = middle); `nil` for keyboard shortcuts.
        var mouseButton: Int?
        /// Bitmask of required modifier keys stored as `CGEventFlags.rawValue`.
        var modifiers: UInt64
        /// Human-readable label shown in `ShortcutRecorder` (e.g. "Cmd+Shift+K").
        var displayString: String

        /// The factory-default shortcut: middle mouse button, no modifiers.
        static let defaultMiddleMouse = UserShortcut(keyCode: nil, mouseButton: 2, modifiers: 0, displayString: "Middle Mouse")
    }

    /// JSON-encoded backing store for `userShortcut`, persisted via `@AppStorage`.
    @AppStorage("userShortcutData") var userShortcutData: Data = (try? JSONEncoder().encode(UserShortcut.defaultMiddleMouse)) ?? Data()

    /// The active input shortcut.
    ///
    /// Getting decodes from `userShortcutData`, normalising a legacy "Mouse 2" label.
    /// Setting re-encodes and persists via `userShortcutData`.
    var userShortcut: UserShortcut {
        get {
            if let decoded = try? JSONDecoder().decode(UserShortcut.self, from: userShortcutData) {
                // Normalize legacy "Mouse 2" display string
                if decoded.mouseButton == 2 && decoded.displayString.contains("Mouse 2") {
                    var new = decoded
                    new.displayString = "Middle Mouse"
                    return new
                }
                return decoded
            }
            return .defaultMiddleMouse
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                userShortcutData = encoded
            }
        }
    }

    
    /// Resets all settings to their factory defaults.
    func restoreDefaults() {
        triggerMode = .holdToTalk
        inputButton = .middleMouse
        silenceTimeout = 0.0
        inputDeviceUID = ""
        
        playStartSound = true
        playStopSound = true
        showVisualHUD = false
        
        selectedStartSound = .none
        selectedStopSound = .none
        
        autoPaste = true
        profanityFilter = false
        appendMode = false
        
        launchAtLogin = false
        
        userShortcutData = (try? JSONEncoder().encode(UserShortcut.defaultMiddleMouse)) ?? Data()
    }
}
