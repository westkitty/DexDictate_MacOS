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
    // canUndoLastDictation, recordDictationUndoIfNeeded, and undoLastDictation() live in
    // TranscriptionEngine+DictationUndo.swift.
    public var canRetryLastUtterance: Bool {
        AppSettings.shared.enableAccuracyRetry &&
        lastUtteranceSnapshot?.hasAudio == true &&
        state == .ready
    }

    private let audioService = AudioRecorderService()
    private let whisperService = WhisperService()
    /// Transcription provider architecture (Whisper, Apple Speech, and real implementations
    /// of Parakeet/Nemotron/Moonshine). See `TranscriptionProviderRegistry` for the fallback
    /// order Live Transcription uses, and `dispatchCommittedTranscription` for the order
    /// that decides which engine's text actually gets committed/pasted.
    public let transcriptionProviderRegistry: TranscriptionProviderRegistry
    /// Set for the duration of a listening session when a streaming provider (Apple Speech or
    /// Nemotron) is driving the live partial preview in `liveTranscript`. `nil` means the
    /// session is plain Whisper-only, identical to Live Transcription being off.
    private var activeLiveProviderID: TranscriptionProviderID?
    private let outputCoordinator: OutputCoordinating
    private let browserMediaController: BrowserMediaControlling
    private var activeBrowserMediaPauseSession: BrowserMediaPauseSession?
    public let vocabularyManager = VocabularyManager()
    private let commandProcessor = CommandProcessor()
    public let customCommandsManager = CustomCommandsManager()
    public let appInsertionOverridesManager = AppInsertionOverridesManager()
    // Not `private`: read/written from the TranscriptionEngine+DictationUndo.swift extension.
    let dictationUndoManager: DictationUndoPerforming = DictationUndoManager()

    /// Published mirror of `dictationUndoManager.availability`, so SwiftUI actually re-renders
    /// when undo is armed, cleared, retained, or invalidated — and so the disabled control can
    /// state *why*. The manager stays authoritative; this is only ever written by
    /// `syncUndoAvailability()` in TranscriptionEngine+DictationUndo.swift (hence
    /// `internal(set)`: read-only to the app target, writable inside the kit).
    @Published public internal(set) var undoAvailability: DictationUndoAvailability = .unavailable(.noDictationYet)

    /// Convenience view of the same published value — deliberately computed, so there is no
    /// second Boolean that could disagree with `undoAvailability`.
    public var canUndoLastDictation: Bool { undoAvailability.canUndo }

    /// When the last undo attempt was serviced. A second ⌃⌥⌘Z press that arrives while the
    /// first is still in flight finds no eligibility and would otherwise report "nothing to
    /// undo" *after* the successful undo, clobbering its confirmation — see
    /// `reportUndoUnavailableForShortcut(now:)`.
    /// Not `private`: written from the TranscriptionEngine+DictationUndo.swift extension.
    var lastUndoAttemptAt: Date?
    
    /// Global input monitor.
    private var inputMonitor: InputMonitor?

    /// Pending stop task (debounce).
    private var stopTask: Task<Void, Error>?

    /// Task managing the silence-timeout countdown.
    private var silenceTimeoutTask: Task<Void, Never>?

    private weak var permissionManager: PermissionManager?
    private var currentSessionId = UUID()
    // Not `private`: delivery completions are coordinated by TranscriptionEngine+DictationUndo.swift.
    var pendingDeliveryID: UUID?
    /// The focus snapshot belonging to the in-flight delivery. `pendingFocusSnapshot` is
    /// cleared by `finalizeTranscription`'s `defer`, which runs *before* an asynchronous paste
    /// verification completes — so a delivery verified after the fact had no snapshot left to
    /// arm undo with. This one survives until the next delivery cycle begins.
    var pendingDeliveryFocusSnapshot: FocusedElementSnapshot?
    
    /// Optional callback invoked on the main actor after each dictation event that
    /// warrants visible toast feedback. Wire this in the UI layer to drive `ToastState`.
    /// Matches the `onRouteRecoveryResult` pattern — non-blocking, fire-and-forget.
    public var onToast: ((ToastEvent) -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private var lifecycle = EngineLifecycleStateMachine()
    private var lastCapturedUtterance: (samples: [Float], sampleRate: Double)?
    private var pendingImportedFileName: String?
    private var pendingOutputTargetApplication: OutputTargetApplication?
    /// Snapshot of the focused AX element captured at trigger-down (recording start).
    /// Used to detect focus changes during transcription before committing paste.
    /// Not `private`: also read from the TranscriptionEngine+DictationUndo.swift extension.
    var pendingFocusSnapshot: FocusedElementSnapshot?
    private var pendingDictationDomain: DictationDomain = .general
    private var currentRecordingStartedAt: Date?
    private var recentCommittedOutputs: [String] = []
    private var automaticRetryOriginalText: String?

    /// True when a trigger press arrived while the engine was still busy (`.transcribing`)
    /// finishing the *previous* utterance. The event tap consumes the key/mouse event
    /// regardless of whether we act on it, so without this flag that press is silently
    /// dropped — the classic "first press after switching fields does nothing" symptom.
    /// Consumed automatically once the engine transitions back to `.ready`
    /// (see `applyLifecycle`). Hold-to-Talk cancels it on trigger-up if it hasn't fired yet,
    /// since a hold that was released before recording ever started shouldn't start one now.
    private var pendingStartRequest = false

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
             
    public init(
        outputCoordinator: OutputCoordinating = OutputCoordinator(),
        browserMediaController: BrowserMediaControlling = BrowserMediaPauseService(
            settingsProvider: { AppSettings.shared.pauseBrowserMediaDuringDictation }
        )
    ) {
        self.outputCoordinator = outputCoordinator
        self.browserMediaController = browserMediaController
        self.transcriptionProviderRegistry = TranscriptionProviderRegistry(whisperService: whisperService)
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
                self.resumeActiveBrowserMediaSession()
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
        // Whisper (local CoreML) is always the engine that produces the committed transcript.
        // When Live Transcription is on and Apple Speech is healthy, it additionally drives the
        // live partial preview — see TranscriptionProviderRegistry. Ask for its permission (if
        // undetermined) up front so the first dictation isn't mid-prompt.
        if AppSettings.shared.liveTranscriptionEnabled {
            transcriptionProviderRegistry.appleSpeechProvider.requestAuthorizationIfNeeded()
        }
        // Load any Nemotron/Parakeet/Moonshine models already downloaded from a prior
        // session — zero network activity. Without this, a fully-downloaded model reported
        // "downloaded but not loaded yet" forever, since load state lives in memory and
        // resets every launch while the files persist on disk. Detached from startSystem()'s
        // own completion — model loading can take a moment and must not delay input-monitor
        // setup (the trigger becoming responsive).
        let registry = transcriptionProviderRegistry
        let settings = AppSettings.shared
        Task {
            await registry.loadAlreadyDownloadedModelsIfNeeded(settings: settings)
        }
        setupInputMonitor()
        Safety.log("startSystem() complete — state=\(state)", category: .lifecycle)
    }

    public func stopSystem() {
        pendingStartRequest = false
        silenceTimeoutTask?.cancel()
        silenceTimeoutTask = nil
        silenceCountdown = nil
        resumeActiveBrowserMediaSession()
        inputMonitor?.stop()
        audioService.stopRecording()
        audioService.onRawAudioBuffer = nil
        activeStreamingProvider?.stopTranscription()
        transcriptionProviderRegistry.appleSpeechProvider.cancelTranscription()
        activeLiveProviderID = nil
        _ = applyLifecycle(.systemStopped, context: "stopSystem")
        statusText = NSLocalizedString("Idle", comment: "Status: Idle")
        liveTranscript = ""
        inputLevel = 0
        resultFeedback = .idle
        activityPhase = .idle
        pendingImportedFileName = nil
        importedFileResult = nil
        pendingOutputTargetApplication = nil
        pendingFocusSnapshot = nil
        pendingDictationDomain = .general
        currentRecordingStartedAt = nil
        automaticRetryOriginalText = nil
        whisperService.setInitialPrompt(nil)
        // Stopping the system invalidates the focus/AX context a pending undo depends on.
        disarmUndo(reason: .engineStopped)
    }

    public func rebuildAudioAfterCoreAudioReset() async -> Result<String, Error> {
        Safety.log("TranscriptionEngine — Core Audio reset postflight started, state=\(state)", category: .audio)
        let preferredUID = AppSettings.shared.inputDeviceUID

        if !preferredUID.isEmpty {
            let knownDevices = AudioDeviceManager.inputDevices()
            if !knownDevices.contains(where: { $0.uid == preferredUID }) {
                Safety.log(
                    "TranscriptionEngine — preferred input uid='\(preferredUID)' no longer exists after Core Audio reset; clearing stored selection",
                    category: .audio
                )
                AppSettings.shared.inputDeviceUID = ""
            }
        }

        guard state == .listening else {
            statusText = "Core Audio reset complete. Audio devices reloaded."
            Safety.log("TranscriptionEngine — Core Audio reset postflight complete; no active dictation engine to restart", category: .audio)
            return .success("Core Audio reset complete. Audio devices reloaded.")
        }

        silenceTimeoutTask?.cancel()
        silenceTimeoutTask = nil
        silenceCountdown = nil
        inputLevel = 0
        liveTranscript = ""
        statusText = "Restarting audio input..."

        return await withCheckedContinuation { continuation in
            audioService.rebuildAfterCoreAudioReset(preferredInputUID: AppSettings.shared.inputDeviceUID) { [weak self] result in
                guard let self else {
                    continuation.resume(returning: .success("Core Audio reset complete."))
                    return
                }

                switch result {
                case .success(let report):
                    if let report {
                        self.recordRouteRecoverySuccess(report)
                        if report.shouldClearStoredPreferredUID {
                            AppSettings.shared.inputDeviceUID = ""
                        }
                    }
                    self.statusText = "Core Audio reset complete. Audio input restarted."
                    self.startSilenceCountdownIfNeeded()
                    Safety.log("TranscriptionEngine — Core Audio reset postflight engine restart succeeded", category: .audio)
                    continuation.resume(returning: .success("Core Audio reset complete. Audio input restarted."))
                case .failure(let error):
                    self.resultFeedback = .idle
                    self.pendingOutputTargetApplication = nil
                    self.currentRecordingStartedAt = nil
                    self.resumeActiveBrowserMediaSession()
                    _ = self.applyLifecycle(.audioCaptureFailed, context: "coreAudioResetRestartFailure")
                    self.statusText = "Core Audio reset completed, but DexDictate could not restart audio input."
                    self.inputLevel = 0
                    Safety.log("TranscriptionEngine — Core Audio reset postflight engine restart failed: \(error)", category: .audio)
                    continuation.resume(returning: .failure(error))
                }
            }
        }
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
        } else if state == .ready {
            startListening()
        } else if state == .transcribing {
            // Engine is still finishing the previous utterance. Queue this press rather
            // than dropping it — a second tap here toggles the queued request back off.
            pendingStartRequest.toggle()
            Safety.log(
                "toggleListening() — engine busy (state=\(state)); pendingStartRequest=\(pendingStartRequest)",
                category: .lifecycle
            )
        }
    }

    public func handleTrigger(down: Bool) {
        if down {
            stopTask?.cancel()
            stopTask = nil
            currentSessionId = UUID()

            // reset metrics
            currentMetrics = MetricsSession()

            if state == .ready {
                resultFeedback = .idle
                startListening()
            } else if state == .transcribing {
                // Same race as toggleListening(): the previous utterance is still being
                // transcribed/pasted. Queue the start instead of swallowing the press —
                // it fires automatically once the engine reaches .ready (see applyLifecycle).
                Safety.log("handleTrigger(down: true) — engine busy (state=\(state)); queuing start", category: .lifecycle)
                pendingStartRequest = true
            }
        } else {
            // Hold-to-Talk: if the queued start above never got the chance to fire before
            // the user released the trigger, cancel it — a hold that ended before recording
            // ever began shouldn't start one now.
            pendingStartRequest = false
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
        beginDeliveryCycle()

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
        pendingFocusSnapshot = FocusedElementSnapshot.captureFromSystem()
        pendingDictationDomain = DictationDomainBias.resolvedDomain(
            mode: AppSettings.shared.dictationDomainMode,
            bundleIdentifier: pendingOutputTargetApplication?.bundleIdentifier
        )
        currentRecordingStartedAt = Date()
        automaticRetryOriginalText = nil

        // Re-request if the user missed or dismissed the one-shot prompt in startSystem() —
        // requestAuthorizationIfNeeded() is a no-op once authorization is anything other than
        // .notDetermined, so this is safe to call on every listen. It can't help *this*
        // session (the OS dialog is asynchronous; the user hasn't answered it yet), but means
        // the very next attempt already sees Apple Speech available instead of silently
        // falling back to Whisper-only forever because a passive launch-time prompt was easy
        // to miss and nothing ever asked again.
        if AppSettings.shared.liveTranscriptionEnabled {
            transcriptionProviderRegistry.appleSpeechProvider.requestAuthorizationIfNeeded()
        }

        let providerResolution = transcriptionProviderRegistry.resolveActiveProvider(
            liveTranscriptionEnabled: AppSettings.shared.liveTranscriptionEnabled
        )
        activeLiveProviderID = providerResolution.usesLiveStreaming ? providerResolution.selectedProviderID : nil
        startLiveProviderSessionIfNeeded()

        if AppSettings.shared.playStartSound {
            SoundPlayer.play(AppSettings.shared.selectedStartSound)
        }

        // Pause browser media, then start the audio engine. Both steps run on the
        // @MainActor Task (pauseIfNeeded is async; startRecordingAsync dispatches
        // internally to audioQueue so there's no blocking here).
        let uid = AppSettings.shared.inputDeviceUID
        let ctrl = browserMediaController
        Task { [weak self] in
            guard let self else { return }
            let session = await ctrl.pauseIfNeeded()
            self.activeBrowserMediaPauseSession = session
            // Guard: state may have changed while awaiting pause (e.g. stopSystem()).
            guard self.state == .listening else {
                if let session { await ctrl.resume(session: session) }
                self.activeBrowserMediaPauseSession = nil
                return
            }
            self.audioService.startRecordingAsync(inputDeviceUID: uid) { [weak self] result in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    Safety.log("ERROR: startListening() — audio engine failed: \(error) — resetting state to .ready")
                    let userFacingMessage = self.userFacingAudioStartFailureMessage(for: error)
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
                    self.resumeActiveBrowserMediaSession()
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
    }

    /// Returns the concrete streaming provider for `activeLiveProviderID`, if it's one that
    /// can actually drive the live preview (Apple Speech or Nemotron — both real, both
    /// `TranscriptionProvider & StreamingAudioReceiving`). `nil` for anything else (e.g. plain
    /// Whisper compatibility, or a provider that turned out unavailable).
    private var activeStreamingProvider: (any TranscriptionProvider & StreamingAudioReceiving)? {
        switch activeLiveProviderID {
        case .appleSpeech: return transcriptionProviderRegistry.appleSpeechProvider
        case .nemotron35ASRStreaming06B: return transcriptionProviderRegistry.nemotronProvider
        default: return nil
        }
    }

    /// Starts a live-preview streaming session on `activeLiveProviderID` if the resolver picked
    /// one for this listening session (Apple Speech or Nemotron). The Whisper batch pipeline
    /// below is unaffected either way: it still produces the committed transcript exactly as
    /// before this provider architecture existed.
    private func startLiveProviderSessionIfNeeded() {
        guard let provider = activeStreamingProvider else { return }
        let providerName = provider.displayName
        do {
            try provider.startTranscription()
            provider.onPartialResult = { [weak self] text in
                guard let self, self.state == .listening else { return }
                self.liveTranscript = text
            }
            provider.onFinalResult = nil
            provider.onError = { error in
                Safety.log("Live preview — \(providerName) error: \(error.localizedDescription)", category: .transcription)
            }
            audioService.onRawAudioBuffer = { [weak provider] buffer in
                provider?.appendAudioBuffer(buffer)
            }
            Safety.log("Live preview — \(providerName) session started", category: .transcription)
        } catch {
            activeLiveProviderID = nil
            Safety.log("Live preview — \(providerName) failed to start: \(error.localizedDescription)", category: .transcription)
        }
    }

    /// Tears down the live-preview session, if one is active, before the Whisper batch flow
    /// takes over to produce the committed transcript.
    private func stopLiveProviderSessionIfNeeded() {
        guard let provider = activeStreamingProvider else { return }
        audioService.onRawAudioBuffer = nil
        provider.stopTranscription()
        activeLiveProviderID = nil
    }

    private func resumeActiveBrowserMediaSession() {
        guard let session = activeBrowserMediaPauseSession else { return }
        activeBrowserMediaPauseSession = nil
        let ctrl = browserMediaController
        Task { await ctrl.resume(session: session) }
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

    /// Pure decision extracted for testability (no audio engine / timers involved).
    ///
    /// Hold-to-Talk's entire contract (stated verbatim in Settings: "records only while the
    /// trigger is pressed") is that the user controls start/stop by holding/releasing the
    /// key — a silence-based auto-stop firing while the key is still held silently breaks
    /// that contract mid-dictation (e.g. a natural pause to think or breathe stops the
    /// recording out from under the user, who is still holding the trigger). The Silence
    /// Timeout setting exists as a safety net specifically for Toggle mode, where there's no
    /// "release" gesture to end a forgotten recording — it must not also apply to
    /// Hold-to-Talk, where the trigger key itself is already that safety net.
    static func shouldRunSilenceCountdown(triggerMode: AppSettings.TriggerMode, timeout: Double) -> Bool {
        triggerMode != .holdToTalk && timeout > 0
    }

    private func startSilenceCountdownIfNeeded() {
        let timeout = AppSettings.shared.silenceTimeout
        guard Self.shouldRunSilenceCountdown(triggerMode: AppSettings.shared.triggerMode, timeout: timeout) else { return }
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
        stopLiveProviderSessionIfNeeded()

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

        // Immediate UI feedback to user that dictation was captured and is processing.
        self.liveTranscript = NSLocalizedString("Processing...", comment: "Status: Processing audio")

        // Capture session token before leaving the main actor so we can detect stale
        // sessions if the user starts a new recording while the worker is still running.
        let sessionId = self.currentSessionId
        let capturedRawCount = rawSamples.count

        // Snapshot the flags this worker needs on the main actor before dispatching.
        // ExperimentFlags' properties are plain `static var`s written from the main actor
        // (ExperimentFlags.applyRuntimeSettings, on a settings change) with no
        // synchronization — reading them directly from the detached task below would be a
        // genuine data race the moment a settings change lands mid-transcription.
        let enableSilenceTrim = ExperimentFlags.enableSilenceTrim
        let enableTrailingTrim = ExperimentFlags.enableTrailingTrim
        let trailingTrimMinimumSilenceMs = ExperimentFlags.trailingTrimMinimumSilenceMs
        let trailingTrimPadMs = ExperimentFlags.trailingTrimPadMs

        // 2. Move silence trimming and resampling off the main actor — these are
        //    CPU-heavy operations (10–50 ms) that don't need the main thread.
        Task.detached(priority: .userInitiated) { [weak self] in
            // ── Heavy work (off main actor) ──────────────────────────────────────
            var samplesToProcess = rawSamples
            if enableSilenceTrim {
                samplesToProcess = AudioResampler.trimSilenceFast(samplesToProcess, sampleRate: sourceSampleRate)
                if samplesToProcess.count != capturedRawCount {
                    let pct = Int((1.0 - Double(samplesToProcess.count) / Double(capturedRawCount)) * 100)
                    Safety.log("Silence trim: \(capturedRawCount) → \(samplesToProcess.count) samples (\(pct)% removed)")
                }
            }
            if enableTrailingTrim {
                samplesToProcess = AudioResampler.trimTrailingSilenceCalibrated(
                    samplesToProcess,
                    sampleRate: sourceSampleRate,
                    minimumSilenceMs: trailingTrimMinimumSilenceMs,
                    padMs: trailingTrimPadMs
                )
            }
            let trimSamples = samplesToProcess.count

            let whisperSamples = AudioResampler.resampleToWhisper(samplesToProcess, fromRate: sourceSampleRate)
            let tResampleDone = Date()

            // ── Return to main actor ─────────────────────────────────────────────
            await MainActor.run { [weak self] in
                guard let self else { return }
                // Stale session check: if the user started a new session while the
                // worker was running, discard this work.
                guard self.currentSessionId == sessionId else {
                    Safety.log("stopListening() detached worker: stale session, discarding resampled audio", category: .transcription)
                    return
                }

                // Write back timing fields captured in the worker.
                self.currentMetrics.trim_samples = trimSamples
                self.currentMetrics.resample_samples = whisperSamples.count
                self.currentMetrics.t_resample_done = tResampleDone

                Safety.log("Submitting \(whisperSamples.count) samples @ 16000 Hz for transcription")
                self.currentMetrics.t_whisper_submit = Date()
                self.activityPhase = .transcribing
                self.dispatchCommittedTranscription(samples: whisperSamples, sessionId: sessionId)
            }
        }
    }

    /// Duration under which a recording is eligible for Command Mode's Moonshine
    /// pre-check before falling through to the primary dictation engine.
    private static let commandModeMaxDurationSeconds: Double = 2.5

    /// Decides which engine produces the committed transcript for this utterance and kicks
    /// off transcription. Order: Moonshine (Command Mode, short utterances, recognized
    /// commands only) → Parakeet (if its model is downloaded and healthy) → Whisper (always
    /// available, never requires a download). Until a user explicitly downloads the Parakeet
    /// or Moonshine models, both health checks report unavailable and this is byte-identical
    /// to calling Whisper directly, as before this provider architecture existed.
    ///
    /// `sessionId` guards against a late-arriving result being committed/pasted after the
    /// user has already started a new recording (or the system was stopped) while Moonshine/
    /// Parakeet's async inference was still in flight — mirroring the stale-session check the
    /// resample worker above already does before calling this.
    private func dispatchCommittedTranscription(samples: [Float], sessionId: UUID) {
        let durationSeconds = Double(samples.count) / 16000.0
        let registry = transcriptionProviderRegistry

        guard AppSettings.shared.commandModeEnabled,
              durationSeconds < Self.commandModeMaxDurationSeconds,
              registry.moonshineProvider.healthCheck().isAvailable else {
            runPrimaryEngine(samples: samples, sessionId: sessionId)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await registry.moonshineProvider.transcribeBatch(samples: samples)
                guard self.currentSessionId == sessionId else {
                    Safety.log("Command Mode — stale session, discarding Moonshine result", category: .transcription)
                    return
                }
                if self.isRecognizedCommand(text) {
                    Safety.log("Command Mode — Moonshine recognized a command; skipping the primary engine", category: .transcription)
                    self.currentMetrics.t_whisper_done = Date()
                    self.handleTranscriptionResult(text)
                    return
                }
                Safety.log("Command Mode — Moonshine result wasn't a recognized command; continuing to primary engine", category: .transcription)
            } catch {
                Safety.log("Command Mode — Moonshine failed (\(error.localizedDescription)); continuing to primary engine", category: .transcription)
            }
            self.runPrimaryEngine(samples: samples, sessionId: sessionId)
        }
    }

    /// True if `CommandProcessor` would treat `text` as a command (built-in like "scratch
    /// that"/"new line"/"all caps", or a custom "Dex [keyword]" hot word) rather than as
    /// plain dictation content. Side-effect-free — `CommandProcessor.process` is pure text
    /// analysis; the real command action (e.g. removing the last history item) still runs
    /// exactly once, later, inside `prepareTranscriptionResult` via `handleTranscriptionResult`.
    private func isRecognizedCommand(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let (processedText, command) = commandProcessor.process(trimmed, customCommands: customCommandsManager.commands)
        return command != .none || processedText != trimmed
    }

    /// Primary dictation engine: Parakeet when its model is downloaded and healthy, otherwise
    /// Whisper — unless `AppSettings.preferredPrimaryEngineID` pins a specific choice (set by
    /// picking an entry in the unified model list). `sessionId` — see `dispatchCommittedTranscription`.
    private func runPrimaryEngine(samples: [Float], sessionId: UUID) {
        guard currentSessionId == sessionId else {
            Safety.log("runPrimaryEngine: stale session, discarding", category: .transcription)
            return
        }
        let registry = transcriptionProviderRegistry
        let pin = TranscriptionProviderID(rawValue: AppSettings.shared.preferredPrimaryEngineID)

        // Pinned explicitly to Whisper: skip Parakeet entirely, even if it's healthy.
        if pin == .whisperKit {
            runWhisperTranscription(samples: samples, sessionId: sessionId)
            return
        }

        // Auto (no pin) or pinned to Parakeet: use Parakeet if healthy, else Whisper.
        guard registry.parakeetProvider.healthCheck().isAvailable, pin == nil || pin == .parakeetTDT06Bv3 else {
            if pin == .parakeetTDT06Bv3 {
                Safety.log("Primary engine pinned to Parakeet but it's unavailable; falling back to Whisper", category: .transcription)
            }
            runWhisperTranscription(samples: samples, sessionId: sessionId)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await registry.parakeetProvider.transcribeBatch(samples: samples)
                guard self.currentSessionId == sessionId else {
                    Safety.log("Parakeet: stale session, discarding result", category: .transcription)
                    return
                }
                self.currentMetrics.t_whisper_done = Date()
                self.handleTranscriptionResult(text)
            } catch {
                Safety.log("Parakeet failed (\(error.localizedDescription)); falling back to Whisper", category: .transcription)
                guard self.currentSessionId == sessionId else {
                    Safety.log("Parakeet fallback: stale session, discarding", category: .transcription)
                    return
                }
                self.runWhisperTranscription(samples: samples, sessionId: sessionId)
            }
        }
    }

    /// DexDictate's original engine — always available, never requires a model download.
    ///
    /// `sessionId` closes a pre-existing gap (not introduced this session, but now inconsistent
    /// with the guard the Parakeet/Moonshine paths above have): `stopSystem()` doesn't cancel an
    /// in-flight Whisper transcription, so without this check a transcription that completes
    /// after the user force-stopped mid-utterance (or started a new recording before the old one
    /// resolved) would still commit/paste — the same class of bug fixed for Parakeet/Moonshine.
    private func runWhisperTranscription(samples: [Float], sessionId: UUID) {
        let domainBias = DictationDomainBias.initialPrompt(for: pendingDictationDomain)
        // Opt-in: prime Whisper with the text the user is currently editing (proper nouns,
        // sentence continuation), combined with the domain-bias vocabulary.
        let focusedContext = AppSettings.shared.enableContextInjection
            ? FocusedTextReader().readTail(maxChars: 200)
            : nil
        whisperService.setInitialPrompt(
            DictationContextPrompt.combine(domainBias: domainBias, focusedContext: focusedContext)
        )

        // Wire up result handler before calling transcribe.
        whisperService.ontranscriptionComplete = { [weak self] text in
            guard let self, self.currentSessionId == sessionId else {
                Safety.log("Whisper: stale session, discarding result", category: .transcription)
                return
            }
            self.currentMetrics.t_whisper_done = Date()
            self.handleTranscriptionResult(text)
        }

        if !whisperService.transcribe(audioFrames: samples) {
            Safety.log("stopListening() — Whisper refused transcription; resetting to ready state")
            statusText = NSLocalizedString("Ready", comment: "Status: Ready to dictate")
            liveTranscript = ""
            resultFeedback = .idle
            activityPhase = .ready
            resumeActiveBrowserMediaSession()
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
        beginDeliveryCycle()
        pendingImportedFileName = url.lastPathComponent
        importedFileResult = nil
        pendingDictationDomain = .general
        automaticRetryOriginalText = nil
        whisperService.setInitialPrompt(DictationDomainBias.initialPrompt(for: .general))
        statusText = NSLocalizedString("Processing file...", comment: "Status: Processing audio file")
        activityPhase = .transcribing

        whisperService.ontranscriptionComplete = { [weak self] text in
            self?.handleTranscriptionResult(text)
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

    private func handleTranscriptionResult(_ text: String) {
        let importedFileName = pendingImportedFileName
        pendingImportedFileName = nil
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Safety.log("handleTranscriptionResult — \(trimmed.isEmpty ? "empty" : "\(trimmed.count) chars")")
        if trimmed.isEmpty {
            resumeActiveBrowserMediaSession()
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
        sourceHistoryItemID: UUID?
    ) {
        // Any path through this method completes the transcription cycle.
        // Without this, early returns (e.g. command-only utterances) can leave state
        // stuck at .transcribing and block the next trigger press.
        defer {
            resumeActiveBrowserMediaSession()
            pendingOutputTargetApplication = nil
            pendingFocusSnapshot = nil
            automaticRetryOriginalText = nil
            whisperService.setInitialPrompt(nil)
            _ = applyLifecycle(.transcriptionCompleted, context: "finalizeTranscription")
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
        
        // Focus identity check: if the focused element changed meaningfully during
        // transcription, copy to clipboard instead of pasting into the wrong field.
        if AppSettings.shared.autoPaste, let triggerSnapshot = pendingFocusSnapshot {
            let currentSnapshot = FocusedElementSnapshot.captureFromSystem()
            if !FocusedElementIdentityMatcher.isSameContext(
                triggerSnapshot, currentSnapshot,
                targetBundleID: pendingOutputTargetApplication?.bundleIdentifier
            ) {
                Safety.log(
                    "TranscriptionEngine — paste aborted: focused element changed during transcription. Copying to clipboard.",
                    category: .output
                )
                let reason = "Focus changed during transcription."
                let delivery: OutputDelivery = ClipboardManager.copy(finalText)
                    ? .blocked(reason: reason + " Text was copied to the clipboard.")
                    : .failed(reason: reason + " Copying to the clipboard also failed.")
                applyDeliveryDecision(
                    OutputDeliveryDecision(delivery: delivery),
                    modified: preparedResult.wasModified
                )
                return
            }
        }

        let deliveryID = UUID()
        pendingDeliveryID = deliveryID
        pendingDeliveryFocusSnapshot = pendingFocusSnapshot
        let deliveryDecision = outputCoordinator.deliver(
            text: finalText,
            autoPaste: AppSettings.shared.autoPaste,
            protectSensitiveContexts: AppSettings.shared.copyOnlyInSensitiveFields,
            insertionMode: resolvedInsertionMode(for: pendingOutputTargetApplication),
            targetApplication: pendingOutputTargetApplication,
            completion: { [weak self] completedDecision in
                self?.applyDeliveryCompletion(
                    completedDecision,
                    deliveryID: deliveryID,
                    modified: preparedResult.wasModified
                )
            }
        )
        applyDeliveryDecision(
            deliveryDecision,
            modified: preparedResult.wasModified,
            awaitingVerification: true
        )
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
                    onToast?(.commandExecuted(name: "Scratch That"))
                } else {
                    statusText = NSLocalizedString("Nothing to remove", comment: "")
                    resultFeedback = .nothingToDelete
                }
                return nil
            }

            statusText = NSLocalizedString("Scratched", comment: "")
            resultFeedback = .discardedCurrentUtterance
            onToast?(.commandExecuted(name: "Scratch That"))
            return nil
        }

        // Detect "Dex [keyword]" custom command execution.
        // CommandProcessor returns .none for custom commands — infer from the raw text.
        if command == .none, !customCommandsManager.commands.isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let keyword = extractCustomCommandKeyword(from: trimmed) {
                onToast?(.customCommandExecuted(keyword: keyword))
            }
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

        // Bracket this path with the same lifecycle transition every other transcription
        // path uses. Without this, `state` stayed `.ready` for the whole manual retry —
        // bypassing the pendingStartRequest queue entirely, so a trigger press during a
        // retry started a brand-new recording concurrently, and both attempts raced for
        // the single whisperService.ontranscriptionComplete callback slot.
        guard applyLifecycle(.transcriptionStarted, context: "retryLastUtteranceInAccuracyMode") else {
            return
        }
        beginDeliveryCycle()

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
            _ = applyLifecycle(.transcriptionCompleted, context: "retryLastUtteranceInAccuracyMode failed to start")
        }
    }

    private func handleAccuracyRetryResult(text: String, sourceHistoryItemID: UUID?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusText = NSLocalizedString("Retry returned no speech", comment: "")
            liveTranscript = ""
            resultFeedback = .noSpeechDetected
            activityPhase = .ready
            _ = applyLifecycle(.transcriptionCompleted, context: "handleAccuracyRetryResult empty result")
            return
        }

        finalizeTranscription(
            trimmed,
            isAccuracyRetry: true,
            sourceHistoryItemID: sourceHistoryItemID
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

    /// Cached regex for `extractCustomCommandKeyword(from:)`. Compiled once at class load time.
    private static let customCommandRegex: NSRegularExpression? = try? NSRegularExpression(pattern: #"(?i)^dex\s+(.+)$"#)

    /// Returns the keyword portion of a "Dex [keyword]" utterance if it matches a
    /// registered custom command, otherwise `nil`. Used to emit `.customCommandExecuted`
    /// toast events without changing `CommandProcessor`'s return type.
    private func extractCustomCommandKeyword(from text: String) -> String? {
        guard let regex = TranscriptionEngine.customCommandRegex,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let keyword = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard customCommandsManager.commands.contains(where: { $0.keyword.lowercased() == keyword }) else {
            return nil
        }
        return keyword
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

        if transition.to == .ready, pendingStartRequest {
            pendingStartRequest = false
            Safety.log("applyLifecycle — replaying trigger press that arrived while engine was busy (\(context))", category: .lifecycle)
            startListening()
        }

        return true
    }
}
