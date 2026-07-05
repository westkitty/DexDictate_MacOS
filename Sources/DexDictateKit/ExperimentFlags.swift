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
    ///
    /// Default is `.balanced`, not `.accuracy`: `.accuracy` (best_of=2) roughly doubles
    /// decode work on every single dictation regardless of length — confirmed in production
    /// logs where a 1.5s utterance and a 22s utterance both took ~3-3.9s to transcribe, a flat
    /// tax rather than length-proportional. `.balanced` drops best_of to 1 (no double-decode)
    /// while still leaving `speed_up` off, so it doesn't take the phase-vocoder quality hit
    /// `.speed` does. This only affects the *default* — `retryLastUtteranceInAccuracyMode()`
    /// and the automatic suspicious-result retry both already explicitly request `.accuracy`
    /// as an override for that one attempt, so accuracy-on-demand is unaffected.
    public static var whisperDecodeProfile: DecodeProfile = .balanced
    
    public enum ResampleMethod {
        case linear
        case avAudioConverter
    }
    /// The manual resampler vs AVAudioConverter path.
    public static var resampleMethod: ResampleMethod = .avAudioConverter

    /// Pre-trigger circular audio buffer — preserves the 750ms of audio before dictation
    /// starts so the first syllable is never clipped.
    /// Default disabled for safe rollout; enable via feature flags or testing.
    public static var enablePreTriggerBuffer: Bool = false

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
