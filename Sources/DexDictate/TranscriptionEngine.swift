import SwiftUI
import Speech
import AVFoundation
import AudioToolbox

/// The central coordinator for the speech-recognition pipeline.
///
/// `TranscriptionEngine` owns the `AVAudioEngine` and `SFSpeechRecognizer`, manages the
/// `InputMonitor` that intercepts the user's trigger shortcut, and delegates post-processing
/// to `ProfanityFilter`, `ClipboardManager`, and `SoundPlayer`.
///
/// All mutations run on the main actor so `@Published` properties drive SwiftUI views
/// without extra dispatch.
@MainActor
final class TranscriptionEngine: ObservableObject {

    /// Current lifecycle phase of the engine. Views observe this to enable/disable controls.
    @Published var state: EngineState = .stopped

    /// Short human-readable description of the current state, shown in the history feed
    /// when no transcriptions exist yet.
    @Published var statusText = "Idle"

    /// Live partial transcription shown while listening/transcribing.
    @Published var liveTranscript = ""

    /// Normalized microphone input level (0.0-1.0) for visual feedback.
    @Published var inputLevel: Double = 0

    /// Ordered collection of completed transcription results for the current session.
    @Published var history = TranscriptionHistory()

    /// On-device English speech recognizer. `requiresOnDeviceRecognition` is enforced on
    /// every request so audio never leaves the device.
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    /// Live audio buffer fed incrementally to the recognizer while recording.
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    /// The active recognition task; cancelled and replaced at the start of each recording.
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Shared audio engine. Started when recording begins; stopped after each result or error.
    private let audioEngine = AVAudioEngine()

    /// Global input monitor that intercepts the configured trigger shortcut system-wide.
    private var inputMonitor: InputMonitor?

    /// Pending task that stops listening after the hold-to-talk debounce window (750 ms).
    private var stopTask: Task<Void, Error>?

    /// Weak reference to the permission manager so the engine can retry after accessibility
    /// access is granted without creating a retain cycle.
    private weak var permissionManager: PermissionManager?

    /// UUID regenerated on every trigger press. Used to discard stale `scheduleStop` tasks
    /// that were queued before the most recent press began.
    private var currentSessionId = UUID()

    /// Lifecycle phases of the transcription engine.
    enum EngineState {
        /// Not started or explicitly stopped.
        case stopped
        /// `startSystem()` was called; waiting for speech authorization.
        case initializing
        /// Input monitor is active, waiting for the trigger shortcut.
        case ready
        /// Trigger held/toggled on; microphone is recording.
        case listening
        /// Audio capture ended; waiting for the final recognition result.
        case transcribing
        /// A non-recoverable error occurred (e.g. event tap could not be installed).
        case error
    }

    /// SF Symbol name reflecting the current state, used in the menu bar icon.
    var statusIcon: String {
        switch state {
        case .listening: return "waveform.circle.fill"
        case .transcribing: return "hourglass"
        case .ready: return "waveform.circle"
        case .error: return "exclamationmark.triangle.fill"
        default: return "circle"
        }
    }

    // MARK: - System Lifecycle

    /// Requests speech recognition authorization and, on success, starts the input monitor.
    ///
    /// Transitions the engine through `.initializing` → `.ready`, or back to `.stopped`
    /// if permission is denied. Call this when the user taps **Start Dictation**.
    func startSystem() async {
        state = .initializing
        statusText = "Requesting Access..."

        SFSpeechRecognizer.requestAuthorization { authStatus in
            Task { @MainActor in
                switch authStatus {
                case .authorized:
                    self.setupInputMonitor()
                default:
                    self.statusText = "Speech Permission Denied"
                    self.state = .stopped
                }
            }
        }
    }

    /// Tears down the input monitor and audio engine, returning the engine to `.stopped`.
    ///
    /// Safe to call from any engine state; idempotent if already stopped.
    func stopSystem() {
        inputMonitor?.stop()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        state = .stopped
        statusText = "Idle"
        liveTranscript = ""
        inputLevel = 0
    }

    /// Wires up the permission manager so it can call ``retryInputMonitor()`` after
    /// accessibility access is granted.
    ///
    /// - Parameter manager: Stored as a weak reference to avoid a retain cycle.
    func setPermissionManager(_ manager: PermissionManager) {
        self.permissionManager = manager
    }

    /// Tears down and recreates the input monitor.
    ///
    /// Called by `PermissionManager` when it detects that accessibility access was just
    /// granted, allowing the event tap to be installed without a full app restart.
    func retryInputMonitor() {
        inputMonitor?.stop()
        inputMonitor = nil
        setupInputMonitor()
    }

    // MARK: - Trigger Handling

    /// Toggles between recording and idle. This is the handler for *Click to Toggle* mode.
    func toggleListening() {
        if state == .listening {
            stopListening()
        } else {
            startListening()
        }
    }

