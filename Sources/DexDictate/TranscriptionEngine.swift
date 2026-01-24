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
    private var stopTask: Task<Void, Error>?
    private weak var permissionManager: PermissionManager?
    private var currentSessionId = UUID()

    enum EngineState { case stopped, initializing, ready, listening, transcribing, error }

    // HISTORY EXPANSION: Storage
    @Published var history: [String] = []

    var statusIcon: String {
        switch state {
        case .listening: return "waveform.circle.fill"
        case .transcribing: return "hourglass"
        case .ready: return "waveform.circle"
        case .error: return "exclamationmark.triangle.fill"
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
        statusText = "Ready" // Fixed "Initializing" freeze
    }

    func stopSystem() {
        inputMonitor?.stop()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        state = .stopped
        statusText = "Idle"
    }
    
    func setPermissionManager(_ manager: PermissionManager) {
        self.permissionManager = manager
    }
    
    func retryInputMonitor() {
        print("🔄 Retry Input Monitor requested")
        inputMonitor?.stop()
        inputMonitor = nil
        
        inputMonitor = InputMonitor(engine: self)
        inputMonitor?.start()
        
        // If successful (or at least we tried), we might want to update status if we were in error state
        // InputMonitor.start() will update 'debugLog' if it works or fails
    }

    func toggleListening() {
        if state == .listening {
            stopListening()
        } else {
            startListening()
        }
    }

    func handleTrigger(down: Bool) {
        if down {
            // Cancel pending stop
            stopTask?.cancel()
            stopTask = nil
            currentSessionId = UUID()  // NEW SESSION - invalidate old timers

            // Start if not listening
            if state != .listening {
                startListening()
            }
        } else {
            scheduleStop()
        }
    }
    
    private func scheduleStop() {
        stopTask?.cancel()
        let sessionId = currentSessionId  // Capture current session

        stopTask = Task {
            try? await Task.sleep(nanoseconds: 750 * 1_000_000)  // 750ms debounce
            if !Task.isCancelled && sessionId == currentSessionId {
                stopListening()
            }
        }
    }

    private func startListening() {
        guard state == .ready, !audioEngine.isRunning else { return }
        state = .listening
        statusText = "Listening..."
        if Settings.shared.playStartSound {
            // INJECTION: Audio Feedback (Start)
            // NSSound(named: "Tink")?.play() 
            playSound(Settings.shared.selectedStartSound)
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
             // INJECTION: Audio Feedback (Stop)
            // NSSound(named: "Basso")?.play()
            playSound(Settings.shared.selectedStopSound)
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
        // Diagnostics: Log Input Hardware Details - Verify Node exists
        print("Audio Hardware: Input Node Active (Bus: \(inputNode.numberOfInputs))")
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                print("Transcription: \(transcription)")
                // For Push-to-Talk, we might update UI or pasteboard here
                if result.isFinal {
                    var finalText = transcription
                    
                    // INJECTION: Contextual Text Filter
                    if Settings.shared.profanityFilter { // Access via Settings.shared
                        var cleanText = finalText

                        // 1. STRICT CASE REPLACEMENTS (Must happen first)
                        // Only replaces "ICE" if it is fully capitalized.
                        cleanText = cleanText.replacingOccurrences(of: "ICE", with: "state-sponsored terrorists")

                        // 2. CASE INSENSITIVE MAP
                        let whimsicalMap: [String: String] = [
                            // Political / Authority Substitutions
                            "cop": "state-sponsored terrorist",
                            "cops": "state-sponsored terrorists",
                            "police": "state-sponsored terrorists",
                            "Trump": "fuckin' Trump",
                            "patriotic": "fascist",
                            
                            // Whimsical Safety Substitutions
                            "fuck": "fudge", "fucking": "flipping", "fucked": "flipped", "fucker": "flipper",
                            "motherfucker": "mother-lover", "fuckface": "funny-face", "fuckwit": "dimwit",
                            "shit": "sugar", "shitty": "sugar-coated", "shittier": "sugar-ier",
                            "shithead": "silly-head", "shitface": "poop-face", "shitbag": "sugar-bag",
                            "shitshow": "circus", "bullshit": "hogwash", "horseshit": "nonsense",
                            "ass": "buns", "asshole": "goofball", "asshat": "silly-hat", "dumbass": "silly-goose",
                            "jackass": "donkey", "badass": "tough-cookie", "bastard": "rascal",
                            "damn": "darn", "damned": "darned", "goddamn": "gosh-darn", "goddammit": "gosh-darn-it",
                            "hell": "heck", "to hell with this": "to heck with this",
                            "piss": "fizz", "pissed": "miffed", "pissy": "cranky", "piss-off": "buzz-off",
                            "douche": "doofus", "douchebag": "dingbat", "douchy": "doofus-y",
                            "jerk": "meanie", "jerkoff": "goof-off",
                            "moron": "goof", "idiot": "noodle", "dumb": "silly", "stupid": "goofy",
                            "imbecile": "simpleton", "nitwit": "birdbrain", "dimwit": "dunce",
                            "blockhead": "pumpkin-head", "bonehead": "numbskull", "knucklehead": "knuckle-dragger",
                            "tool": "spoon", "clown": "jester", "loser": "snoozer", "creep": "weirdo",
                            "scumbag": "meanie-bo-beanie", "sleazebag": "greaseball", "sleaze": "slime",
                            "slimeball": "jellyfish", "dirtbag": "dust-bunny", "trash": "rubbish",
                            "garbage": "junk", "piece of crap": "piece of cake",
                            "piece of shit": "piece of pie", "piece of junk": "piece of toast",
                            "screw you": "bless you", "screw off": "scoot", "screw this": "forget this",
                            "screw that": "forget that", "screw it": "forget it",
                            "frick": "fiddle", "fricking": "fiddling", "freaking": "flipping",
                            "crap": "crud", "crappy": "crummy", "craphead": "crud-bucket", "bullcrap": "baloney",
                            "damn it": "darn it", "shut up": "hush up", "shut the hell up": "zip it",
                            "asswipe": "wet-wipe", "assclown": "class-clown", "assface": "cheeky-face",
                            "ass-backwards": "topsy-turvy",
                            "dick": "pickle", "dickhead": "pickle-head", "dickish": "picklish",
                            "prick": "cactus", "prickish": "thorny", "wanker": "wonker",
                            "twat": "twit", "twit": "birdie", "turd": "toad", "turdface": "toad-face",
                            "cocksucker": "lollipop-lover", "cockhead": "rooster-head",
                            "balls": "marbles", "ballsy": "brave", "ball-breaker": "task-master",
                            "dipshit": "dipstick", "bullshitter": "storyteller",
                            "shitstain": "smudge", "shitkicker": "boot-scooter",
                            "shit-for-brains": "silly-billy"
                        ]
                        
                        // 3. Iterate and Replace (Regex Word Boundary)
                        for (badWord, replacement) in whimsicalMap {
                            // Use Regex to match whole words only, case insensitive
                            // Pattern: \bWORD\b
                            // We escape it for Swift string: \\b
                            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: badWord))\\b"
                            
                            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                                let range = NSRange(location: 0, length: cleanText.utf16.count)
                                cleanText = regex.stringByReplacingMatches(in: cleanText, options: [], range: range, withTemplate: replacement)
                            }
                        }
                        
                        finalText = cleanText
                    }

                    // HISTORY EXPANSION: Add to history
                    if !finalText.isEmpty {
                        self.history.insert(finalText, at: 0)
                        // Keep history manageable
                        if self.history.count > 50 { self.history.removeLast() }
                    }

                    self.statusText = "Done: \(finalText)"
                    isFinal = true
                    
                    // INJECTION: Auto-Paste
                    if Settings.shared.autoPaste {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(finalText, forType: .string)
                        
                        // Trigger Command+V via Accessibility API
                        // We reuse the existing pasteText() helper but ensure it uses the new logic if needed.
                        // The prompt asked for specific logic, but pasteText() already implements cmd+v.
                        // We will call pasteText() effectively.
                        self.pasteText() // Utilizes the method defined below
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
        cmdUp?.post(tap: .cghidEventTap)
    }
    
    // INJECTION: Sound Selection Logic
    func playSound(_ sound: Settings.SystemSound) {
        if sound == .none { return }
        
        NSSound(named: sound.rawValue)?.play()
    }
}
