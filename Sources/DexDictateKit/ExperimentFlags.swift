import Foundation

public struct ExperimentFlags {
    /// Silence trim heuristic. Disabled: the adaptive noise-floor estimator
    /// samples the first 500ms of audio (which is speech in hold-to-talk mode),
    /// inflating the threshold and clipping sentence onsets. Needs redesign with
    /// a pre-trigger calibration window before this can safely be re-enabled.
    public static var enableSilenceTrim = false
    
    /// Amount of tail delay (ms) applied after trigger release before stopping audio engine.
    /// Current head is 250ms. Older builds used 750ms.
    public static var stopTailDelayMs: UInt64 = 750
    
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
}
