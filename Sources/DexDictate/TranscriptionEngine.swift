import SwiftUI
import Speech
import AVFoundation
import AudioToolbox

@MainActor
final class TranscriptionEngine: ObservableObject {
    @Published var state: EngineState = .stopped
    @Published var statusText = "Idle"
    @Published var debugLog: String = "Initializing..."
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var inputMonitor: InputMonitor?

    enum EngineState { case stopped, initializing, ready, listening, transcribing }

    var statusIcon: String {
        switch state {
        case .listening: return "waveform.circle.fill"
        case .transcribing: return "hourglass"
        case .ready: return "waveform.circle"
        default: return "circle"
    }
    }

    func startSystem() async {
        state = .initializing
        statusText = "Requesting Access..."
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            Task { @MainActor in
                switch authStatus {
                case .authorized:
                    self.setupAudioEngine()
                default:
                    self.statusText = "Speech Permission Denied"
                    self.state = .stopped
                }
            }
        }
    }
    
    private func setupAudioEngine() {
        inputMonitor = InputMonitor(engine: self)
        inputMonitor?.start()
        state = .ready
        statusText = "Ready! (Middle Mouse)"
    }

    func stopSystem() {
        inputMonitor?.stop()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        state = .stopped
        statusText = "Idle"
    }

    func toggleListening() {
        if state == .listening {
            stopListening()
        } else {
            startListening()
        }
    }

    func handleTrigger(down: Bool) {
        if down { startListening() } else { stopListening() }
    }

    private func startListening() {
        guard state == .ready, !audioEngine.isRunning else { return }
        state = .listening
        statusText = "Listening..."
        if Settings.shared.playStartSound {
            AudioServicesPlaySystemSound(1057) // Tink
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
        
        audioEngine.stop()
        recognitionRequest?.endAudio()
        if Settings.shared.playStopSound {
            AudioServicesPlaySystemSound(1052) // Pop
        }
    }
    
    private func startRecording() throws {
        // Cancel previous task if any
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create request") }
        recognitionRequest.shouldReportPartialResults = false // We want final result on release
        
        // Keep speech recognition data on device
        if #available(macOS 10.15, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                print("Transcription: \(transcription)")
                // For Push-to-Talk, we might update UI or pasteboard here
                if result.isFinal {
                    self.statusText = "Done: \(transcription)"
                    isFinal = true
                    // COPY TO CLIPBOARD
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(transcription, forType: .string)
                    // PASTE
                    // PASTE
                    if Settings.shared.autoPaste {
                        self.pasteText()
                    }
                }
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.state = .ready
                if !isFinal { self.statusText = "Ready! (Middle Mouse)" }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func pasteText() {
        // Simulate Command+V
        let src = CGEventSource(stateID: .hidSystemState)
        
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: false)
        
        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}
