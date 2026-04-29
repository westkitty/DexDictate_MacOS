import Foundation

public struct ExperimentFlags {
    /// Silence trim heuristic. Disabled: the adaptive noise-floor estimator
    /// samples the first 500ms of audio (which is speech in hold-to-talk mode),
    /// inflating the threshold and clipping sentence onsets. Needs redesign with
    /// a pre-trigger calibration window before this can safely be re-enabled.
    public static var enableSilenceTrim = false
    
    /// Amount of tail delay (ms) applied after trigger release before stopping audio engine.
    /// Current default is 250ms. Older builds used 750ms.
    public static var stopTailDelayMs: UInt64 = 250

    /// Trailing-only trim defaults on; leading/full trim remains separately guarded.
    public static var enableTrailingTrim = true
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
