import SwiftUI
import AVFoundation
import AudioToolbox
import Combine

/// The central coordinator for the speech-recognition pipeline.
@MainActor
public final class TranscriptionEngine: ObservableObject {

    /// Current lifecycle phase of the engine.
    @Published public var state: EngineState = .stopped

    /// Human-readable status description.
    @Published public var statusText = NSLocalizedString("Idle", comment: "Status: Idle")

    /// Live partial transcription.
    @Published public var liveTranscript = ""

    /// Normalized microphone input level (0.0-1.0).
    @Published public var inputLevel: Double = 0

    /// Transcription history.
    @Published public var history = TranscriptionHistory()

    private let audioService = AudioRecorderService()
    private let whisperService = WhisperService()
    public let vocabularyManager = VocabularyManager()
    private let commandProcessor = CommandProcessor()
    
    /// Global input monitor.
    private var inputMonitor: InputMonitor?

    /// Pending stop task (debounce).
    private var stopTask: Task<Void, Error>?

    private weak var permissionManager: PermissionManager?
    private var currentSessionId = UUID()
    
    private var recognitionTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()

    public enum EngineState {
        case stopped, initializing, ready, listening, transcribing, error
    }

    /// SF Symbol name reflecting current state.
    public var statusIcon: String {
        switch state {
        case .listening: return "waveform.circle.fill"
        case .transcribing: return "hourglass"
        case .ready: return "waveform.circle"
        case .error: return "exclamationmark.triangle.fill"
        default: return "circle"
        }
    }
    
    public static let shared = TranscriptionEngine()
             
    public init() {
        // AudioRecorderService.inputLevel is @MainActor @Published — safe to bind directly.
        audioService.$inputLevel
            .assign(to: &$inputLevel)

        // Bind Whisper output
        whisperService.ontranscriptionComplete = { [weak self] text in
            Task { @MainActor in
                self?.liveTranscript = text
            }
        }
    }

    // MARK: - System Lifecycle

    public func startSystem() async {
        // Belt-and-suspenders guard: .onAppear already checks engine.state == .stopped,
        // but this prevents double-initialisation if startSystem() is ever called from
        // another code path while the engine is already running.
        guard state == .stopped else {
            Safety.log("startSystem() skipped — already running (state=\(state))")
            return
        }
        Safety.log("startSystem() called — setting up input monitor")
        state = .initializing
        statusText = NSLocalizedString("Requesting Access...", comment: "Status: Requesting permissions")
        // DexDictate uses Whisper (local CoreML) exclusively — no Apple Speech Recognition.
        setupInputMonitor()
        Safety.log("startSystem() complete — state=\(state)")
    }

    public func stopSystem() {
        inputMonitor?.stop()
        audioService.stopRecording()
        state = .stopped
        statusText = NSLocalizedString("Idle", comment: "Status: Idle")
        liveTranscript = ""
        inputLevel = 0
    }
    
    /// True once the Whisper model has been successfully loaded into memory.
    /// Used by `.onAppear` to skip redundant 74 MB model reloads when the engine
    /// is stopped and restarted (e.g. user clicks "Stop Dictation" then opens the menu again).
    public var isModelLoaded: Bool { whisperService.isModelLoaded }

    public func loadWhisperModel(url: URL) {
        whisperService.loadModel(url: url)
    }

    public func loadEmbeddedWhisperModel() {
        whisperService.loadEmbeddedModel()
    }

    public func setPermissionManager(_ manager: PermissionManager) {
        self.permissionManager = manager
    }

    public func retryInputMonitor() {
        inputMonitor?.stop()
        inputMonitor = nil
        setupInputMonitor()
    }

    // MARK: - Trigger Handling

    public func toggleListening() {
        if state == .listening {
            stopListening()
        } else {
            startListening()
        }
    }

    public func handleTrigger(down: Bool) {
        if down {
            stopTask?.cancel()
            stopTask = nil
            currentSessionId = UUID()

            if state != .listening {
                startListening()
            }
        } else {
            scheduleStop()
        }
    }

    // MARK: - Private

    private func setupInputMonitor() {
        // Stop the old monitor (and cancel any pending retry) before replacing it.
        // Without this, the old monitor's 5-second retry fires after we've already
        // created a new tap, producing a duplicate CGEvent tap.
        inputMonitor?.stop()
        inputMonitor = InputMonitor(engine: self)
        inputMonitor?.start()
        // Only advance to .ready if the tap was created successfully.
        // If tapCreate failed, InputMonitor queues a Task { state = .error } — but we
        // must NOT overwrite it with .ready here (that Task runs after this function
        // returns, so the ordering would be: .ready set here → .error set by Task).
        // Instead, check the tap synchronously via isEventTapActive.
        if inputMonitor?.isEventTapActive == true {
            state = .ready
            statusText = NSLocalizedString("Ready", comment: "Status: Ready")
        }
        // If tap failed, state stays .initializing until the InputMonitor Task sets .error.
    }

