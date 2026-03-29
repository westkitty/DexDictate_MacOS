import Foundation

public struct ExperimentFlags {
    /// Silence trim heuristic. Now fixed to use the quietest frames in the recording
    /// (not the first frames) for noise floor estimation, so it's safe in hold-to-talk mode.
    public static var enableSilenceTrim = false
    
    /// Amount of tail delay (ms) applied after trigger release before stopping audio engine.
    /// Current default is 250ms. Older builds used 750ms.
    public static var stopTailDelayMs: UInt64 = 250

    /// Trailing-only trim remains opt-in until benchmark evidence says otherwise.
    public static var enableTrailingTrim = false
    public static var trailingTrimMinimumSilenceMs = 220
    public static var trailingTrimPadMs = 80
    
    public enum DecodeProfile {
        case speed
        case balanced
        case accuracy
    }
    /// Controls greedy.best_of, speed_up phase vocoder, and temperature retries.
    public static var whisperDecodeProfile: DecodeProfile = .accuracy
    
    public enum ResampleMethod {
        case linear
        case avAudioConverter
    }
    /// The manual resampler vs AVAudioConverter path.
    public static var resampleMethod: ResampleMethod = .avAudioConverter

    public static func applyRuntimeSettings(_ settings: AppSettings) {
        stopTailDelayMs = settings.utteranceEndPreset.stopTailDelayMs
        enableSilenceTrim = settings.enableSilenceTrim
        enableTrailingTrim = settings.enableTrailingTrimExperiment
        trailingTrimMinimumSilenceMs = settings.utteranceEndPreset.trailingTrimMinimumSilenceMs
        trailingTrimPadMs = settings.utteranceEndPreset.trailingTrimPadMs
    }
}

public extension ExperimentFlags.DecodeProfile {
    var cliName: String {
        switch self {
        case .accuracy:
            return "accuracy"
        case .balanced:
            return "balanced"
        case .speed:
            return "speed"
        }
    }
}
