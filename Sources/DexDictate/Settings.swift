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

    // 3. Output
    @AppStorage("autoPaste") var autoPaste: Bool = true
    @AppStorage("profanityFilter") var profanityFilter: Bool = true
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
}
