import Foundation

/// The 11 top-level destinations in the Settings window sidebar, in display order.
///
/// This enum is the single source of truth for sidebar ordering and naming; pages are
/// placeholders in Packet 02 and gain real controls in Packets 03–11.
enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case dictation
    case audioMicrophone
    case outputInsertion
    case vocabularyCommands
    case modelsAccuracy
    case smartCleanup
    case history
    case dexterPersonality
    case diagnosticsRecovery
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .dictation: return "Dictation"
        case .audioMicrophone: return "Audio & Microphone"
        case .outputInsertion: return "Output & Insertion"
        case .vocabularyCommands: return "Vocabulary & Commands"
        case .modelsAccuracy: return "Models & Accuracy"
        case .smartCleanup: return "Smart Cleanup"
        case .history: return "History"
        case .dexterPersonality: return "Dexter & Personality"
        case .diagnosticsRecovery: return "Diagnostics & Recovery"
        case .advanced: return "Advanced"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .dictation: return "mic"
        case .audioMicrophone: return "waveform"
        case .outputInsertion: return "text.cursor"
        case .vocabularyCommands: return "character.book.closed"
        case .modelsAccuracy: return "cpu"
        case .smartCleanup: return "sparkles"
        case .history: return "clock.arrow.circlepath"
        case .dexterPersonality: return "theatermasks"
        case .diagnosticsRecovery: return "stethoscope"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}
