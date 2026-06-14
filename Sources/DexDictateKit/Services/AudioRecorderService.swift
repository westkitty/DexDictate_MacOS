import AppKit
import AVFoundation
import CoreAudio

// MARK: - Core Audio default-device callback (file-scope C-style function)

/// Fires on an arbitrary Core Audio thread whenever the system default input device changes.
/// MUST return immediately — no heavyweight work allowed here.
private let defaultInputDeviceListenerProc: AudioObjectPropertyListenerProc = { _, _, _, context in
    guard let context else { return noErr }
    let service = Unmanaged<AudioRecorderService>.fromOpaque(context).takeUnretainedValue()
    Safety.log("CoreAudio: kAudioHardwarePropertyDefaultInputDevice changed — scheduling recovery", category: .audio)
    service.audioQueue.async { [weak service] in
        service?.handleEngineConfigurationChange()
    }
    return noErr
}

/// Service responsible for managing the audio engine and microphone input.
///
/// Threading model (community-established; Apple does not formally document this):
///   - ALL AVAudioEngine operations run on `audioQueue`, a dedicated serial DispatchQueue.
///     This includes: inputNode access, outputFormat queries, installTap, prepare, and start.
///     There is no documented main-thread requirement for any of these. The only callback
///     that is guaranteed off-main is the tap block itself (fires on the AVAudioEngine
///     internal audio thread).
///   - `audioQueue` is serial — operations are never concurrent, which is the key safety
///     property. Route-change recovery must also go through this queue.
///   - `bufferQueue` protects `_accumulatedSamples` between the tap callback thread and
///     the main thread (collectRecording).
///   - UI-visible state (@Published) is always updated on the main actor via `MainActorDispatch`.
public final class AudioRecorderService: ObservableObject {
    // nonisolated(unsafe): engine is accessed exclusively on audioQueue.
    // The compiler can't verify this statically, so we assert it manually.
    nonisolated(unsafe) private let engine = AVAudioEngine()

    @MainActor @Published public var inputLevel: Double = 0

    /// All engine lifecycle operations run on this serial queue.
    /// `fileprivate` (not `private`) so the file-scope Core Audio callback can dispatch onto it.
    fileprivate let audioQueue = DispatchQueue(label: "com.dexdictate.audioEngine", qos: .userInitiated)

    /// Called on the main actor when AVAudioEngine stops itself due to a hardware
    /// configuration change and recovery ultimately fails.
    @MainActor public var onEngineInterrupted: (() -> Void)?

    /// Called on the main actor when a hardware-route recovery attempt succeeds or fails.
    @MainActor public var onRouteRecoveryResult: ((Result<AudioRecorderStartReport, AudioRecorderRecoveryFailure>) -> Void)?

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var configChangeObserver: NSObjectProtocol?

    /// Tracks whether the Core Audio default-input-device listener is currently registered.
    /// Guarded by the Swift runtime (set once in init, read/cleared in deinit).
    /// Exposed internally so tests can verify single-registration invariant.
    #if DEBUG
    internal private(set) var isDefaultDeviceListenerRegistered = false
    #else
    private var isDefaultDeviceListenerRegistered = false
    #endif

    // Accessed only on audioQueue.
    nonisolated(unsafe) private var isCaptureSessionActive = false
    nonisolated(unsafe) private var activePreferredInputUID = ""
    nonisolated(unsafe) private var activeInputUID = ""
    /// True while `handleEngineConfigurationChange()` is executing on audioQueue.
    /// Prevents a second concurrent route-change event from re-entering recovery
    /// while the first is still in progress (the two events that always fire together —
    /// the HAL listener and AVAudioEngineConfigurationChange — would otherwise both
    /// attempt to install a tap, causing an NSException from AVAudioEngine).
    nonisolated(unsafe) private var isHandlingConfigChange = false
    /// True between a successful `installTap` call and the matching `removeTap`.
    /// Guards against calling `installTap` while a tap is already installed, which
    /// throws an uncatchable NSException.
    nonisolated(unsafe) private var isTapInstalled = false

