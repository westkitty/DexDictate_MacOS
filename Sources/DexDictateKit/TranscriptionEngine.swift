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

    public struct RouteHealthSnapshot: Equatable {
        public let activeInputLabel: String
        public let recoveryCount: Int
        public let lastRecoverySucceeded: Bool?
        public let isUsingSystemDefault: Bool
        public let detail: String
        public let updatedAt: Date

        public init(
            activeInputLabel: String,
            recoveryCount: Int,
            lastRecoverySucceeded: Bool?,
            isUsingSystemDefault: Bool,
            detail: String,
            updatedAt: Date
        ) {
            self.activeInputLabel = activeInputLabel
            self.recoveryCount = recoveryCount
            self.lastRecoverySucceeded = lastRecoverySucceeded
            self.isUsingSystemDefault = isUsingSystemDefault
            self.detail = detail
            self.updatedAt = updatedAt
        }
    }

    public struct PerformanceSnapshot: Equatable {
        public let captureStopMs: Int
        public let resampleMs: Int
        public let transcriptionMs: Int
        public let totalMs: Int
        public let createdAt: Date

        public init(
            captureStopMs: Int,
            resampleMs: Int,
            transcriptionMs: Int,
            totalMs: Int,
            createdAt: Date
        ) {
            self.captureStopMs = captureStopMs
            self.resampleMs = resampleMs
            self.transcriptionMs = transcriptionMs
            self.totalMs = totalMs
            self.createdAt = createdAt
        }
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
    @Published public private(set) var importedFileResult: ImportedFileTranscriptionResult?
    @Published public private(set) var lastDictationCompletionAt: Date?
    @Published public private(set) var routeHealthSnapshot = RouteHealthSnapshot(
        activeInputLabel: "System Default",
        recoveryCount: 0,
        lastRecoverySucceeded: nil,
        isUsingSystemDefault: true,
        detail: "Waiting for microphone activity.",
        updatedAt: Date()
    )
    @Published public private(set) var performanceSnapshot: PerformanceSnapshot?

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
    
    private var cancellables = Set<AnyCancellable>()
    private var lifecycle = EngineLifecycleStateMachine()
    private var lastCapturedUtterance: (samples: [Float], sampleRate: Double)?
    private var pendingImportedFileName: String?
    private var pendingOutputTargetApplication: OutputTargetApplication?
    private var pendingDictationDomain: DictationDomain = .general
    private var currentRecordingStartedAt: Date?
    private var recentCommittedOutputs: [String] = []
    private var automaticRetryOriginalText: String?

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
            self?.liveTranscript = text
        }

        audioService.onRouteRecoveryResult = { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let report):
                Safety.log(
                    "TranscriptionEngine — route recovery succeeded; finalDecision=\(report.finalDecisionDescription), retries=\(report.retryCount), usedSystemDefault=\(report.usedSystemDefault)",
                    category: .audio
                )
                self.recordRouteRecoverySuccess(report)
                if report.shouldClearStoredPreferredUID {
                    AppSettings.shared.inputDeviceUID = ""
                }
                guard self.state == .listening else {
                    Safety.log("TranscriptionEngine — route recovery completed while state=\(self.state); leaving UI untouched", category: .audio)
                    return
                }
                if report.usedSystemDefault {
                    self.statusText = report.recoveryNotice
                        ?? NSLocalizedString("Listening on System Default input.", comment: "Status: Fallback input")
                } else {
                    self.statusText = NSLocalizedString("Listening...", comment: "Status: Listening")
                }
            case .failure(let failure):
                Safety.log(
                    "TranscriptionEngine — route recovery failed; retries=\(failure.retryCount), error=\(failure.underlyingError)",
                    category: .audio
                )
                self.recordRouteRecoveryFailure(failure)
                if failure.shouldClearStoredPreferredUID {
                    AppSettings.shared.inputDeviceUID = ""
                }
                guard self.state == .listening else {
                    Safety.log("TranscriptionEngine — route recovery failure arrived after listening ended; ignoring ready-state reset", category: .audio)
                    return
                }
                self.silenceTimeoutTask?.cancel()
                self.silenceTimeoutTask = nil
                self.silenceCountdown = nil
                self.resultFeedback = .idle
                _ = self.applyLifecycle(.audioCaptureFailed, context: "routeRecoveryFailed")
                self.statusText = failure.recoveryNotice
                    ?? NSLocalizedString("Audio device changed. Ready to record.", comment: "Status: Route change")
                self.inputLevel = 0
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
        pendingImportedFileName = nil
        importedFileResult = nil
        pendingOutputTargetApplication = nil
        pendingDictationDomain = .general
        currentRecordingStartedAt = nil
        automaticRetryOriginalText = nil
        whisperService.setInitialPrompt(nil)
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
        let baseDelayMs = ExperimentFlags.stopTailDelayMs
        let recordingDurationMs = currentRecordingStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) }
        let stopDelayMs: UInt64
        if AppSettings.shared.adaptiveTailDelayEnabled {
            stopDelayMs = AdaptiveTailDelayHeuristic.resolvedDelayMs(
                baseDelayMs: baseDelayMs,
                recordingDurationMs: recordingDurationMs,
                recentOutputs: recentCommittedOutputs
            )
        } else {
            stopDelayMs = baseDelayMs
        }
        Safety.log("scheduleStop() — scheduling stop after \(stopDelayMs)ms (base=\(baseDelayMs)ms)")
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
        resultFeedback = .idle
        inputLevel = 0
        activityPhase = .listening
        pendingOutputTargetApplication = captureOutputTargetApplication()
        pendingDictationDomain = DictationDomainBias.resolvedDomain(
            mode: AppSettings.shared.dictationDomainMode,
            bundleIdentifier: pendingOutputTargetApplication?.bundleIdentifier
        )
        currentRecordingStartedAt = Date()
        automaticRetryOriginalText = nil

        if AppSettings.shared.playStartSound {
            SoundPlayer.play(AppSettings.shared.selectedStartSound)
        }

        // All AVAudioEngine operations (inputNode, prepare, start) run on AudioRecorderService's
        // internal audioQueue — fully off the main actor. The completion block fires back on
        // @MainActor so we can update state without re-entering the main thread.
        let uid = AppSettings.shared.inputDeviceUID
        audioService.startRecordingAsync(inputDeviceUID: uid) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                Safety.log("ERROR: startListening() — audio engine failed: \(error) — resetting state to .ready")
                let userFacingMessage = userFacingAudioStartFailureMessage(for: error)
                let desc = userFacingMessage.lowercased()
                if desc.contains("permission") || desc.contains("unauthorized") {
                    self.statusText = NSLocalizedString("Microphone access lost. Please check system preferences.", comment: "Status: Permission revoked during recording")
                    self.permissionManager?.refreshPermissions()
                } else {
                    self.statusText = userFacingMessage
                }
                self.resultFeedback = .idle
                self.pendingOutputTargetApplication = nil
                self.currentRecordingStartedAt = nil
                _ = self.applyLifecycle(.audioCaptureFailed, context: "audio start failure")
            case .success(let report):
                Safety.log(
                    "Audio engine started successfully — finalDecision=\(report.finalDecisionDescription), retries=\(report.retryCount), usedSystemDefault=\(report.usedSystemDefault)",
                    category: .audio
                )
                self.recordAudioStart(report)
                if report.shouldClearStoredPreferredUID {
                    AppSettings.shared.inputDeviceUID = ""
                }
                if report.usedSystemDefault {
                    self.statusText = report.recoveryNotice
                        ?? NSLocalizedString("Listening on System Default input.", comment: "Status: Fallback input")
                }
                Safety.log("Audio engine started successfully — accumulating audio until trigger release")
                self.startSilenceCountdownIfNeeded()
            }
        }
    }

    private func userFacingAudioStartFailureMessage(for error: Error) -> String {
        if let recoveryFailure = error as? AudioRecorderRecoveryFailure,
           let description = recoveryFailure.errorDescription,
           !description.isEmpty {
            return description
        }

        if case let DictationError.audioEngineSetupFailed(message) = error,
           message.contains("-10868")
                || message.contains("kAudioOutputUnitErr_InvalidDevice")
                || message.contains("coreaudio.avfaudio error -10868")
        {
            return "DexDictate could not open the microphone. If this keeps happening, restart macOS audio and try again."
        }

        return error.localizedDescription
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
        automaticRetryOriginalText = nil

        let (rawSamples, sourceSampleRate) = audioService.stopAndCollect()
        currentMetrics.t_audio_stop = Date()
        currentMetrics.raw_samples = rawSamples.count
        lastCapturedUtterance = (rawSamples, sourceSampleRate)
        activityPhase = .captured
        currentRecordingStartedAt = nil
        
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
        whisperService.setInitialPrompt(DictationDomainBias.initialPrompt(for: pendingDictationDomain))

        // Wire up result handler before calling transcribe.
        whisperService.ontranscriptionComplete = { [weak self] text in
            self?.currentMetrics.t_whisper_done = Date()
            self?.handleWhisperResult(text)
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
        pendingImportedFileName = url.lastPathComponent
        importedFileResult = nil
        pendingDictationDomain = .general
        automaticRetryOriginalText = nil
        whisperService.setInitialPrompt(DictationDomainBias.initialPrompt(for: .general))
        statusText = NSLocalizedString("Processing file...", comment: "Status: Processing audio file")
        activityPhase = .transcribing

        whisperService.ontranscriptionComplete = { [weak self] text in
            self?.handleWhisperResult(text)
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let (samples, sampleRate) = try AudioFileImporter.loadSamples(from: url)
                let whisperSamples = AudioResampler.resampleToWhisper(samples, fromRate: sampleRate)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.lastCapturedUtterance = (samples, sampleRate)
                    if !self.whisperService.transcribeImportedFile(audioFrames: whisperSamples) {
                        Safety.log("transcribeAudioFile() — Whisper refused transcription; resetting to ready state")
                        _ = self.applyLifecycle(.transcriptionCompleted, context: "whisper unavailable (file)")
                        self.statusText = NSLocalizedString("Ready", comment: "Status: Ready to dictate")
                        self.resultFeedback = .idle
                        self.activityPhase = .ready
                        self.pendingImportedFileName = nil
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
                    self.pendingImportedFileName = nil
                }
            }
        }
    }

    private func handleWhisperResult(_ text: String) {
        let importedFileName = pendingImportedFileName
        pendingImportedFileName = nil
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Safety.log("handleWhisperResult — \(trimmed.isEmpty ? "empty" : "\(trimmed.count) chars")")
        if trimmed.isEmpty {
            _ = applyLifecycle(.transcriptionCompleted, context: "empty whisper result")
            statusText = NSLocalizedString("Ready", comment: "Status: Ready to dictate")
            resultFeedback = .noSpeechDetected
            activityPhase = .ready
            lastDictationCompletionAt = Date()
            pendingOutputTargetApplication = nil
            automaticRetryOriginalText = nil
            whisperService.setInitialPrompt(nil)
        } else {
            if importedFileName == nil,
               automaticRetryOriginalText == nil,
               shouldAutomaticallyRetrySuspiciousResult(trimmed) {
                automaticRetryOriginalText = trimmed
                if startAutomaticAccuracyRetry(for: trimmed) {
                    return
                }
                automaticRetryOriginalText = nil
            }

            if let importedFileName {
                finalizeImportedFileTranscription(trimmed, fileName: importedFileName)
            } else {
                finalizeTranscription(trimmed, isAccuracyRetry: false, sourceHistoryItemID: nil)
            }
        }
    }


    
    /// Resolves the effective text insertion mode by checking per-app overrides first,
    /// then the global `useAccessibilityInsertion` setting.
    private func resolvedInsertionMode(for targetApplication: OutputTargetApplication?) -> InsertionModeOverride {
        let settings = AppSettings.shared
        let bundleID = targetApplication?.bundleIdentifier
            ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let bundleID,
           let perAppMode = appInsertionOverridesManager.effectiveMode(for: bundleID) {
            return perAppMode
        }
        return settings.useAccessibilityInsertion ? .accessibilityAPI : .clipboardPaste
    }

    private func finalizeTranscription(
        _ text: String,
        isAccuracyRetry: Bool,
        sourceHistoryItemID: UUID?,
        completesLifecycle: Bool = true
    ) {
        // Any path through this method completes the transcription cycle.
        // Without this, early returns (e.g. command-only utterances) can leave state
        // stuck at .transcribing and block the next trigger press.
        defer {
            pendingOutputTargetApplication = nil
            automaticRetryOriginalText = nil
            whisperService.setInitialPrompt(nil)
            if completesLifecycle {
                _ = applyLifecycle(.transcriptionCompleted, context: "finalizeTranscription")
            }
            emitMetricsCSV()
            activityPhase = .ready
            lastDictationCompletionAt = Date()
        }

        guard let preparedResult = prepareTranscriptionResult(from: text) else { return }

        let finalText = preparedResult.finalText
        let addedItem = history.add(
            finalText,
            sourceHistoryItemID: sourceHistoryItemID,
            isAccuracyRetry: isAccuracyRetry
        )
        if isAccuracyRetry {
            statusText = NSLocalizedString("Saved retried result", comment: "")
        } else {
            let doneFormat = NSLocalizedString("Done: %@", comment: "Status: Transcription complete")
            statusText = String(format: doneFormat, finalText)
        }
        liveTranscript = ""
        latestHistoryItem = addedItem
        recordCommittedOutput(finalText)
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
            insertionMode: resolvedInsertionMode(for: pendingOutputTargetApplication),
            targetApplication: pendingOutputTargetApplication
        )

        switch deliveryDecision.delivery {
        case .savedOnly:
            resultFeedback = .savedToHistory(modified: preparedResult.wasModified)
        case .pastedToActiveApp:
            resultFeedback = .pastedToActiveApp(modified: preparedResult.wasModified)
        case .copiedOnly(let reason):
            resultFeedback = .copiedOnlySensitiveContext(modified: preparedResult.wasModified, reason: reason)
        }
    }

    private func finalizeImportedFileTranscription(_ text: String, fileName: String) {
        defer {
            pendingOutputTargetApplication = nil
            automaticRetryOriginalText = nil
            whisperService.setInitialPrompt(nil)
            _ = applyLifecycle(.transcriptionCompleted, context: "finalizeImportedFileTranscription")
            emitMetricsCSV()
            activityPhase = .ready
            lastDictationCompletionAt = Date()
        }

        guard let preparedResult = prepareTranscriptionResult(from: text) else { return }

        let addedItem = history.add(preparedResult.finalText)
        statusText = String(format: NSLocalizedString("Imported %@", comment: "Status: Imported file name"), fileName)
        liveTranscript = ""
        latestHistoryItem = addedItem
        recordCommittedOutput(preparedResult.finalText)
        if let captured = lastCapturedUtterance {
            lastUtteranceSnapshot = LastUtteranceSnapshot(
                rawSamples: captured.samples,
                sourceSampleRate: captured.sampleRate,
                originalTranscript: preparedResult.finalText,
                sourceHistoryItemID: addedItem?.id
            )
        }
        importedFileResult = ImportedFileTranscriptionResult(
            fileName: fileName,
            transcript: preparedResult.finalText,
            createdAt: addedItem?.createdAt ?? Date(),
            wasModified: preparedResult.wasModified
        )
        resultFeedback = .savedToHistory(modified: preparedResult.wasModified)
    }

    private func captureOutputTargetApplication() -> OutputTargetApplication? {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier ?? "com.westkitty.dexdictate.macos"
        if let app = NSWorkspace.shared.frontmostApplication,
           let bundleIdentifier = app.bundleIdentifier,
           bundleIdentifier != ownBundleIdentifier {
            return OutputTargetApplication(
                bundleIdentifier: bundleIdentifier,
                processIdentifier: app.processIdentifier
            )
        }

        return ApplicationContextTracker.shared.recentOutputTargetApplication()
    }

    private struct PreparedTranscriptionResult {
        let finalText: String
        let wasModified: Bool
    }

    private func prepareTranscriptionResult(from text: String) -> PreparedTranscriptionResult? {
        let (processedText, command) = commandProcessor.process(
            text,
            customCommands: customCommandsManager.commands
        )

        if command == .deleteLastSentence {
            let input = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if input == "scratch that" {
                if history.removeMostRecent() != nil {
                    statusText = NSLocalizedString("Scratch that", comment: "")
                    resultFeedback = .deletedPreviousHistory
                } else {
                    statusText = NSLocalizedString("Nothing to remove", comment: "")
                    resultFeedback = .nothingToDelete
                }
                return nil
            }

            statusText = NSLocalizedString("Scratched", comment: "")
            resultFeedback = .discardedCurrentUtterance
            return nil
        }

        var finalText = processedText
        if finalText.isEmpty {
            statusText = NSLocalizedString("Ready", comment: "Status: Ready to dictate")
            liveTranscript = ""
            resultFeedback = .noSpeechDetected
            return nil
        }

        let preProcessingText = finalText
        finalText = vocabularyManager.applyEffective(
            to: finalText,
            additionalItems: DictationDomainBias.vocabularyItems(for: pendingDictationDomain)
        )
        if AppSettings.shared.profanityFilter {
            finalText = ProfanityFilter.filter(
                finalText,
                additions: AppSettings.shared.customProfanityWords,
                removals: AppSettings.shared.customProfanityRemovals
            )
        }

        return PreparedTranscriptionResult(
            finalText: finalText,
            wasModified: finalText != preProcessingText
        )
    }

    public func dismissImportedFileResult() {
        importedFileResult = nil
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
        automaticRetryOriginalText = nil

        whisperService.ensureModelLoaded(descriptor: descriptor)
        whisperService.setInitialPrompt(DictationDomainBias.initialPrompt(for: .general))
        let whisperSamples = AudioResampler.resampleToWhisper(snapshot.rawSamples, fromRate: snapshot.sourceSampleRate)

        whisperService.ontranscriptionComplete = { [weak self] text in
            self?.handleAccuracyRetryResult(
                text: text,
                sourceHistoryItemID: snapshot.sourceHistoryItemID
            )
        }

        activityPhase = .transcribing
        if !whisperService.transcribe(audioFrames: whisperSamples, decodeProfile: .accuracy) {
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

        finalizeTranscription(
            trimmed,
            isAccuracyRetry: true,
            sourceHistoryItemID: sourceHistoryItemID,
            completesLifecycle: false
        )
    }

    private func shouldAutomaticallyRetrySuspiciousResult(_ text: String) -> Bool {
        guard AppSettings.shared.enableAccuracyRetry,
              AppSettings.shared.autoRetrySuspiciousResults,
              let snapshot = lastCapturedUtterance else {
            return false
        }

        let audioDurationSeconds = Double(snapshot.samples.count) / snapshot.sampleRate
        guard let reason = SuspiciousTranscriptionHeuristic.reason(
            for: text,
            audioDurationSeconds: audioDurationSeconds
        ) else {
            return false
        }

        Safety.log("Automatic accuracy retry armed — reason=\(reason), duration=\(String(format: "%.2f", audioDurationSeconds))s", category: .transcription)
        return true
    }

    private func startAutomaticAccuracyRetry(for originalText: String) -> Bool {
        guard let snapshot = lastCapturedUtterance,
              let descriptor = WhisperModelCatalog.shared.activeDescriptor() else {
            return false
        }

        activityPhase = .retryingAccuracy
        statusText = NSLocalizedString("Retrying suspicious result...", comment: "Status: automatic retry")
        liveTranscript = NSLocalizedString("Running a focused retry...", comment: "Automatic retry progress")
        resultFeedback = .idle

        whisperService.ensureModelLoaded(descriptor: descriptor)
        whisperService.setInitialPrompt(DictationDomainBias.initialPrompt(for: pendingDictationDomain))
        let whisperSamples = AudioResampler.resampleToWhisper(snapshot.samples, fromRate: snapshot.sampleRate)
        currentMetrics.t_whisper_submit = Date()

        whisperService.ontranscriptionComplete = { [weak self] text in
            self?.currentMetrics.t_whisper_done = Date()
            self?.handleAutomaticAccuracyRetryResult(
                text: text,
                originalText: originalText
            )
        }

        activityPhase = .transcribing
        return whisperService.transcribe(audioFrames: whisperSamples, decodeProfile: .accuracy)
    }

    private func handleAutomaticAccuracyRetryResult(text: String, originalText: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Safety.log("Automatic accuracy retry returned empty output; keeping original transcription", category: .transcription)
            finalizeTranscription(originalText, isAccuracyRetry: false, sourceHistoryItemID: nil)
            return
        }

        finalizeTranscription(trimmed, isAccuracyRetry: true, sourceHistoryItemID: nil)
    }

    private func recordCommittedOutput(_ text: String) {
        recentCommittedOutputs.append(text)
        if recentCommittedOutputs.count > 8 {
            recentCommittedOutputs.removeFirst(recentCommittedOutputs.count - 8)
        }
    }

    private func recordAudioStart(_ report: AudioRecorderStartReport) {
        routeHealthSnapshot = RouteHealthSnapshot(
            activeInputLabel: labelForActiveInput(from: report),
            recoveryCount: routeHealthSnapshot.recoveryCount,
            lastRecoverySucceeded: routeHealthSnapshot.lastRecoverySucceeded,
            isUsingSystemDefault: report.usedSystemDefault,
            detail: report.recoveryNotice ?? "Input route is stable.",
            updatedAt: Date()
        )
    }

    private func recordRouteRecoverySuccess(_ report: AudioRecorderStartReport) {
        routeHealthSnapshot = RouteHealthSnapshot(
            activeInputLabel: labelForActiveInput(from: report),
            recoveryCount: routeHealthSnapshot.recoveryCount + 1,
            lastRecoverySucceeded: true,
            isUsingSystemDefault: report.usedSystemDefault,
            detail: report.recoveryNotice ?? "Recovered on the preferred input.",
            updatedAt: Date()
        )
    }

    private func recordRouteRecoveryFailure(_ failure: AudioRecorderRecoveryFailure) {
        routeHealthSnapshot = RouteHealthSnapshot(
            activeInputLabel: "Unavailable",
            recoveryCount: routeHealthSnapshot.recoveryCount + 1,
            lastRecoverySucceeded: false,
            isUsingSystemDefault: false,
            detail: failure.recoveryNotice ?? failure.localizedDescription,
            updatedAt: Date()
        )
    }

    private func labelForActiveInput(from report: AudioRecorderStartReport) -> String {
        if report.usedSystemDefault {
            return "System Default"
        }

        let knownDevices = AudioDeviceManager.inputDevices()
        return knownDevices.first(where: { $0.uid == report.activeInputUID })?.name
            ?? knownDevices.first(where: { $0.uid == report.requestedPreferredUID })?.name
            ?? (report.activeInputUID.isEmpty ? "Preferred Input" : report.activeInputUID)
    }

    private func emitMetricsCSV() {
        guard let t_up = currentMetrics.t_trigger_up,
              let t_aud = currentMetrics.t_audio_stop,
              let t_res = currentMetrics.t_resample_done,
              let t_sub = currentMetrics.t_whisper_submit,
              let t_done = currentMetrics.t_whisper_done else { return }
        let ms = { (d1: Date, d2: Date) -> Int in Int(d2.timeIntervalSince(d1) * 1000) }
        let captureStopMs = ms(t_up, t_aud)
        let resampleMs = ms(t_aud, t_res)
        let transcriptionMs = ms(t_sub, t_done)
        let totalMs = ms(t_up, t_done)
        let csv = "\(Date().timeIntervalSince1970),\(currentMetrics.raw_samples),\(currentMetrics.trim_samples),\(currentMetrics.resample_samples),\(captureStopMs),\(resampleMs),\(transcriptionMs),\(totalMs)"
        Safety.log("METRIC_CSV: \(csv)")
        performanceSnapshot = PerformanceSnapshot(
            captureStopMs: captureStopMs,
            resampleMs: resampleMs,
            transcriptionMs: transcriptionMs,
            totalMs: totalMs,
            createdAt: Date()
        )
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