    private func scheduleStop() {
        // Keep a short tail to avoid clipping final phonemes while minimizing perceived latency.
        let stopDelayMs: UInt64 = 250
        Safety.log("scheduleStop() — scheduling stop after \(stopDelayMs)ms")
        stopTask?.cancel()
        let sessionId = currentSessionId

        stopTask = Task {
            try? await Task.sleep(nanoseconds: stopDelayMs * 1_000_000)
            if !Task.isCancelled && sessionId == currentSessionId {
                Safety.log("scheduleStop() — \(stopDelayMs)ms elapsed, calling stopListening()")
                stopListening()
            } else {
                if Task.isCancelled {
                    Safety.log("scheduleStop() — Task was cancelled, not calling stopListening()")
                } else {
                    Safety.log("scheduleStop() — sessionId mismatch, not calling stopListening()")
                }
            }
        }
    }

    private func startListening() {
        Safety.log("startListening() called — state=\(state)")
        guard state == .ready else {
            Safety.log("startListening() BLOCKED — state is \(state), must be .ready")
            return
        }

        // Request microphone permission if needed (deferred from onboarding)
        permissionManager?.requestMicrophoneIfNeeded()

        // Guard against blocking CoreAudio calls when mic is not yet authorised.
        // applyInputDevice() calls AudioUnitSetProperty() which can block the main
        // thread indefinitely when TCC permission has been revoked (e.g. after
        // `tccutil reset All`), deadlocking the main actor and preventing the
        // trigger-release Task from ever running.
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        Safety.log("startListening() — mic authorizationStatus=\(micStatus.rawValue)")
        guard micStatus == .authorized else {
            Safety.log("startListening() — microphone not authorized (status=\(micStatus.rawValue)) — aborting to avoid deadlock")
            state = .ready
            statusText = micStatus == .denied
                ? NSLocalizedString("Microphone access denied. Enable in System Settings.", comment: "Status: Mic denied")
                : NSLocalizedString("Microphone permission required. Grant access when prompted.", comment: "Status: Mic not determined")
            return
        }

        state = .listening
        statusText = NSLocalizedString("Listening...", comment: "Status: Listening")
        liveTranscript = ""
        inputLevel = 0

        if AppSettings.shared.playStartSound {
            SoundPlayer.play(AppSettings.shared.selectedStartSound)
        }

        // All AVAudioEngine operations (inputNode, prepare, start) run on AudioRecorderService's
        // internal audioQueue — fully off the main actor. The completion block fires back on
        // @MainActor so we can update state without re-entering the main thread.
        let uid = AppSettings.shared.inputDeviceUID
        audioService.startRecordingAsync(inputDeviceUID: uid) { [weak self] error in
            guard let self else { return }
            if let error {
                Safety.log("ERROR: startListening() — audio engine failed: \(error) — resetting state to .ready")
                let desc = error.localizedDescription.lowercased()
                if desc.contains("permission") || desc.contains("unauthorized") {
                    self.statusText = NSLocalizedString("Microphone access lost. Please check system preferences.", comment: "Status: Permission revoked during recording")
                    self.permissionManager?.refreshPermissions()
                } else {
                    self.statusText = error.localizedDescription
                }
                self.state = .ready
            } else {
                Safety.log("Audio engine started successfully — accumulating audio until trigger release")
            }
        }
    }
    
    // NOTE: startWhisperRecognition() has been removed.
    // Audio is accumulated during the recording session and submitted to Whisper
    // as a single batch in stopListening() after the trigger is released.
    // Streaming per-chunk calls caused `instanceBusy` errors and empty output
    // because whisper.cpp is a batch model that requires a complete utterance
    // at its required 16 kHz sample rate.