    private let preferredInputRetryDelays: [TimeInterval] = [0, 0.2, 0.5, 1.0]

    public init() {
        setupSleepWakeNotifications()
        setupEngineConfigChangeObserver()
        setupDefaultDeviceListener()
    }

    deinit {
        if let obs = sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
        if let obs = wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
        if let obs = configChangeObserver { NotificationCenter.default.removeObserver(obs) }
        teardownDefaultDeviceListener()
    }

    private func setupSleepWakeNotifications() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.audioQueue.async { [weak self] in
                guard let self else { return }
                self.teardownEngineUnsafe()
                self.isCaptureSessionActive = false
                self.activePreferredInputUID = ""
                self.activeInputUID = ""
                MainActorDispatch.async { [weak self] in
                    self?.inputLevel = 0
                }
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: nil
        ) { _ in /* engine will be restarted on next recording attempt */ }
    }

    /// Observes AVAudioEngineConfigurationChange, which fires when the hardware route
    /// changes (headphones plugged/unplugged, USB mic added/removed, etc.).
    /// AVAudioEngine stops itself and removes all taps automatically when this fires.
    /// We still call teardownEngineUnsafe() for belt-and-suspenders cleanup, then try a
    /// bounded recovery on audioQueue before notifying the UI layer.
    private func setupEngineConfigChangeObserver() {
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Safety.log("AVAudioEngineConfigurationChange — hardware route changed, scheduling recovery", category: .audio)
            self.audioQueue.async { [weak self] in
                guard let self else { return }
                self.handleEngineConfigurationChange()
            }
        }
    }

    /// Registers a Core Audio listener for `kAudioHardwarePropertyDefaultInputDevice`.
    ///
    /// This supplements `AVAudioEngineConfigurationChange` by catching system-level input
    /// device switches that AVAudioEngine may not surface immediately (e.g. when the engine
    /// is idle). Safe to call multiple times — the listener is only registered once.
    private func setupDefaultDeviceListener() {
        guard !isDefaultDeviceListenerRegistered else {
            Safety.log("setupDefaultDeviceListener() — already registered, skipping", category: .audio)
            return
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Pass `self` as an unretained raw pointer — the listener is removed in deinit
        // before `self` can be released, so this pointer remains valid for the listener's
        // entire lifetime.
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            defaultInputDeviceListenerProc,
            context
        )

        if status == noErr {
            isDefaultDeviceListenerRegistered = true
            Safety.log("setupDefaultDeviceListener() — registered kAudioHardwarePropertyDefaultInputDevice listener", category: .audio)
        } else {
            Safety.log("setupDefaultDeviceListener() — AudioObjectAddPropertyListener failed (status=\(status)); relying on AVAudioEngineConfigurationChange only", category: .audio)
        }
    }

    // AudioObjectRemovePropertyListener is synchronous on macOS: it blocks until any
    // in-flight invocation of the proc returns before returning. This makes the
    // unretained `self` pointer safe for the listener's full lifetime — no callback
    // can fire after this call returns.
    private func teardownDefaultDeviceListener() {
        guard isDefaultDeviceListenerRegistered else { return }
        isDefaultDeviceListenerRegistered = false

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            defaultInputDeviceListenerProc,
            context
        )

        if status != noErr {
            Safety.log("teardownDefaultDeviceListener() — AudioObjectRemovePropertyListener returned status=\(status)", category: .audio)
        }
    }

    // MARK: - Recording

    /// Starts the full audio pipeline asynchronously on `audioQueue`.
    ///
    /// All AVAudioEngine operations (inputNode, outputFormat, installTap, prepare, start)
    /// run serially on audioQueue, keeping the main actor free throughout.
    /// `completion` is called back on the main actor.
    public func startRecordingAsync(
        inputDeviceUID: String,
        completion: @escaping @MainActor (Result<AudioRecorderStartReport, Error>) -> Void
    ) {
        Safety.log("startRecordingAsync() — dispatching audio setup to audioQueue", category: .audio)
        audioQueue.async { [weak self] in
            guard let self else { return }
            do {
                let report = try self.startRecordingInternal(
                    inputDeviceUID: inputDeviceUID,
                    reason: .initialStart,
                    preserveBufferedAudio: false
                )
                MainActorDispatch.async {
                    completion(.success(report))
                }
            } catch {
                Safety.log("startRecordingInternal() FAILED: \(error)", category: .audio)
                MainActorDispatch.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func startRecordingInternal(
        inputDeviceUID: String,
        reason: AudioRecorderStartReason,
        preserveBufferedAudio: Bool
    ) throws -> AudioRecorderStartReport {
        Safety.log(
            "startRecordingInternal() — reason=\(reason.rawValue), micAuthorizationStatus=\(AVCaptureDevice.authorizationStatus(for: .audio).rawValue), preferredUID='\(inputDeviceUID)', engine.isRunning=\(engine.isRunning), preserveBufferedAudio=\(preserveBufferedAudio)",
            category: .audio
        )

        let planner = AudioRecorderRecoveryPlanner(
            retryDelays: preferredInputRetryDelays,
            sleep: { Thread.sleep(forTimeInterval: $0) },
            log: { Safety.log($0, category: .audio) },
            resolvePreferredInput: { AudioDeviceManager.resolveInputDevice(forUID: $0) },
            startAttempt: { [weak self] selection, startReason, attemptIndex in
                guard let self else {
                    throw DictationError.audioEngineSetupFailed("Audio recorder service was released before startup completed.")
                }
                return try self.performStartAttempt(
                    selection: selection,
                    reason: startReason,
                    attemptIndex: attemptIndex,
                    preserveBufferedAudio: preserveBufferedAudio
                )
            }
        )

        let report = try planner.execute(preferredUID: inputDeviceUID, reason: reason)
        isCaptureSessionActive = true
        activePreferredInputUID = inputDeviceUID
        activeInputUID = report.activeInputUID

        Safety.log(
            "startRecordingInternal() — reason=\(reason.rawValue), finalDecision=\(report.finalDecisionDescription), preferredUID='\(report.requestedPreferredUID)', activeInputUID='\(report.activeInputUID)', activeDeviceID=\(String(describing: report.activeInputDeviceID)), preferredDeviceID=\(String(describing: report.preferredInputDeviceID)), retries=\(report.retryCount), usedSystemDefault=\(report.usedSystemDefault)",
            category: .audio
        )
        if let recoveryNotice = report.recoveryNotice {
            Safety.log("startRecordingInternal() — recoveryNotice=\(recoveryNotice)", category: .audio)
        }
        return report
    }

    /// Stops the engine and returns all accumulated samples atomically.
    /// Blocks the calling thread until the audioQueue drains — safe to call from @MainActor
    /// because audioQueue never calls back to main synchronously (no deadlock risk).
    public func stopAndCollect() -> (samples: [Float], sampleRate: Double) {
        audioQueue.sync { [weak self] in
            guard let self else { return ([], 44100) }
            teardownEngineUnsafe()
            isCaptureSessionActive = false
            activePreferredInputUID = ""
            activeInputUID = ""
            MainActorDispatch.async { [weak self] in
                self?.inputLevel = 0
            }
            return self.bufferQueue.sync {
                let samples = self._accumulatedSamples
                self._accumulatedSamples = []
                return (samples, self.capturedSampleRate)
            }
        }
    }

    /// Stops the engine without collecting samples (e.g. on system stop/sleep).
    public func stopRecording() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.teardownEngineUnsafe()
            self.isCaptureSessionActive = false
            self.activePreferredInputUID = ""
            self.activeInputUID = ""
            MainActorDispatch.async { [weak self] in
                self?.inputLevel = 0
            }
        }
    }

    /// Removes the tap and stops the engine. Safe to call from any state.
    /// Must be called on audioQueue.
    private func teardownEngineUnsafe() {
        if isTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        if engine.isRunning {
            engine.stop()
        }
    }

    // fileprivate (not private) so the file-scope Core Audio callback can dispatch to this.
    fileprivate func handleEngineConfigurationChange() {
        guard !isHandlingConfigChange else {
            Safety.log("handleEngineConfigurationChange() — skipping duplicate event (already in progress)", category: .audio)
            return
        }
        isHandlingConfigChange = true
        defer { isHandlingConfigChange = false }

        let wasCaptureSessionActive = isCaptureSessionActive
        let preferredUID = activePreferredInputUID
        let activeUID = activeInputUID

        teardownEngineUnsafe()
        MainActorDispatch.async { [weak self] in
            self?.inputLevel = 0
        }

        guard wasCaptureSessionActive else {
            Safety.log("handleEngineConfigurationChange() — no active capture session; cleanup only", category: .audio)
            return
        }

        Safety.log(
            "handleEngineConfigurationChange() — attempting recovery for preferredUID='\(preferredUID)', previouslyActiveInputUID='\(activeUID)'",
            category: .audio
        )

        do {
            let report = try startRecordingInternal(
                inputDeviceUID: preferredUID,
                reason: .routeRecovery,
                preserveBufferedAudio: true
            )
            MainActorDispatch.async { [weak self] in
                guard let self else { return }
                self.onRouteRecoveryResult?(.success(report))
            }
        } catch {
            let failure = makeRecoveryFailure(error, reason: .routeRecovery, preferredUID: preferredUID)
            Safety.log(
                "handleEngineConfigurationChange() — recovery FAILED for preferredUID='\(preferredUID)', retries=\(failure.retryCount), fallbackNotice=\(failure.recoveryNotice ?? "nil"), error=\(failure.underlyingError)",
                category: .audio
            )
            isCaptureSessionActive = false
            activePreferredInputUID = ""
            activeInputUID = ""
            MainActorDispatch.async { [weak self] in
                guard let self else { return }
                self.inputLevel = 0
                self.onRouteRecoveryResult?(.failure(failure))
                self.onEngineInterrupted?()
            }
        }
    }

    private func performStartAttempt(
        selection: AudioRecorderSelectedInput,
        reason: AudioRecorderStartReason,
        attemptIndex: Int,
        preserveBufferedAudio: Bool
    ) throws -> AudioRecorderStartedInput {
        teardownEngineUnsafe()
        engine.reset()

        let selectionDescription = describeSelection(selection)
        Safety.log(
            "performStartAttempt() — reason=\(reason.rawValue), attempt=\(attemptIndex + 1), selection=\(selectionDescription), preserveBufferedAudio=\(preserveBufferedAudio)",
            category: .audio
        )

        if !preserveBufferedAudio {
            // Capture any pre-trigger audio before resetting accumulated samples.
            let preTriggerSnapshot = preTriggerBuffer?.snapshot() ?? []
            preTriggerBuffer?.clear()
            bufferQueue.sync {
                if preTriggerSnapshot.isEmpty {
                    _accumulatedSamples = []
                } else {
                    Safety.log(
                        "performStartAttempt() — prepending \(preTriggerSnapshot.count) pre-trigger samples",
                        category: .audio
                    )
                    _accumulatedSamples = preTriggerSnapshot
                }
            }
        } else {
            let bufferedSampleCount = bufferQueue.sync { _accumulatedSamples.count }
            Safety.log("performStartAttempt() — preserving \(bufferedSampleCount) buffered samples across recovery", category: .audio)
        }

        switch selection {
        case .systemDefault:
            break
        case .preferred(let match):
            try applyInputDevice(match: match)
        }

        let inputNode = engine.inputNode
        let prePrepareFormat = inputNode.outputFormat(forBus: 0)
        Safety.log(
            "performStartAttempt() — pre-prepare format: \(prePrepareFormat.sampleRate) Hz, \(prePrepareFormat.channelCount) ch",
            category: .audio
        )

        if isTapInstalled {
            inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        engine.prepare()

        let finalFormat = inputNode.outputFormat(forBus: 0)
        Safety.log(
            "performStartAttempt() — post-prepare format: \(finalFormat.sampleRate) Hz, \(finalFormat.channelCount) ch",
            category: .audio
        )

        guard finalFormat.sampleRate > 0, finalFormat.channelCount > 0 else {
            throw DictationError.audioEngineSetupFailed(
                "Audio input returned an invalid format after prepare() (sampleRate=\(finalFormat.sampleRate), channels=\(finalFormat.channelCount))."
            )
        }

        let previousSampleRate = capturedSampleRate
        capturedSampleRate = finalFormat.sampleRate
        if capturedSampleRate != previousSampleRate {
            preTriggerBuffer?.reset(sampleRate: capturedSampleRate)
        }

        // capturedSampleRate is set above; capture it as a local constant so the tap
        // closure never reads the property from the audio thread (data-race fix).
        let sampleRateForTap = capturedSampleRate   // captured once; never read from audio thread
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, sampleRate: sampleRateForTap)
        }
        isTapInstalled = true

        do {
            Safety.log("performStartAttempt() — calling engine.start()", category: .audio)
            try engine.start()
        } catch {
            throw wrapAudioStartError(error, selection: selection, reason: reason, attemptIndex: attemptIndex)
        }

        let startedInput: AudioRecorderStartedInput
        switch selection {
        case .systemDefault:
            startedInput = AudioRecorderStartedInput(uid: "", deviceID: nil)
        case .preferred(let match):
            startedInput = AudioRecorderStartedInput(uid: match.uid, deviceID: match.deviceID)
        }

        Safety.log(
            "performStartAttempt() — engine.start() succeeded for selection=\(selectionDescription), capturedSampleRate=\(capturedSampleRate)",
            category: .audio
        )
        return startedInput
    }

    private func applyInputDevice(match: AudioInputDeviceMatch) throws {
        Safety.log(
            "applyInputDevice() — preferredUID='\(match.uid)', deviceID=\(match.deviceID), hasInputChannels=\(match.hasInputChannels)",
            category: .audio
        )
        guard let audioUnit = engine.inputNode.audioUnit else {
            throw DictationError.audioEngineSetupFailed("Audio input node could not provide an audio unit for device selection.")
        }

        var id = match.deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            throw DictationError.audioEngineSetupFailed(
                "AudioUnitSetProperty failed for preferred input device '\(match.uid)' (deviceID=\(match.deviceID), status=\(status))."
            )
        }
    }

    private func wrapAudioStartError(
        _ error: Error,
        selection: AudioRecorderSelectedInput,
        reason: AudioRecorderStartReason,
        attemptIndex: Int
    ) -> Error {
        let stage: String
        switch selection {
        case .systemDefault:
            stage = reason == .routeRecovery ? "route-recovery fallback start" : "system-default fallback start"
        case .preferred:
            stage = reason == .routeRecovery ? "route-recovery preferred start" : "initial preferred start"
        }

        let errorDescription = error.localizedDescription
        let nsError = error as NSError
        Safety.log(
            "wrapAudioStartError() — stage=\(stage), attempt=\(attemptIndex + 1), domain=\(nsError.domain), code=\(nsError.code), description=\(errorDescription)",
            category: .audio
        )

        if let recoveryFailure = error as? AudioRecorderRecoveryFailure {
            return recoveryFailure
        }
        if let dictationError = error as? DictationError {
            return dictationError
        }
        return DictationError.audioEngineSetupFailed("\(stage): \(errorDescription)")
    }

    private func makeRecoveryFailure(
        _ error: Error,
        reason: AudioRecorderStartReason,
        preferredUID: String
    ) -> AudioRecorderRecoveryFailure {
        if let failure = error as? AudioRecorderRecoveryFailure {
            return failure
        }
        return AudioRecorderRecoveryFailure(
            reason: reason,
            requestedPreferredUID: preferredUID,
            preferredInputDeviceID: nil,
            retryCount: 0,
            recoveryNotice: nil,
            shouldClearStoredPreferredUID: false,
            underlyingError: error
        )
    }

    private func describeSelection(_ selection: AudioRecorderSelectedInput) -> String {
        switch selection {
        case .systemDefault:
            return "systemDefault"
        case .preferred(let match):
            return "preferred(uid=\(match.uid), deviceID=\(match.deviceID), hasInputChannels=\(match.hasInputChannels))"
        }
    }

    // MARK: - Audio Accumulation

    private let bufferQueue = DispatchQueue(label: "com.dexdictate.audioBuffer")
    private let maxSampleCount = 48000 * 600  // 10 minutes at 48 kHz
    nonisolated(unsafe) private var _accumulatedSamples: [Float] = []
    private(set) var capturedSampleRate: Double = 44100

    // MARK: - Pre-trigger Buffer

    /// Circular audio buffer that retains the last 750ms of audio so that the onset of
    /// speech is not lost when dictation begins. Allocated lazily; nil when the flag is off.
    // nonisolated(unsafe): pointer is immutable after init; internal state is guarded by PreTriggerAudioBuffer's os_unfair_lock.
    // Evaluated once at init; runtime flag changes require a new service instance.
    nonisolated(unsafe) private var preTriggerBuffer: PreTriggerAudioBuffer? = {
        ExperimentFlags.enablePreTriggerBuffer ? PreTriggerAudioBuffer(durationSeconds: 0.75) : nil
    }()

    #if DEBUG
    /// Internal seam that calls `setupDefaultDeviceListener()` for testing the idempotency guard.
    /// Allows tests to invoke the private method a second time and verify no double-registration occurs.
    internal func setupDefaultDeviceListenerForTesting() {
        setupDefaultDeviceListener()
    }

    /// Internal seam to inject mock float samples directly into the buffer queue during testing.
    internal func injectMockSamples(_ samples: [Float]) {
        bufferQueue.sync {
            _accumulatedSamples.append(contentsOf: samples)
        }
    }

    internal func setCapturedSampleRateForTesting(_ rate: Double) {
        capturedSampleRate = rate
    }
    #endif

    func collectRecording() -> [Float] {
        bufferQueue.sync {
            let samples = _accumulatedSamples
            _accumulatedSamples = []
            return samples
        }
    }

    // Called on AVAudioEngine's internal audio thread — never main thread.
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
        // Copy buffer to local array first — tap buffer is only valid during this callback.
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0, let channelData = buffer.floatChannelData?[0] else { return }

        var chunk = [Float](repeating: 0, count: frameLength)
        chunk.withUnsafeMutableBufferPointer { dst in
            let src = UnsafeBufferPointer(start: channelData, count: frameLength)
            dst.baseAddress?.initialize(from: src.baseAddress!, count: frameLength)
        }

        // Compute RMS from local copy — no lock needed.
        var sumSquares: Float = 0
        for s in chunk { sumSquares += s * s }

        // Pre-trigger buffer: write the chunk with a minimal os_unfair_lock — no await,
        // no @MainActor crossing, no allocation. Safe on the real-time audio thread.
        // `sampleRate` is the local constant captured at installTap time — no property read from audio thread.
        preTriggerBuffer?.append(chunk, sampleRate: sampleRate)

        // Async enqueue to bufferQueue — does not block the audio thread.
        bufferQueue.async { [weak self] in
            guard let self else { return }
            let cap = self.maxSampleCount
            let currentCount = self._accumulatedSamples.count
            if currentCount + frameLength > cap {
                // Drop oldest samples to make room.
                let overflow = currentCount + frameLength - cap
                self._accumulatedSamples.removeFirst(overflow)
            }
            self._accumulatedSamples.append(contentsOf: chunk)
        }

        let rms = sqrt(sumSquares / Float(frameLength))
        let normalized = AudioLevelNormalizer.normalize(Double(rms))
        MainActorDispatch.async { [weak self] in
            self?.inputLevel = normalized
        }
    }
}
