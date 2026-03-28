import SwiftUI
import AVFoundation
import AudioToolbox
import Combine

/// The central coordinator for the speech-recognition pipeline.
@MainActor
public final class TranscriptionEngine: ObservableObject {
    public enum ActivityPhase: Equatable {
        case idle
        case ready
        case listening
        case captured
        case resampling
        case transcribing
        case retryingAccuracy
    }

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
    @Published public var resultFeedback: TranscriptionFeedback = .idle
    @Published public private(set) var activityPhase: ActivityPhase = .idle
    @Published public private(set) var lastUtteranceSnapshot: LastUtteranceSnapshot?
    @Published public private(set) var latestHistoryItem: HistoryItem?
    @Published public private(set) var lastDictationCompletionAt: Date?

    /// Seconds remaining until auto-stop due to silence; `nil` when inactive.
    @Published public private(set) var silenceCountdown: Double? = nil

    public var canUndoLastHistoryRemoval: Bool { history.canRestoreLastRemovedItem }
    public var canRetryLastUtterance: Bool {
        AppSettings.shared.enableAccuracyRetry &&
        lastUtteranceSnapshot?.hasAudio == true &&
        state == .ready
    }

    private let audioService = AudioRecorderService()
    private let whisperService = WhisperService()
    private let outputCoordinator: OutputCoordinating
    public let vocabularyManager = VocabularyManager()
    private let commandProcessor = CommandProcessor()
    public let customCommandsManager = CustomCommandsManager()
    public let appInsertionOverridesManager = AppInsertionOverridesManager()
    
    /// Global input monitor.
    private var inputMonitor: InputMonitor?

    /// Pending stop task (debounce).
    private var stopTask: Task<Void, Error>?

    /// Task managing the silence-timeout countdown.
    private var silenceTimeoutTask: Task<Void, Never>?

    private weak var permissionManager: PermissionManager?
    private var currentSessionId = UUID()
    
    private var recognitionTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    private var lifecycle = EngineLifecycleStateMachine()
    private var lastCapturedUtterance: (samples: [Float], sampleRate: Double)?

    // MARK: - Metrics
    private struct MetricsSession {
        var t_trigger_up: Date?
        var t_audio_stop: Date?
        var t_resample_done: Date?
        var t_whisper_submit: Date?
        var t_whisper_done: Date?
        
        var raw_samples: Int = 0
        var trim_samples: Int = 0
        var resample_samples: Int = 0
    }
    private var currentMetrics = MetricsSession()

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
             
    public init(outputCoordinator: OutputCoordinating = OutputCoordinator()) {
        self.outputCoordinator = outputCoordinator
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
        guard applyLifecycle(.startSystemRequested, context: "startSystem") else {
            Safety.log("startSystem() skipped — already running (state=\(state))", category: .lifecycle)
            return
        }
        Safety.log("startSystem() called — setting up input monitor", category: .lifecycle)
        statusText = NSLocalizedString("Requesting Access...", comment: "Status: Requesting permissions")
        // DexDictate uses Whisper (local CoreML) exclusively — no Apple Speech Recognition.
        setupInputMonitor()
        Safety.log("startSystem() complete — state=\(state)", category: .lifecycle)
    }

    public func stopSystem() {
        silenceTimeoutTask?.cancel()
        silenceTimeoutTask = nil
        silenceCountdown = nil
        inputMonitor?.stop()
        audioService.stopRecording()
        _ = applyLifecycle(.systemStopped, context: "stopSystem")
        statusText = NSLocalizedString("Idle", comment: "Status: Idle")
        liveTranscript = ""
        inputLevel = 0
        resultFeedback = .idle
        activityPhase = .idle
    }
    
    /// True once the Whisper model has been successfully loaded into memory.
    /// Used by `.onAppear` to skip redundant 74 MB model reloads when the engine
    /// is stopped and restarted (e.g. user clicks "Stop Dictation" then opens the menu again).
    public var isModelLoaded: Bool { whisperService.isModelLoaded }

    public func loadWhisperModel(url: URL) {
        whisperService.loadModel(url: url)
    }

