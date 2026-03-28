import SwiftUI

/// Persistent user preferences, backed by `UserDefaults` via `@AppStorage`.
///
/// A singleton (`Settings.shared`) is used throughout the app because most settings are
/// read inside Quartz event-tap callbacks where dependency injection is impractical.
/// All properties are `@Published` so bound SwiftUI controls update reactively.
public class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    public init() {
        SettingsMigrationCoordinator(store: UserDefaults.standard).migrateIfNeeded()
        // Load stored appearance
        if let stored = UserDefaults.standard.string(forKey: "appearanceTheme_stored"),
           let theme = AppearanceTheme(rawValue: stored) {
            appearanceTheme = theme
        }

        let defaults = UserDefaults.standard
        if defaults.object(forKey: "menuBarDisplayMode_v1") == nil,
           !selectedMenuBarIconIdentifier.isEmpty {
            menuBarDisplayMode = .customIcon
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

    /// When `true`, likely secure text-entry contexts fall back to copy-only instead of auto-paste.
    @AppStorage("copyOnlyInSensitiveFields") public var copyOnlyInSensitiveFields: Bool = true

    /// When `true`, transcribed text is passed through `ProfanityFilter` before use.
    @AppStorage("profanityFilter") public var profanityFilter: Bool = false

    /// Reserved for a future append-mode feature; not currently implemented.
    @AppStorage("appendMode") public var appendMode: Bool = false

    /// Applies a reversible lower-risk preset for dictation behavior.
    @AppStorage("safeModeEnabled") public var safeModeEnabled: Bool = false
    @AppStorage("safeModeSnapshotData") public var safeModeSnapshotData: Data = Data()

    // MARK: - System

    /// Mirrors whether DexDictate is currently configured to launch at login.
    @AppStorage("launchAtLogin") public var launchAtLogin: Bool = false

    /// Whether the user has completed the onboarding flow.
    @AppStorage("hasCompletedOnboarding") public var hasCompletedOnboarding: Bool = false
    
    /// Whether to show the floating dictation HUD.
    @AppStorage("showFloatingHUD") public var showFloatingHUD: Bool = false

    /// Controls how the primary menu bar item renders while idle.
    @AppStorage("menuBarDisplayMode_v1") public var menuBarDisplayMode: MenuBarDisplayMode = .micAndText

    /// Controls the active bundled profile content set.
    @AppStorage("localizationMode_v1") public var localizationMode: AppProfile = .standard

    /// Whether the single-line flavor ticker is visible in the menu bar popover.
    @AppStorage("showFlavorTicker_v1") public var showFlavorTicker: Bool = true

    /// Whether the flavor ticker may animate when content overflows and motion is allowed.
    @AppStorage("animateFlavorTicker_v1") public var animateFlavorTicker: Bool = true

    /// Persisted selection for the Dex icon asset.
    @AppStorage("selectedMenuBarIconIdentifier_v2") public var selectedMenuBarIconIdentifier: String = ""

    /// Persisted selection for the emoji-based menu bar icon.
    @AppStorage("selectedMenuBarEmoji_v1") public var selectedMenuBarEmoji: String = "🐶"

    /// Controls which transcription engine to use.
    /// DexDictate uses Whisper exclusively — no Apple Speech Recognition.
    /// This enum is kept for UserDefaults compatibility;  is the only valid value.
    public enum TranscriptionEngineType: String, CaseIterable, Identifiable {
        case whisper = "Whisper (Local CoreML)"
        public var id: String { rawValue }
    }

    /// The selected transcription engine. Defaults to Whisper (local-only, no data sent to Apple).
    @AppStorage("selectedEngine") public var selectedEngine: TranscriptionEngineType = .whisper

    public enum ModelSelectionMode: String, CaseIterable, Identifiable {
        case autoIdleBenchmark = "Auto Idle Benchmark"
        case manual = "Manual"

        public var id: String { rawValue }
    }

    public enum UtteranceEndPreset: String, CaseIterable, Identifiable {
        case stable = "Stable"
        case fast = "Fast"
        case conservative = "Conservative"

        public var id: String { rawValue }

        public var stopTailDelayMs: UInt64 {
            switch self {
            case .stable:
                return 250
            case .fast:
                return 180
            case .conservative:
                return 400
            }
        }

        public var trailingTrimMinimumSilenceMs: Int {
            switch self {
            case .stable:
                return 220
            case .fast:
                return 150
            case .conservative:
                return 320
            }
        }

        public var trailingTrimPadMs: Int {
            switch self {
            case .stable:
                return 80
            case .fast:
                return 50
            case .conservative:
                return 120
            }
        }
    }

    @AppStorage("activeWhisperModelID_v1") public var activeWhisperModelID: String = "tiny.en"
    @AppStorage("modelSelectionMode_v1") public var modelSelectionMode: ModelSelectionMode = .autoIdleBenchmark
    @AppStorage("utteranceEndPreset_v1") public var utteranceEndPreset: UtteranceEndPreset = .stable
    @AppStorage("benchmarkGateEnabled_v1") public var benchmarkGateEnabled: Bool = true
    @AppStorage("allowAutoModelPromotion_v1") public var allowAutoModelPromotion: Bool = true
    @AppStorage("enableTrailingTrimExperiment_v1") public var enableTrailingTrimExperiment: Bool = true
    @AppStorage("enableAccuracyRetry_v1") public var enableAccuracyRetry: Bool = true
    @AppStorage("enableCorrectionSheet_v1") public var enableCorrectionSheet: Bool = true
    
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

    public enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
        case micAndText = "Mic + Text"
        case micOnly = "Mic Only"
        case customIcon = "Custom Icon"
        case logoOnly = "Logo Only"
        case emojiIcon = "Emoji"

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
        
        playStartSound = false
        playStopSound = false
        showVisualHUD = false
        
        selectedStartSound = .none
        selectedStopSound = .none
        
        autoPaste = true
        copyOnlyInSensitiveFields = true
        profanityFilter = false
        appendMode = false
        safeModeEnabled = false
        safeModeSnapshotData = Data()
        
        _ = SystemLaunchAtLoginService.unregisterIfPossible()
        launchAtLogin = false
        selectedEngine = .whisper
        selectedTheme = .custom
        appearanceTheme = .system
        appearanceThemeStored = AppearanceTheme.system.rawValue
        menuBarDisplayMode = .micAndText
        localizationMode = .standard
        activeWhisperModelID = "tiny.en"
        modelSelectionMode = .autoIdleBenchmark
        utteranceEndPreset = .stable
        benchmarkGateEnabled = true
        allowAutoModelPromotion = true
        enableTrailingTrimExperiment = true
        enableAccuracyRetry = true
        enableCorrectionSheet = true
        showFlavorTicker = true
        animateFlavorTicker = true
        selectedMenuBarIconIdentifier = ""
        selectedMenuBarEmoji = "🐶"
        
        userShortcutData = (try? JSONEncoder().encode(UserShortcut.defaultMiddleMouse)) ?? Data()
    }

