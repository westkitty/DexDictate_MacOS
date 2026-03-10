import Foundation

struct SafeModePreferences: Codable, Equatable {
    var triggerModeRawValue: String
    var autoPaste: Bool
    var playStartSound: Bool
    var playStopSound: Bool
    var selectedStartSoundRawValue: String
    var selectedStopSoundRawValue: String

    var triggerMode: AppSettings.TriggerMode {
        get { AppSettings.TriggerMode(rawValue: triggerModeRawValue) ?? .holdToTalk }
        set { triggerModeRawValue = newValue.rawValue }
    }

    var selectedStartSound: AppSettings.SystemSound {
        get { AppSettings.SystemSound(rawValue: selectedStartSoundRawValue) ?? .none }
        set { selectedStartSoundRawValue = newValue.rawValue }
    }

    var selectedStopSound: AppSettings.SystemSound {
        get { AppSettings.SystemSound(rawValue: selectedStopSoundRawValue) ?? .none }
        set { selectedStopSoundRawValue = newValue.rawValue }
    }

    mutating func applySafeMode() {
        triggerMode = .holdToTalk
        autoPaste = false
        playStartSound = false
        playStopSound = false
        selectedStartSound = .none
        selectedStopSound = .none
    }
}
