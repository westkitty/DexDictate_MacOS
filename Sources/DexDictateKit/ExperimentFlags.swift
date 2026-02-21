import Foundation

public struct ExperimentFlags {
    /// Silence trim heuristic. If true, trims trailing silence via RMS energy threshold before passing to Whisper.
    public static var enableSilenceTrim = true
    
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
