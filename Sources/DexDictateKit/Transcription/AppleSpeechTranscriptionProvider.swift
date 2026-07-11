import Foundation
import Speech
import AVFoundation

/// Real, live Apple Speech provider used as the live-transcription fallback when Nemotron
/// isn't available. It streams partial hypotheses while the user talks.
///
/// Scope note (deliberate, not a shortcut): this provider drives DexDictate's *live preview
/// text only* (`TranscriptionEngine.liveTranscript`) while the user is speaking. It does not
/// replace Whisper as the authority for the committed transcript — the existing, tuned
/// Whisper batch pipeline (commands, vocabulary correction, punctuation, paste/clipboard
/// delivery) still produces and delivers the final text, completely unchanged. This keeps the
/// well-tested output path stable while still giving the user real, honest live captions
/// while Live Transcription is on. See DEXDICTATE_LOCAL_CONTEXT / report for the follow-up
/// needed to make a streaming engine authoritative for final output.
///
/// Never starts its own `AVAudioEngine` or audio tap — it only consumes `AVAudioPCMBuffer`s
/// that `AudioRecorderService` is already capturing for Whisper, via `appendAudioBuffer(_:)`,
/// so it cannot conflict with the existing microphone pipeline.
///
/// Offline policy: this provider refuses to run unless the device supports on-device speech
/// recognition (`supportsOnDeviceRecognition`). It never falls back to Apple's server-based
/// recognition, which would be a network call during dictation.
@MainActor
public final class AppleSpeechTranscriptionProvider: TranscriptionProvider, StreamingAudioReceiving {
    public let id: TranscriptionProviderID = .appleSpeech
    public let displayName = "Apple Speech"
    public let userFacingModeName = "Apple Speech"
    public let mode: TranscriptionMode = .appleSpeech
    public let locality: TranscriptionProviderLocality = .native

    public let supportsStreaming = true
    public let supportsPartialResults = true
    public let supportsPunctuation = true
    public let supportsCommands = false
    public let modelInstallStatus: TranscriptionModelInstallStatus = .builtIn

    public var onPartialResult: ((String) -> Void)?
    public var onFinalResult: ((String) -> Void)?
    public var onError: ((Error) -> Void)?

    private let recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    public private(set) var isSessionActive = false

    /// Bumped on every start/stop. `SFSpeechRecognitionTask.cancel()` is not guaranteed
    /// synchronous — the recognizer can still deliver one more callback shortly after
    /// cancellation. The completion closure captures the generation at task-creation time and
    /// discards any callback that arrives once a newer session has started, which is exactly
    /// the "stale caption bleeds into the next utterance" failure `cancelTranscription()`'s own
    /// doc comment describes wanting to prevent.
    private var sessionGeneration = 0

    public init() {
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) ?? SFSpeechRecognizer()
    }

    public func healthCheck() -> TranscriptionProviderHealth {
        guard let recognizer else {
            return .unavailable("No speech recognizer is available for the current locale.")
        }
        guard recognizer.isAvailable else {
            return .unavailable("Apple Speech recognizer is temporarily unavailable.")
        }
        guard recognizer.supportsOnDeviceRecognition else {
            return .unavailable("On-device recognition isn't supported on this Mac; DexDictate won't use server-based Speech Recognition.")
        }
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .available()
        case .notDetermined:
            return .unavailable("Speech Recognition permission hasn't been granted yet.")
        case .denied:
            return .unavailable("Speech Recognition permission denied. Enable it in System Settings > Privacy & Security > Speech Recognition.")
        case .restricted:
            return .unavailable("Speech Recognition is restricted on this Mac.")
        @unknown default:
            return .unavailable("Speech Recognition permission status is unknown.")
        }
    }

    /// Opportunistically requests the Speech Recognition TCC permission if it has never been
    /// decided. Safe to call repeatedly — no-ops once a decision exists. Does not block.
    public func requestAuthorizationIfNeeded() {
        guard SFSpeechRecognizer.authorizationStatus() == .notDetermined else { return }
        SFSpeechRecognizer.requestAuthorization { _ in }
    }

    public func startTranscription() throws {
        guard !isSessionActive else { return }
        let health = healthCheck()
        guard health.isAvailable, let recognizer else {
            throw TranscriptionProviderError.unavailable(health.reason ?? "Apple Speech is unavailable.")
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request
        isSessionActive = true
        sessionGeneration &+= 1
        let myGeneration = sessionGeneration

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            MainActorDispatch.async {
                guard let self, self.sessionGeneration == myGeneration else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.onFinalResult?(text)
                    } else {
                        self.onPartialResult?(text)
                    }
                }
                if let error {
                    self.onError?(error)
                }
            }
        }
    }

    public func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isSessionActive else { return }
        recognitionRequest?.append(buffer)
    }

    public func stopTranscription() {
        cancelTranscription()
    }

    /// Hard-cancels the current session, if any. Used for both the normal end-of-utterance
    /// path and teardown.
    ///
    /// This deliberately cancels rather than calling `endAudio()` and letting the task finish
    /// naturally: nothing in DexDictate consumes Apple Speech's final result (Whisper/Parakeet
    /// own the committed transcript — see the type doc above), so there's no reason to keep
    /// the task alive after the trigger is released. Letting it linger risked a late partial
    /// or final callback from *this* utterance arriving after a *new* session had already
    /// started (its weak `self` capture would still be valid, and `onPartialResult` doesn't
    /// otherwise distinguish which utterance a callback belongs to) — bleeding stale live
    /// captions from utterance N-1 into utterance N's preview.
    public func cancelTranscription() {
        isSessionActive = false
        sessionGeneration &+= 1
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
}
