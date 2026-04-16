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
    /// configuration change (route switch, device added/removed, etc.).
    /// TranscriptionEngine uses this to abort the in-progress recording cleanly.
    @MainActor public var onEngineInterrupted: (() -> Void)?

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var configChangeObserver: NSObjectProtocol?

    public init() {
        setupSleepWakeNotifications()
        setupEngineConfigChangeObserver()
    }

    deinit {
        if let obs = sleepObserver      { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
        if let obs = wakeObserver       { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
        if let obs = configChangeObserver { NotificationCenter.default.removeObserver(obs) }
    }

    private func setupSleepWakeNotifications() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: nil   // delivery queue doesn't matter — we dispatch to audioQueue ourselves
        ) { [weak self] _ in
            self?.audioQueue.async { [weak self] in
                guard let self else { return }
                self.teardownEngineUnsafe()
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
    /// We still call teardownEngineUnsafe() for belt-and-suspenders cleanup, then
    /// notify the UI layer so it can abort the in-progress dictation gracefully.
    private func setupEngineConfigChangeObserver() {
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Safety.log("AVAudioEngineConfigurationChange — hardware route changed, tearing down engine")
            self.audioQueue.async { [weak self] in
                guard let self else { return }
                // engine has already been stopped by AVAudioEngine; cleanup our side
                self.teardownEngineUnsafe()
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.inputLevel = 0
                    self.onEngineInterrupted?()
                }
            }
        }
    }

    // MARK: - Recording

    /// Starts the full audio pipeline asynchronously on `audioQueue`.
    ///
    /// All AVAudioEngine operations (inputNode, outputFormat, installTap, prepare, start)
    /// run serially on audioQueue, keeping the main actor free throughout.
    /// `completion` is called back on the main actor.
    public func startRecordingAsync(inputDeviceUID: String, completion: @escaping @MainActor (Error?) -> Void) {
        Safety.log("startRecordingAsync() — dispatching audio setup to audioQueue")
        audioQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.startRecordingInternal(inputDeviceUID: inputDeviceUID)
                DispatchQueue.main.async { Task { @MainActor in completion(nil) } }
            } catch {
                Safety.log("startRecordingInternal() FAILED: \(error)")
                DispatchQueue.main.async { Task { @MainActor in completion(error) } }
            }
        }
    }

    private func startRecordingInternal(inputDeviceUID: String) throws {
        // Always called on audioQueue.
        Safety.log("startRecordingInternal() — mic authorizationStatus=\(AVCaptureDevice.authorizationStatus(for: .audio).rawValue), beginning audio engine setup")

        // ── Step 1: Bring the engine to a clean stopped state ─────────────────────
        //
        // We must reset() the engine before installing a new tap, for two reasons:
        //
        //   a) Format-mismatch crash: applyInputDevice() calls AudioUnitSetProperty
        //      to change the hardware device. AVAudioEngine caches the input node's
        //      format in its internal graph. If that cached format doesn't match the
        //      format of the newly selected device, installTap throws an NSException
        //      ("IsFormatSampleRateAndChannelCountValid"), which Swift cannot catch,
        //      aborting the process. engine.reset() flushes the cached graph state so
        //      AVAudioEngine re-negotiates the format on the next prepare()/start().
        //
        //   b) Running-engine crash: calling installTap while the engine is running
        //      (e.g. rapid trigger presses where stop hasn't finished) can throw an
        //      NSException. stop() + reset() ensure we start from a clean slate.
        teardownEngineUnsafe()
        engine.reset()

        // ── Step 2: Apply input device selection ───────────────────────────────────
        // Must happen AFTER reset() so AudioUnitSetProperty writes to a freshly
        // initialized audio unit rather than one with stale cached state.
        try applyInputDevice(uid: inputDeviceUID)

        // ── Step 3: Fetch hardware format ──────────────────────────────────────────
        let inputNode = engine.inputNode  // triggers hardware init — safe here on audioQueue

        // Use the hardware's native format for the tap to avoid format-mismatch crashes
        // ("IsFormatSampleRateAndChannelCountValid" exception). We resample to 16 kHz in
        // TranscriptionEngine.resampleToWhisper() after collection.
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        Safety.log("startRecordingInternal() — native format: \(nativeFormat.sampleRate) Hz, \(nativeFormat.channelCount) ch")

        // Guard against an invalid format — can occur if the microphone is not yet ready,
        // TCC permission was just granted, or the hardware returned a degenerate format.
        guard nativeFormat.sampleRate > 0, nativeFormat.channelCount > 0 else {
            throw NSError(
                domain: "AudioRecorderService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "Audio input returned an invalid format (sampleRate=\(nativeFormat.sampleRate), channels=\(nativeFormat.channelCount)). The microphone may not be available yet."]
            )
        }

        // ── Step 4: Install tap and start engine ───────────────────────────────────
        bufferQueue.sync { _accumulatedSamples = [] }
        capturedSampleRate = nativeFormat.sampleRate

        // removeTap is defensive — safe to call even when no tap is installed.
        // engine.reset() above should have already cleared it, but belt-and-suspenders.
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        Safety.log("startRecordingInternal() — tap installed, calling engine.prepare()")

        engine.prepare()
        Safety.log("startRecordingInternal() — engine.prepare() done, calling engine.start()")
        try engine.start()
        Safety.log("startRecordingInternal() — engine.start() succeeded")
    }

    /// Stops the engine and returns all accumulated samples atomically.
    /// Blocks the calling thread until the audioQueue drains — safe to call from @MainActor
    /// because audioQueue never calls back to main synchronously (no deadlock risk).
    public func stopAndCollect() -> (samples: [Float], sampleRate: Double) {
        audioQueue.sync { [weak self] in
            guard let self else { return ([], 44100) }
            // Remove tap unconditionally — NOT just when engine.isRunning.
            // AVAudioEngine can auto-stop on a configuration change (route switch,
            // device removed) while a tap is still registered. If we skip removal
            // here, the stale tap causes a "tap already installed" NSException on
            // the next startRecordingInternal() even though engine.isRunning == false.
            teardownEngineUnsafe()
            Task { @MainActor in self.inputLevel = 0 }
            // Drain the buffer under bufferQueue while still on audioQueue.
            return self.bufferQueue.sync {
                let s = self._accumulatedSamples
                self._accumulatedSamples = []
                return (s, self.capturedSampleRate)
            }
        }
    }

    /// Stops the engine without collecting samples (e.g. on system stop/sleep).
    public func stopRecording() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            // Remove tap unconditionally — see stopAndCollect() for rationale.
            self.teardownEngineUnsafe()
            Task { @MainActor in self.inputLevel = 0 }
        }
    }

    /// Removes the tap and stops the engine.  Safe to call from any state:
    ///   - removeTap(onBus:) is a no-op when no tap is installed
    ///   - engine.stop() is a no-op when the engine is already stopped
    /// Must be called on audioQueue.
    private func teardownEngineUnsafe() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }
    }

    private func applyInputDevice(uid: String) throws {
        // Called on audioQueue.
        guard !uid.isEmpty else { return }

        guard let deviceID = AudioDeviceManager.deviceID(forUID: uid) else {
            Safety.log("Preferred input device is unavailable. Falling back to the system default input device.", category: .audio)
            return
        }

        guard let audioUnit = engine.inputNode.audioUnit else { return }
        var id = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr { throw DictationError.inputDeviceError }
    }

    // MARK: - Audio Accumulation

    private let bufferQueue = DispatchQueue(label: "com.dexdictate.audioBuffer")
    nonisolated(unsafe) private var _accumulatedSamples: [Float] = []
    private(set) var capturedSampleRate: Double = 44100

    func collectRecording() -> [Float] {
        bufferQueue.sync {
            let s = _accumulatedSamples
            _accumulatedSamples = []
            return s
        }
    }

    // Called on AVAudioEngine's internal audio thread — never main thread.
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 { return }

        var sumSquares: Float = 0
        for i in 0..<frameLength { sumSquares += channelData[i] * channelData[i] }

        bufferQueue.sync {
            _accumulatedSamples.reserveCapacity(_accumulatedSamples.count + frameLength)
            for i in 0..<frameLength { _accumulatedSamples.append(channelData[i]) }
        }

        let rms = sqrt(sumSquares / Float(frameLength))
        let avgPower = rms == 0 ? -100 : 20 * log10(rms)
        let normalized = min(max((Double(avgPower) + 50) / 50, 0), 1)
        Task { @MainActor in self.inputLevel = normalized }
    }
}