    /// Responds to a trigger press or release. This is the handler for *Hold to Talk* mode.
    ///
    /// On press (`down: true`) any pending debounced stop is cancelled and recording begins.
    /// On release (`down: false`) a 750 ms debounce window is started; recording stops only
    /// if no new press arrives within that window.
    ///
    /// - Parameter down: `true` on key/button press, `false` on release.
    func handleTrigger(down: Bool) {
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
        inputMonitor = InputMonitor(engine: self)
        inputMonitor?.start()
        state = .ready
        statusText = "Ready"
    }

    /// Schedules `stopListening()` after 750 ms. If the trigger is pressed again before
    /// the delay elapses the task is cancelled via `currentSessionId` comparison.
    private func scheduleStop() {
        stopTask?.cancel()
        let sessionId = currentSessionId

        stopTask = Task {
            try? await Task.sleep(nanoseconds: 750 * 1_000_000)
            if !Task.isCancelled && sessionId == currentSessionId {
                stopListening()
            }
        }
    }

    private func startListening() {
        guard state == .ready, !audioEngine.isRunning else { return }
        state = .listening
        statusText = "Listening..."
        liveTranscript = ""
        inputLevel = 0

        if Settings.shared.playStartSound {
            SoundPlayer.play(Settings.shared.selectedStartSound)
        }

        do {
            try startRecording()
        } catch {
            print("Recording failed: \(error)")
            statusText = "Audio Error"
            state = .ready
        }
    }

    private func stopListening() {
        guard state == .listening else { return }
        state = .transcribing
        statusText = "Transcribing..."
        inputLevel = 0

        audioEngine.stop()
        recognitionRequest?.endAudio()

        if Settings.shared.playStopSound {
            SoundPlayer.play(Settings.shared.selectedStopSound)
        }
    }

    /// Configures and starts an `AVAudioEngine` tap that feeds PCM buffers into a new
    /// `SFSpeechAudioBufferRecognitionRequest`.
    ///
    /// The recognition callback applies optional profanity filtering, appends the result to
    /// `history`, and triggers auto-paste when the result is final.
    ///
    /// - Throws: Any error propagated from `AVAudioEngine.start()`.
    private func startRecording() throws {
        applySelectedInputDevice()

        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            state = .error
            statusText = "Failed to create recognition request"
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        if speechRecognizer?.supportsOnDeviceRecognition == true {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        let inputNode = audioEngine.inputNode

        // Capture the local (non-@MainActor-isolated) constant so the audio-thread tap
        // callback never touches a @MainActor property from a background thread.
        let capturedRequest = recognitionRequest

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            // SFSpeechRecognizer delivers results on the main thread, but dispatch
            // explicitly to stay safe with @MainActor-isolated state.
            DispatchQueue.main.async {
                guard let self = self else { return }
                var isFinal = false

                if let result = result {
                    let bestText = result.bestTranscription.formattedString
                    self.liveTranscript = bestText

                    if result.isFinal {
                        var finalText = bestText

                        if Settings.shared.profanityFilter {
                            finalText = ProfanityFilter.filter(finalText)
                        }

                        self.history.add(finalText)
                        self.statusText = "Done: \(finalText)"
                        self.liveTranscript = ""
                        isFinal = true

                        if Settings.shared.autoPaste {
                            ClipboardManager.copyAndPaste(finalText)
                        }
                    }
                }

                if error != nil || isFinal {
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    self.state = .ready
                    if !isFinal {
                        if let error = error {
                            self.statusText = "Error: \(error.localizedDescription)"
                        } else {
                            self.statusText = "Ready"
                        }
                    }
                    if !isFinal {
                        self.liveTranscript = ""
                    }
                }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            // 'capturedRequest' is a local constant — safe to access from the audio thread.
            capturedRequest.append(buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            if frameLength == 0 { return }

            var sumSquares: Float = 0
            for i in 0..<frameLength {
                let sample = channelData[i]
                sumSquares += sample * sample
            }
            let rms = sqrt(sumSquares / Float(frameLength))
            let avgPower = rms == 0 ? -100 : 20 * log10(rms)
            let normalized = min(max((Double(avgPower) + 50) / 50, 0), 1)

            DispatchQueue.main.async {
                self.inputLevel = normalized
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func applySelectedInputDevice() {
        let selectedUID = Settings.shared.inputDeviceUID
        guard !selectedUID.isEmpty,
              let selectedDeviceID = AudioDeviceManager.deviceID(forUID: selectedUID),
              let audioUnit = audioEngine.inputNode.audioUnit else {
            return
        }

        var deviceID = selectedDeviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        if status != noErr {
            statusText = "Input Device Error"
        }
    }
}