    public func loadWhisperModel(
        descriptor: WhisperModelDescriptor,
        decodeProfile: ExperimentFlags.DecodeProfile? = nil
    ) {
        whisperService.ensureModelLoaded(descriptor: descriptor, decodeProfile: decodeProfile)
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

    func handleInputMonitorFailure() {
        guard applyLifecycle(.inputMonitorFailed, context: "input monitor failure") else {
            return
        }

        statusText = "Grant Accessibility Permission"
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
            
            // reset metrics
            currentMetrics = MetricsSession()

            if state != .listening {
                resultFeedback = .idle
                startListening()
            }
        } else {
            currentMetrics.t_trigger_up = Date()
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
            _ = applyLifecycle(.inputMonitorActivated, context: "input monitor active")
            statusText = NSLocalizedString("Ready", comment: "Status: Ready")
            activityPhase = .ready
        }
        // If tap failed, state stays .initializing until the InputMonitor Task sets .error.
    }

    private func scheduleStop() {
        // Keep a short tail to avoid clipping final phonemes while minimizing perceived latency.
        let stopDelayMs: UInt64 = ExperimentFlags.stopTailDelayMs
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

        guard applyLifecycle(.listeningStarted, context: "startListening") else {
            Safety.log("startListening() BLOCKED — lifecycle rejected listening start from \(state)", category: .lifecycle)
            return
        }
        statusText = NSLocalizedString("Listening...", comment: "Status: Listening")
        liveTranscript = ""
        inputLevel = 0
        activityPhase = .listening

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
                _ = self.applyLifecycle(.audioCaptureFailed, context: "audio start failure")
            } else {
                Safety.log("Audio engine started successfully — accumulating audio until trigger release")
                self.startSilenceCountdownIfNeeded()
            }
        }
    }

    private func startSilenceCountdownIfNeeded() {
        let timeout = AppSettings.shared.silenceTimeout
        guard timeout > 0 else { return }
        silenceTimeoutTask?.cancel()
        silenceCountdown = timeout
        let tickInterval: Double = 0.25
        silenceTimeoutTask = Task { @MainActor [weak self] in
            var remaining = timeout
            while remaining > 0 {
                do {
                    try await Task.sleep(nanoseconds: UInt64(tickInterval * 1_000_000_000))
                } catch {
                    break
                }
                guard let self, !Task.isCancelled else { break }
                if self.inputLevel > 0.01 {
                    remaining = timeout
                } else {
                    remaining -= tickInterval
                }
                self.silenceCountdown = max(0, remaining)
            }
            guard let self, !Task.isCancelled, self.state == .listening else { return }
            self.silenceCountdown = nil
            self.stopListening()
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
        guard applyLifecycle(.transcriptionStarted, context: "stopListening") else {
            Safety.log("stopListening() BLOCKED — lifecycle rejected transcription start from \(state)", category: .lifecycle)
            return
        }
        silenceTimeoutTask?.cancel()
        silenceTimeoutTask = nil
        silenceCountdown = nil
        statusText = NSLocalizedString("Transcribing...", comment: "Status: Transcribing")
        inputLevel = 0

        // 1. Stop the audio engine and atomically collect the full utterance buffer.
        // stopAndCollect() runs on audioQueue.sync — safe from @MainActor because
        // audioQueue never dispatches back to main synchronously.
        recognitionTask?.cancel()
        recognitionTask = nil

        let (rawSamples, sourceSampleRate) = audioService.stopAndCollect()
        currentMetrics.t_audio_stop = Date()
        currentMetrics.raw_samples = rawSamples.count
        lastCapturedUtterance = (rawSamples, sourceSampleRate)
        activityPhase = .captured
        
        Safety.log("stopListening() — collected \(rawSamples.count) samples @ \(sourceSampleRate) Hz")

        if AppSettings.shared.playStopSound {
            SoundPlayer.play(AppSettings.shared.selectedStopSound)
        }

        var samplesToProcess = rawSamples
        if ExperimentFlags.enableSilenceTrim {
            samplesToProcess = AudioResampler.trimSilenceFast(samplesToProcess, sampleRate: sourceSampleRate)
            if samplesToProcess.count != rawSamples.count {
                let pct = Int((1.0 - Double(samplesToProcess.count) / Double(rawSamples.count)) * 100)
                Safety.log("Silence trim: \(rawSamples.count) → \(samplesToProcess.count) samples (\(pct)% removed)")
            }
        }
        if ExperimentFlags.enableTrailingTrim {
            samplesToProcess = AudioResampler.trimTrailingSilenceCalibrated(
                samplesToProcess,
                sampleRate: sourceSampleRate,
                minimumSilenceMs: ExperimentFlags.trailingTrimMinimumSilenceMs,
                padMs: ExperimentFlags.trailingTrimPadMs
            )
        }
        currentMetrics.trim_samples = samplesToProcess.count
        
        // Immediate UI feedback to user that dictation was captured and is processing.
        self.liveTranscript = NSLocalizedString("Processing...", comment: "Status: Processing audio")

        // 2. Resample to 16 kHz (Whisper's required sample rate) and submit once.
        activityPhase = .resampling
        let whisperSamples = AudioResampler.resampleToWhisper(samplesToProcess, fromRate: sourceSampleRate)
        currentMetrics.t_resample_done = Date()
        currentMetrics.resample_samples = whisperSamples.count
        
        Safety.log("Submitting \(whisperSamples.count) samples @ 16000 Hz to Whisper")

        // Wire up result handler before calling transcribe.
        whisperService.ontranscriptionComplete = { [weak self] text in
            Task { @MainActor in
                self?.currentMetrics.t_whisper_done = Date()
                self?.handleWhisperResult(text)
            }
        }
        
        currentMetrics.t_whisper_submit = Date()
        activityPhase = .transcribing
        if !whisperService.transcribe(audioFrames: whisperSamples) {
            Safety.log("stopListening() — Whisper refused transcription; resetting to ready state")
            statusText = NSLocalizedString("Ready", comment: "Status: Ready to dictate")
            liveTranscript = ""
            resultFeedback = .idle
            activityPhase = .ready
            _ = applyLifecycle(.transcriptionCompleted, context: "whisper unavailable")
        }
    }

    /// Called by WhisperService when the single-batch transcription completes.
    /// Transcribes an audio file from disk, routing the result through the normal
    /// post-processing and output pipeline (commands, vocab, history, paste).
    public func transcribeAudioFile(url: URL) {
        guard state == .ready else {
            Safety.log("transcribeAudioFile() skipped — state is \(state), must be .ready")
            return
        }
        guard applyLifecycle(.transcriptionStarted, context: "transcribeAudioFile") else { return }
        statusText = NSLocalizedString("Processing file...", comment: "Status: Processing audio file")
        activityPhase = .transcribing

        whisperService.ontranscriptionComplete = { [weak self] text in
            Task { @MainActor [weak self] in
                self?.handleWhisperResult(text)
            }
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let (samples, sampleRate) = try AudioFileImporter.loadSamples(from: url)
                let whisperSamples = AudioResampler.resampleToWhisper(samples, fromRate: sampleRate)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if !self.whisperService.transcribe(audioFrames: whisperSamples) {
                        Safety.log("transcribeAudioFile() — Whisper refused transcription; resetting to ready state")
                        _ = self.applyLifecycle(.transcriptionCompleted, context: "whisper unavailable (file)")
                        self.statusText = NSLocalizedString("Ready", comment: "Status: Ready to dictate")
                        self.resultFeedback = .idle
                        self.activityPhase = .ready
                    }
                }
            } catch {
                let errorMessage = error.localizedDescription
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    _ = self.applyLifecycle(.transcriptionCompleted, context: "audio file import error")
                    self.statusText = errorMessage
                    self.resultFeedback = .idle
                    self.activityPhase = .ready
                }
            }
        }
    }

    private func handleWhisperResult(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Safety.log("handleWhisperResult — \(trimmed.isEmpty ? "empty" : "\(trimmed.count) chars")")
        if trimmed.isEmpty {
            _ = applyLifecycle(.transcriptionCompleted, context: "empty whisper result")
            statusText = NSLocalizedString("Ready", comment: "Status: Ready to dictate")
            resultFeedback = .noSpeechDetected
            activityPhase = .ready
            lastDictationCompletionAt = Date()
        } else {
            finalizeTranscription(trimmed)
        }
    }


    
    /// Resolves the effective text insertion mode by checking per-app overrides first,
    /// then the global `useAccessibilityInsertion` setting.
    private func resolvedInsertionMode() -> InsertionModeOverride {
        let settings = AppSettings.shared
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           let perAppMode = appInsertionOverridesManager.effectiveMode(for: bundleID) {
            return perAppMode
        }
        return settings.useAccessibilityInsertion ? .accessibilityAPI : .clipboardPaste
    }

    private func finalizeTranscription(_ text: String) {
        // Any path through this method completes the transcription cycle.
        // Without this, early returns (e.g. command-only utterances) can leave state
        // stuck at .transcribing and block the next trigger press.
        defer {
            _ = applyLifecycle(.transcriptionCompleted, context: "finalizeTranscription")
            emitMetricsCSV()
            activityPhase = .ready
            lastDictationCompletionAt = Date()
        }

        // 0. Process Commands (built-in + user-defined hot-word commands)
        let (processedText, command) = commandProcessor.process(text, customCommands: customCommandsManager.commands)
        
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
                if history.removeMostRecent() != nil {
                    statusText = NSLocalizedString("Scratch that", comment: "")
                    resultFeedback = .deletedPreviousHistory
                } else {
                    statusText = NSLocalizedString("Nothing to remove", comment: "")
                    resultFeedback = .nothingToDelete
                }
                return // Nothing to add
            } else {
                // We had some text that we scratched. Do not add anything.
                statusText = NSLocalizedString("Scratched", comment: "")
                resultFeedback = .discardedCurrentUtterance
                return
            }
        }
        
        var finalText = processedText
        if finalText.isEmpty {
            statusText = NSLocalizedString("Ready", comment: "Status: Ready to dictate")
            liveTranscript = ""
            resultFeedback = .noSpeechDetected
            return
        }

        // 1. Apply Effective Vocabulary (bundled mode vocabulary + user custom vocabulary)
        let preProcessingText = finalText
        finalText = vocabularyManager.applyEffective(to: finalText)
        
        // 2. Apply Profanity Filter
        if AppSettings.shared.profanityFilter {
            finalText = ProfanityFilter.filter(
                finalText,
                additions: AppSettings.shared.customProfanityWords,
                removals: AppSettings.shared.customProfanityRemovals
            )
        }
        let wasModified = finalText != preProcessingText
        
        let addedItem = history.add(finalText)
        let doneFormat = NSLocalizedString("Done: %@", comment: "Status: Transcription complete")
        statusText = String(format: doneFormat, finalText)
        liveTranscript = ""
        latestHistoryItem = addedItem
        if let captured = lastCapturedUtterance {
            lastUtteranceSnapshot = LastUtteranceSnapshot(
                rawSamples: captured.samples,
                sourceSampleRate: captured.sampleRate,
                originalTranscript: finalText,
                sourceHistoryItemID: addedItem?.id
            )
        }
        
        let deliveryDecision = outputCoordinator.deliver(
            text: finalText,
            autoPaste: AppSettings.shared.autoPaste,
            protectSensitiveContexts: AppSettings.shared.copyOnlyInSensitiveFields,
            insertionMode: resolvedInsertionMode()
        )

        switch deliveryDecision.delivery {
        case .savedOnly:
            resultFeedback = .savedToHistory(modified: wasModified)
        case .pastedToActiveApp:
            resultFeedback = .pastedToActiveApp(modified: wasModified)
        case .copiedOnly(let reason):
            resultFeedback = .copiedOnlySensitiveContext(modified: wasModified, reason: reason)
        }
    }

    public func undoLastHistoryRemoval() {
        guard history.restoreMostRecentRemoval() else {
            statusText = NSLocalizedString("Nothing to restore", comment: "")
            resultFeedback = .nothingToDelete
            return
        }

        statusText = NSLocalizedString("Restored previous entry", comment: "")
        resultFeedback = .restoredPreviousHistory
    }

    public func retryLastUtteranceInAccuracyMode() {
        guard canRetryLastUtterance,
              let snapshot = lastUtteranceSnapshot,
              let descriptor = WhisperModelCatalog.shared.activeDescriptor() else {
            return
        }

        activityPhase = .retryingAccuracy
        statusText = NSLocalizedString("Retrying last utterance...", comment: "Status: retrying last utterance")
        liveTranscript = NSLocalizedString("Retrying in accuracy mode...", comment: "Retry progress")
        resultFeedback = .idle

        whisperService.ensureModelLoaded(descriptor: descriptor, decodeProfile: .accuracy)
        let whisperSamples = AudioResampler.resampleToWhisper(snapshot.rawSamples, fromRate: snapshot.sourceSampleRate)

        whisperService.ontranscriptionComplete = { [weak self] text in
            Task { @MainActor in
                self?.handleAccuracyRetryResult(
                    text: text,
                    sourceHistoryItemID: snapshot.sourceHistoryItemID
                )
            }
        }

        activityPhase = .transcribing
        if !whisperService.transcribe(audioFrames: whisperSamples) {
            statusText = NSLocalizedString("Retry unavailable", comment: "")
            liveTranscript = ""
            activityPhase = .ready
        }
    }

    private func handleAccuracyRetryResult(text: String, sourceHistoryItemID: UUID?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusText = NSLocalizedString("Retry returned no speech", comment: "")
            liveTranscript = ""
            resultFeedback = .noSpeechDetected
            activityPhase = .ready
            return
        }

        var finalText = vocabularyManager.applyEffective(to: trimmed)
        if AppSettings.shared.profanityFilter {
            finalText = ProfanityFilter.filter(
                finalText,
                additions: AppSettings.shared.customProfanityWords,
                removals: AppSettings.shared.customProfanityRemovals
            )
        }

        latestHistoryItem = history.add(
            finalText,
            sourceHistoryItemID: sourceHistoryItemID,
            isAccuracyRetry: true
        )
        if let snapshot = lastUtteranceSnapshot {
            lastUtteranceSnapshot = LastUtteranceSnapshot(
                rawSamples: snapshot.rawSamples,
                sourceSampleRate: snapshot.sourceSampleRate,
                originalTranscript: finalText,
                sourceHistoryItemID: latestHistoryItem?.id
            )
        }
        statusText = NSLocalizedString("Saved retried result", comment: "")
        liveTranscript = ""
        resultFeedback = .savedToHistory(modified: finalText != trimmed)
        activityPhase = .ready
        lastDictationCompletionAt = Date()
    }

    private func emitMetricsCSV() {
        guard let t_up = currentMetrics.t_trigger_up,
              let t_aud = currentMetrics.t_audio_stop,
              let t_res = currentMetrics.t_resample_done,
              let t_sub = currentMetrics.t_whisper_submit,
              let t_done = currentMetrics.t_whisper_done else { return }
        let ms = { (d1: Date, d2: Date) -> Int in Int(d2.timeIntervalSince(d1) * 1000) }
        let csv = "\(Date().timeIntervalSince1970),\(currentMetrics.raw_samples),\(currentMetrics.trim_samples),\(currentMetrics.resample_samples),\(ms(t_up, t_aud)),\(ms(t_aud, t_res)),\(ms(t_sub, t_done)),\(ms(t_up, t_done))"
        Safety.log("METRIC_CSV: \(csv)")
    }

    @discardableResult
    private func applyLifecycle(_ event: EngineLifecycleEvent, context: String) -> Bool {
        guard let transition = lifecycle.apply(event) else {
            Safety.log("Lifecycle rejected event \(event.rawValue) from state \(state.rawValue) (\(context))", category: .lifecycle)
            return false
        }

        state = transition.to
        Safety.log("Lifecycle transition \(transition.from.rawValue) --\(event.rawValue)--> \(transition.to.rawValue) (\(context))", category: .lifecycle)
        return true
    }
}