    private func stopListening() {
        guard state == .listening else {
            Safety.log("stopListening() BLOCKED — state=\(state), expected .listening")
            return
        }
        state = .transcribing
        statusText = NSLocalizedString("Transcribing...", comment: "Status: Transcribing")
        inputLevel = 0

        // 1. Stop the audio engine and atomically collect the full utterance buffer.
        // stopAndCollect() runs on audioQueue.sync — safe from @MainActor because
        // audioQueue never dispatches back to main synchronously.
        recognitionTask?.cancel()
        recognitionTask = nil

        let (rawSamples, sourceSampleRate) = audioService.stopAndCollect()
        Safety.log("stopListening() — collected \(rawSamples.count) samples @ \(sourceSampleRate) Hz")

        if AppSettings.shared.playStopSound {
            SoundPlayer.play(AppSettings.shared.selectedStopSound)
        }

        // 2. Resample to 16 kHz (Whisper's required sample rate) and submit once.
        let whisperSamples = resampleToWhisper(rawSamples, fromRate: sourceSampleRate)
        Safety.log("Submitting \(whisperSamples.count) samples @ 16000 Hz to Whisper")

        // Wire up result handler before calling transcribe.
        whisperService.ontranscriptionComplete = { [weak self] text in
            Task { @MainActor in
                self?.handleWhisperResult(text)
            }
        }
        whisperService.transcribe(audioFrames: whisperSamples)
    }

    /// Called by WhisperService when the single-batch transcription completes.
    private func handleWhisperResult(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Safety.log("handleWhisperResult — \(trimmed.isEmpty ? "empty" : "\(trimmed.count) chars")")
        if trimmed.isEmpty {
            state = .ready
            statusText = NSLocalizedString("Ready", comment: "Status: Ready to dictate")
        } else {
            finalizeTranscription(trimmed)
        }
    }

    /// Linear interpolation resample: converts mono float PCM from `fromRate` to 16000 Hz.
    /// Whisper.cpp requires exactly 16000 Hz input; no internal resampling is performed.
    private func resampleToWhisper(_ samples: [Float], fromRate: Double) -> [Float] {
        let targetRate: Double = 16000
        guard fromRate != targetRate, !samples.isEmpty else { return samples }
        let ratio = fromRate / targetRate
        let outputCount = Int(Double(samples.count) / ratio)
        var output = [Float](repeating: 0, count: outputCount)
        for i in 0..<outputCount {
            let srcPos = Double(i) * ratio
            let srcIdx = Int(srcPos)
            let frac = Float(srcPos - Double(srcIdx))
            let a = samples[srcIdx]
            let b = srcIdx + 1 < samples.count ? samples[srcIdx + 1] : a
            output[i] = a + frac * (b - a)
        }
        return output
    }
    
    private func finalizeTranscription(_ text: String) {
        // Any path through this method completes the transcription cycle.
        // Without this, early returns (e.g. command-only utterances) can leave state
        // stuck at .transcribing and block the next trigger press.
        defer {
            state = .ready
        }

        // 0. Process Commands
        let (processedText, command) = commandProcessor.process(text)
        
        if command == .deleteLastSentence {
            // Check if user said JUST "scratch that" (meaning delete previous history item)
            // or if they said "oops scratch that" (meaning discard current utterance)
            
            // Heuristic: If processedText is empty, they likely meant "scratch that" for the previous sentence
            // UNLESS the original text was just "scratch that".
            // Actually, commandProcessor returns "" if it was "scratch that".
            // The intent is ambiguous if we don't track state.
            // Simplified:
            // 1. If we have content to discard (the current utterance), we discard it.
            // 2. If the current utterance WAS effectively empty/just a command, we discard history.
            
            // My CommandProcessor returns "" for "scratch that".
            // So if processedText is empty, we effectively discarded the current utterance.
            // But did we WANT to discard history?
            // If the user said "Hello world scratch that", result is "".
            // If the user said "Scratch that", result is "".
            
            // Let's check the original text length vs command length roughly or just assume:
            // If the user said ONLY "scratch that", remove from history.
            let input = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if input == "scratch that" {
                history.removeMostRecent()
                statusText = NSLocalizedString("Scratch that", comment: "")
                return // Nothing to add
            } else {
                // We had some text that we scratched. Do not add anything.
                statusText = NSLocalizedString("Scratched", comment: "")
                return
            }
        }
        
        var finalText = processedText
        if finalText.isEmpty {
            statusText = NSLocalizedString("Ready", comment: "Status: Ready to dictate")
            liveTranscript = ""
            return
        }

        // 1. Apply Custom Vocabulary
        finalText = vocabularyManager.apply(to: finalText)
        
        // 2. Apply Profanity Filter
        if AppSettings.shared.profanityFilter {
             finalText = ProfanityFilter.filter(finalText)
        }
        
        history.add(finalText)
        let doneFormat = NSLocalizedString("Done: %@", comment: "Status: Transcription complete")
        statusText = String(format: doneFormat, finalText)
        liveTranscript = ""
        
        if AppSettings.shared.autoPaste {
             ClipboardManager.copyAndPaste(finalText)
        }
    }
}
