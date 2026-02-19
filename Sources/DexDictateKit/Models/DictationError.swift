import Foundation

/// Structured errors for the dictation pipeline.
/// DexDictate uses Whisper exclusively — speech recognition cases have been removed.
enum DictationError: LocalizedError, Equatable {
    case microphoneAccessDenied
    case audioEngineSetupFailed(String)
    case inputDeviceError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access denied. Please enable it in System Settings."
        case .audioEngineSetupFailed(let message):
            return "Audio engine setup failed: \(message)"
        case .inputDeviceError:
            return "Selected input device could not be configured."
        case .unknown(let message):
            return "An unknown error occurred: \(message)"
        }
    }
}
