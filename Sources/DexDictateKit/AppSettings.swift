import SwiftUI

/// Persistent user preferences, backed by `UserDefaults` via `@AppStorage`.
///
/// A singleton (`Settings.shared`) is used throughout the app because most settings are
/// read inside Quartz event-tap callbacks where dependency injection is impractical.
/// All properties are `@Published` so bound SwiftUI controls update reactively.
public class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    public init() {
        // Load stored appearance
        if let stored = UserDefaults.standard.string(forKey: "appearanceTheme_stored"),
           let theme = AppearanceTheme(rawValue: stored) {
            appearanceTheme = theme
        }
    }

    // MARK: - Interaction

    /// Whether the trigger operates in hold-to-talk or click-to-toggle mode.
    @AppStorage("triggerMode") public var triggerMode: TriggerMode = .holdToTalk

    /// Legacy enum for the built-in input button selector (superseded by `userShortcut`).
    @AppStorage("inputButton") public var inputButton: InputButton = .middleMouse

    /// Seconds of silence before auto-stopping; `0` disables the timeout.
    @AppStorage("silenceTimeout") public var silenceTimeout: Double = 0.0

    /// Preferred input device UID; empty string uses the system default device.
    @AppStorage("inputDeviceUID") public var inputDeviceUID: String = ""

    // MARK: - Feedback

    /// Whether to play a sound when recording starts (default: silent).
    @AppStorage("playStartSound") public var playStartSound: Bool = false

    /// Whether to play a sound when recording stops (default: silent).
    @AppStorage("playStopSound") public var playStopSound: Bool = false

    /// Legacy alias for showFloatingHUD; kept for UserDefaults back-compat.
    @AppStorage("showVisualHUD") public var showVisualHUD: Bool = false

    /// System sound played when recording starts (`None` plays nothing).
    @AppStorage("selectedStartSound") public var selectedStartSound: SystemSound = .none

    /// System sound played when recording stops (`None` plays nothing).
    @AppStorage("selectedStopSound") public var selectedStopSound: SystemSound = .none

    // MARK: - Output

    /// When `true`, transcribed text is automatically pasted into the frontmost app via Cmd+V.
    @AppStorage("autoPaste") public var autoPaste: Bool = true

    /// When `true`, transcribed text is passed through `ProfanityFilter` before use.
    @AppStorage("profanityFilter") public var profanityFilter: Bool = false

    /// Reserved for a future append-mode feature; not currently implemented.
    @AppStorage("appendMode") public var appendMode: Bool = false

    // MARK: - System

    /// Whether the app registers itself as a login item via `ServiceManagement`.
    /// NOTE: SMAppService integration is pending; this setting is stored but not yet enforced.
    @AppStorage("launchAtLogin") public var launchAtLogin: Bool = false

    /// Whether the user has completed the onboarding flow.
    @AppStorage("hasCompletedOnboarding") public var hasCompletedOnboarding: Bool = false
    
    /// Whether to show the floating dictation HUD.
    @AppStorage("showFloatingHUD") public var showFloatingHUD: Bool = false

    /// Controls which transcription engine to use.
    /// DexDictate uses Whisper exclusively — no Apple Speech Recognition.
    /// This enum is kept for UserDefaults compatibility;  is the only valid value.
    public enum TranscriptionEngineType: String, CaseIterable, Identifiable {
        case whisper = "Whisper (Local CoreML)"
        public var id: String { rawValue }
    }

    /// The selected transcription engine. Defaults to Whisper (local-only, no data sent to Apple).
    @AppStorage("selectedEngine") public var selectedEngine: TranscriptionEngineType = .whisper
    
    public enum SoundTheme: String, CaseIterable, Identifiable {
        case custom = "Custom"
        case modern = "Modern"
        case retro = "Retro"
        case subtle = "Subtle"
        
        public var id: String { rawValue }
    }
    
    public enum AppearanceTheme: String, CaseIterable, Identifiable {
        case system = "System"
        case cyberpunk = "Cyberpunk"
        case minimalist = "Minimalist"
        case highContrast = "High Contrast"
        
        public var id: String { rawValue }
    }
    
    @Published public var selectedTheme: SoundTheme = .custom
    @AppStorage("appearanceTheme_stored") public var appearanceThemeStored: String = AppearanceTheme.system.rawValue
    
    @Published public var appearanceTheme: AppearanceTheme = .system {
        didSet {
            appearanceThemeStored = appearanceTheme.rawValue
        }
    }

    // Computed colors
    public var themeBackgroundColor: Color {
        switch appearanceTheme {
        case .cyberpunk: return Color.black
        case .minimalist: return Color.white
        case .highContrast: return Color.black
        case .system: return Color.clear
        }
    }
    
    public var themeAccentColor: Color {
        switch appearanceTheme {
        case .cyberpunk: return Color(red: 0, green: 1, blue: 0.8)
        case .minimalist: return Color.black
        case .highContrast: return Color.yellow
        case .system: return Color.accentColor
        }
    }
    
    public var themeTextColor: Color {
        switch appearanceTheme {
        case .cyberpunk: return Color(red: 0, green: 1, blue: 0.8)
        case .minimalist: return Color.black
        case .highContrast: return Color.white
        case .system: return Color.primary
        }
    }
    
    public func applyTheme(_ theme: SoundTheme) {
        selectedTheme = theme
        switch theme {
        case .modern:
            selectedStartSound = .glass
            selectedStopSound = .bottle
        case .retro:
            selectedStartSound = .morse
            selectedStopSound = .submarine
        case .subtle:
            selectedStartSound = .tink
            selectedStopSound = .pop
        case .custom:
            break
        }
    }
    
    // MARK: - Enums

    /// Controls how the trigger shortcut activates recording.
    public enum TriggerMode: String, CaseIterable, Identifiable {
        /// Hold the trigger down to record; release to stop.
        case holdToTalk = "Hold to Talk"
        /// Press once to start recording, press again to stop.
        case toggle = "Click to Toggle"
        public var id: String { rawValue }
    }

    /// Built-in input button options (currently only middle mouse is supported).
    public enum InputButton: String, CaseIterable, Identifiable {
        case middleMouse = "Middle Mouse"
        public var id: String { rawValue }
    }

    /// macOS system sounds available as audio feedback cues.
    public enum SystemSound: String, CaseIterable, Identifiable {
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
        case submarine = "Submarine"
        
        public var id: String { self.rawValue }
    }
    /// A user-configured input shortcut — either a keyboard key+modifiers combo or a
    /// mouse button+modifiers combo.
    ///
    /// Stored as JSON in `UserDefaults` via the `userShortcutData` backing property so it
    /// survives app restarts.
    public struct UserShortcut: Codable, Equatable {
        /// HID key code for keyboard shortcuts; `nil` when the trigger is a mouse button.
        public var keyCode: UInt16?
        /// Mouse button number (0 = left, 1 = right, 2 = middle); `nil` for keyboard shortcuts.
        public var mouseButton: Int?
        /// Bitmask of required modifier keys stored as `CGEventFlags.rawValue`.
        public var modifiers: UInt64
        /// Human-readable label shown in `ShortcutRecorder` (e.g. "Cmd+Shift+K").
        public var displayString: String
        
        public init(keyCode: UInt16?, mouseButton: Int?, modifiers: UInt64, displayString: String) {
            self.keyCode = keyCode
            self.mouseButton = mouseButton
            self.modifiers = modifiers
            self.displayString = displayString
        }

        /// The factory-default shortcut: middle mouse button, no modifiers.
        public static let defaultMiddleMouse = UserShortcut(keyCode: nil, mouseButton: 2, modifiers: 0, displayString: "Middle Mouse")
    }

    /// JSON-encoded backing store for `userShortcut`, persisted via `@AppStorage`.
    @AppStorage("userShortcutData") public var userShortcutData: Data = (try? JSONEncoder().encode(UserShortcut.defaultMiddleMouse)) ?? Data()

    /// The active input shortcut.
    ///
    /// Getting decodes from `userShortcutData`, normalising a legacy "Mouse 2" label.
    /// Setting re-encodes and persists via `userShortcutData`.
    public var userShortcut: UserShortcut {
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
    public func restoreDefaults() {
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