    public func restoreStableDictationDefaults() {
        activeWhisperModelID = "tiny.en"
        utteranceEndPreset = .stable
        enableTrailingTrimExperiment = false
        enableAccuracyRetry = true
        enableCorrectionSheet = true
    }

    public func selectMenuBarDisplayMode(_ mode: MenuBarDisplayMode) {
        objectWillChange.send()
        menuBarDisplayMode = mode
    }

    public func selectMenuBarIcon(identifier: String?) {
        objectWillChange.send()
        selectedMenuBarIconIdentifier = identifier ?? ""
        if identifier != nil {
            menuBarDisplayMode = .customIcon
        }
    }

    public func selectMenuBarEmoji(_ emoji: String) {
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        objectWillChange.send()
        selectedMenuBarEmoji = trimmed
        menuBarDisplayMode = .emojiIcon
    }

    public func enableSafeMode() {
        guard !safeModeEnabled else { return }

        let snapshot = SafeModePreferences(
            triggerModeRawValue: triggerMode.rawValue,
            autoPaste: autoPaste,
            playStartSound: playStartSound,
            playStopSound: playStopSound,
            selectedStartSoundRawValue: selectedStartSound.rawValue,
            selectedStopSoundRawValue: selectedStopSound.rawValue
        )

        safeModeSnapshotData = (try? JSONEncoder().encode(snapshot)) ?? Data()

        var safePreferences = snapshot
        safePreferences.applySafeMode()
        applySafeModePreferences(safePreferences)
        safeModeEnabled = true
    }

    public func disableSafeMode() {
        defer {
            safeModeEnabled = false
            safeModeSnapshotData = Data()
        }

        guard let snapshot = try? JSONDecoder().decode(SafeModePreferences.self, from: safeModeSnapshotData) else {
            return
        }

        applySafeModePreferences(snapshot)
    }

    private func applySafeModePreferences(_ preferences: SafeModePreferences) {
        triggerMode = preferences.triggerMode
        autoPaste = preferences.autoPaste
        playStartSound = preferences.playStartSound
        playStopSound = preferences.playStopSound
        selectedStartSound = preferences.selectedStartSound
        selectedStopSound = preferences.selectedStopSound
    }
}
