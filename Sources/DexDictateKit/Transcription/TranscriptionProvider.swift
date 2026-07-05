import Foundation
import AVFoundation

/// Common surface for every transcription engine DexDictate can route dictation through —
/// real (SwiftWhisper, Apple Speech) or an honest stub (Parakeet, Nemotron, Moonshine).
///
/// Conformers must never claim availability they can't back up: `healthCheck()` is the single
/// source of truth for whether `startTranscription()` can succeed, and stub providers always
/// throw from `startTranscription()` rather than fabricating output.
@MainActor
public protocol TranscriptionProvider: AnyObject {
    var id: TranscriptionProviderID { get }
    var displayName: String { get }
    var userFacingModeName: String { get }
    var mode: TranscriptionMode { get }
    var locality: TranscriptionProviderLocality { get }

    var supportsStreaming: Bool { get }
    var supportsPartialResults: Bool { get }
    var supportsPunctuation: Bool { get }
    var supportsCommands: Bool { get }
    var modelInstallStatus: TranscriptionModelInstallStatus { get }

    /// Fired zero or more times per session with an in-progress hypothesis. Streaming
    /// providers only.
    var onPartialResult: ((String) -> Void)? { get set }
    /// Fired at most once per session with the committed transcript.
    var onFinalResult: ((String) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }

    /// Synchronous, cheap, side-effect-free capability probe. Safe to call from the main
    /// actor on the trigger-down path — must not block on I/O or the network.
    func healthCheck() -> TranscriptionProviderHealth

    /// Begins a transcription session. Throws `TranscriptionProviderError.unavailable` instead
    /// of starting anything if `healthCheck()` would report unavailable.
    func startTranscription() throws

    /// Ends the current session, if any. Must be safe to call even when no session is active.
    func stopTranscription()
}

/// Providers that accept live microphone audio mid-session (as opposed to batch providers
/// like Whisper, which receive a complete utterance after the trigger is released) conform
/// to this in addition to `TranscriptionProvider`.
@MainActor
public protocol StreamingAudioReceiving: AnyObject {
    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer)
}
