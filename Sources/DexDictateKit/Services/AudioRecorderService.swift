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
final class AudioRecorderService: ObservableObject {
    // nonisolated(unsafe): engine is accessed exclusively on audioQueue.
    // The compiler can't verify this statically, so we assert it manually.
    nonisolated(unsafe) private let engine = AVAudioEngine()

    @MainActor @Published var inputLevel: Double = 0

    /// All engine lifecycle operations run on this serial queue.
    private let audioQueue = DispatchQueue(label: "com.dexdictate.audioEngine", qos: .userInitiated)

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    init() {
        setupSleepWakeNotifications()
    }

    deinit {
        if let obs = sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
        if let obs = wakeObserver  { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
    }

    private func setupSleepWakeNotifications() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: nil   // delivery queue doesn't matter — we dispatch to audioQueue ourselves
        ) { [weak self] _ in
            self?.audioQueue.async { [weak self] in
                guard let self, self.engine.isRunning else { return }
                self.engine.inputNode.removeTap(onBus: 0)
                self.engine.stop()
                Task { @MainActor in self.inputLevel = 0 }
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: nil
        ) { _ in /* engine will be restarted on next recording attempt */ }
    }

    // MARK: - Recording

    /// Starts the full audio pipeline asynchronously on `audioQueue`.
    ///
    /// All AVAudioEngine operations (inputNode, outputFormat, installTap, prepare, start)
    /// run serially on audioQueue, keeping the main actor free throughout.
    /// `completion` is called back on the main actor.
    func startRecordingAsync(inputDeviceUID: String, completion: @escaping @MainActor (Error?) -> Void) {
        Safety.log("startRecordingInternal() — dispatching audio setup to audioQueue")
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

        // Apply input device selection if configured (AudioUnitSetProperty).
        try applyInputDevice(uid: inputDeviceUID)

        let inputNode = engine.inputNode  // triggers hardware init — safe here on audioQueue

        // Use the hardware's native format for the tap to avoid format-mismatch crashes
        // ("IsFormatSampleRateAndChannelCountValid" exception). We resample to 16 kHz in
        // TranscriptionEngine.resampleToWhisper() after collection.
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        Safety.log("startRecordingInternal() — native format: \(nativeFormat.sampleRate) Hz, \(nativeFormat.channelCount) ch")

        bufferQueue.sync { _accumulatedSamples = [] }
        capturedSampleRate = nativeFormat.sampleRate

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
    func stopAndCollect() -> (samples: [Float], sampleRate: Double) {
        audioQueue.sync { [weak self] in
            guard let self else { return ([], 44100) }
            if self.engine.isRunning {
                self.engine.inputNode.removeTap(onBus: 0)
                self.engine.stop()
            }
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
    func stopRecording() {
        audioQueue.async { [weak self] in
            guard let self, self.engine.isRunning else { return }
            self.engine.inputNode.removeTap(onBus: 0)
            self.engine.stop()
            Task { @MainActor in self.inputLevel = 0 }
        }
    }

    private func applyInputDevice(uid: String) throws {
        // Called on audioQueue.
        guard !uid.isEmpty,
              let deviceID = AudioDeviceManager.deviceID(forUID: uid),
              let audioUnit = engine.inputNode.audioUnit else { return }
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
