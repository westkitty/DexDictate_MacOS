import Foundation

/// Structured errors for the dictation pipeline.
/// DexDictate uses Whisper exclusively — speech recognition cases have been removed.
public enum DictationError: LocalizedError, Equatable {
    case microphoneAccessDenied
    case audioEngineSetupFailed(String)
    case inputDeviceError
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access denied. Please enable it in System Settings."
        case .audioEngineSetupFailed(let message):
            if message.contains("-10868")
                || message.contains("kAudioOutputUnitErr_InvalidDevice")
                || message.contains("coreaudio.avfaudio error -10868")
            {
                return """
                Audio engine setup failed: \(message)

                This is usually a macOS Core Audio problem, not a DexDictate settings problem.
                Fix: open Terminal and run:
                sudo killall -9 coreaudiod

                Then try DexDictate again.
                """
            }
            return "Audio engine setup failed: \(message)"
        case .inputDeviceError:
            return "Selected input device could not be configured."
        case .unknown(let message):
            return "An unknown error occurred: \(message)"
        }
    }
}
