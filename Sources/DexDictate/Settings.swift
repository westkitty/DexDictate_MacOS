import SwiftUI

class Settings: ObservableObject {
    static let shared = Settings()
    
    // 1. Interaction
    @AppStorage("triggerMode") var triggerMode: TriggerMode = .holdToTalk
    @AppStorage("inputButton") var inputButton: InputButton = .middleMouse
    @AppStorage("silenceTimeout") var silenceTimeout: Double = 0.0 // 0 = disabled

    // 2. Feedback
    @AppStorage("playStartSound") var playStartSound: Bool = true
    @AppStorage("playStopSound") var playStopSound: Bool = true
    @AppStorage("showVisualHUD") var showVisualHUD: Bool = false
    
    // INJECTION: Sound Selection Logic
    // INJECTION: Sound Selection Logic
    @AppStorage("selectedStartSound") var selectedStartSound: SystemSound = .none
    @AppStorage("selectedStopSound") var selectedStopSound: SystemSound = .none

    // 3. Output
    @AppStorage("autoPaste") var autoPaste: Bool = true
    @AppStorage("profanityFilter") var profanityFilter: Bool = false
    @AppStorage("appendMode") var appendMode: Bool = false

    // 4. System
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    
    // Enums
    enum TriggerMode: String, CaseIterable, Identifiable {
        case holdToTalk = "Hold to Talk"
        case toggle = "Click to Toggle"
        var id: String { rawValue }
    }
    
    enum InputButton: String, CaseIterable, Identifiable {
        case middleMouse = "Middle Mouse"
        // case rightMouse = "Right Mouse" // Hard to intercept without nuisance
        // Future expansion
        var id: String { rawValue }
    }

    
    // INJECTION: Sound Selection Logic
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
    // INJECTION: Configurable Input
    struct UserShortcut: Codable, Equatable {
        var keyCode: UInt16?     // For keyboard
        var mouseButton: Int?    // For mouse
        var modifiers: UInt64    // CGEventFlags.rawValue (UInt64)
        var displayString: String
        
        static let defaultMiddleMouse = UserShortcut(keyCode: nil, mouseButton: 2, modifiers: 0, displayString: "Middle Mouse")
    }
    
    @AppStorage("userShortcutData") var userShortcutData: Data = try! JSONEncoder().encode(UserShortcut.defaultMiddleMouse)
    
    var userShortcut: UserShortcut {
        get {
            if let decoded = try? JSONDecoder().decode(UserShortcut.self, from: userShortcutData) {
                // FIXED: Force display string update if it's outdated or generic
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

    
    func restoreDefaults() {
        triggerMode = .holdToTalk
        inputButton = .middleMouse
        silenceTimeout = 0.0
        
        playStartSound = true
        playStopSound = true
        showVisualHUD = false
        
        selectedStartSound = .none
        selectedStopSound = .none
        
        autoPaste = true
        profanityFilter = false // Ensure OFF by default
        appendMode = false
        
        launchAtLogin = false
        
        userShortcutData = try! JSONEncoder().encode(UserShortcut.defaultMiddleMouse)
    }
}
