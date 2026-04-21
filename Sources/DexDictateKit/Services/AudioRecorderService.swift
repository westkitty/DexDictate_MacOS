import AppKit
import AVFoundation

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
///   - UI-visible state (@Published) is always updated on the main actor via Task { @MainActor }.
public final class AudioRecorderService: ObservableObject {
    // nonisolated(unsafe): engine is accessed exclusively on audioQueue.
    // The compiler can't verify this statically, so we assert it manually.
    nonisolated(unsafe) private let engine = AVAudioEngine()

    @MainActor @Published public var inputLevel: Double = 0

    /// All engine lifecycle operations run on this serial queue.
    private let audioQueue = DispatchQueue(label: "com.dexdictate.audioEngine", qos: .userInitiated)

    /// Called on the main actor when AVAudioEngine stops itself due to a hardware
    /// configuration change and recovery ultimately fails.
    @MainActor public var onEngineInterrupted: (() -> Void)?

    /// Called on the main actor when a hardware-route recovery attempt succeeds or fails.
    @MainActor public var onRouteRecoveryResult: ((Result<AudioRecorderStartReport, AudioRecorderRecoveryFailure>) -> Void)?

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var configChangeObserver: NSObjectProtocol?

    // Accessed only on audioQueue.
    nonisolated(unsafe) private var isCaptureSessionActive = false
    nonisolated(unsafe) private var activePreferredInputUID = ""
    nonisolated(unsafe) private var activeInputUID = ""

    private let preferredInputRetryDelays: [TimeInterval] = [0, 0.15, 0.35]

    public init() {
        setupSleepWakeNotifications()
        setupEngineConfigChangeObserver()
    }

    deinit {
        if let obs = sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
        if let obs = wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
        if let obs = configChangeObserver { NotificationCenter.default.removeObserver(obs) }
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
                Task { @MainActor in self.inputLevel = 0 }
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
                DispatchQueue.main.async { Task { @MainActor in completion(.success(report)) } }
            } catch {
                Safety.log("startRecordingInternal() FAILED: \(error)", category: .audio)
                DispatchQueue.main.async { Task { @MainActor in completion(.failure(error)) } }
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
            Task { @MainActor in self.inputLevel = 0 }
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
            Task { @MainActor in self.inputLevel = 0 }
        }
    }

    /// Removes the tap and stops the engine. Safe to call from any state.
    /// Must be called on audioQueue.
    private func teardownEngineUnsafe() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }
    }

    private func handleEngineConfigurationChange() {
        let wasCaptureSessionActive = isCaptureSessionActive
        let preferredUID = activePreferredInputUID
        let activeUID = activeInputUID

        teardownEngineUnsafe()
        Task { @MainActor in self.inputLevel = 0 }

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
            DispatchQueue.main.async {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.onRouteRecoveryResult?(.success(report))
                }
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
            DispatchQueue.main.async {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.inputLevel = 0
                    self.onRouteRecoveryResult?(.failure(failure))
                    self.onEngineInterrupted?()
                }
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
            bufferQueue.sync { _accumulatedSamples = [] }
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

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        engine.prepare()

        let finalFormat = inputNode.outputFormat(forBus: 0)
        Safety.log(
            "performStartAttempt() — post-prepare format: \(finalFormat.sampleRate) Hz, \(finalFormat.channelCount) ch",
            category: .audio
        )

        guard finalFormat.sampleRate > 0, finalFormat.channelCount > 0 else {
            inputNode.removeTap(onBus: 0)
            throw DictationError.audioEngineSetupFailed(
                "Audio input returned an invalid format after prepare() (sampleRate=\(finalFormat.sampleRate), channels=\(finalFormat.channelCount))."
            )
        }

        capturedSampleRate = finalFormat.sampleRate

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
    nonisolated(unsafe) private var _accumulatedSamples: [Float] = []
    private(set) var capturedSampleRate: Double = 44100

    func collectRecording() -> [Float] {
        bufferQueue.sync {
            let samples = _accumulatedSamples
            _accumulatedSamples = []
            return samples
        }
    }

    // Called on AVAudioEngine's internal audio thread — never main thread.
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 { return }

        var sumSquares: Float = 0
        for i in 0..<frameLength {
            sumSquares += channelData[i] * channelData[i]
        }

        bufferQueue.sync {
            _accumulatedSamples.reserveCapacity(_accumulatedSamples.count + frameLength)
            for i in 0..<frameLength {
                _accumulatedSamples.append(channelData[i])
            }
        }

        let rms = sqrt(sumSquares / Float(frameLength))
        let avgPower = rms == 0 ? -100 : 20 * log10(rms)
        let normalized = min(max((Double(avgPower) + 50) / 50, 0), 1)
        Task { @MainActor in self.inputLevel = normalized }
    }
}
