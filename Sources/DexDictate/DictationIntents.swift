import AppIntents
import DexDictateKit

@available(macOS 13.0, *)
struct StartDictationIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Dictation"
    static var description = IntentDescription("Starts the DexDictate listening process.")

    @MainActor
    func perform() async throws -> some IntentResult {
        let engine = TranscriptionEngine.shared
        // `toggleListening()` only actually starts a new recording from `.ready`. From
        // `.transcribing` it just queues (or cancels a queued) start for once the current
        // dictation finishes — it does not start anything immediately. From `.stopped`,
        // `.initializing`, or `.error` it's a complete no-op. Previously this intent reported
        // "Listening started." for all of those cases too, telling Siri/Shortcuts the
        // dictation began when it may not have.
        switch engine.state {
        case .listening:
            return .result(dialog: "Already listening.")
        case .ready:
            engine.toggleListening()
            return .result(dialog: "Listening started.")
        case .transcribing:
            engine.toggleListening()
            return .result(dialog: "Finishing the previous dictation — DexDictate will start listening automatically.")
        case .stopped, .initializing, .error:
            return .result(dialog: "DexDictate isn't ready yet. Open the app and try again.")
        }
    }
}

@available(macOS 13.0, *)
struct StopDictationIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Dictation"
    static var description = IntentDescription("Stops the DexDictate listening process.")
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let engine = TranscriptionEngine.shared
        if engine.state == .listening {
            engine.toggleListening()
            return .result(dialog: "Listening stopped.")
        } else {
            return .result(dialog: "Not listening.")
        }
    }
}

@available(macOS 13.0, *)
struct ToggleDictationIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Dictation"
    static var description = IntentDescription("Toggles the listening state.")

    @MainActor
    func perform() async throws -> some IntentResult {
        let engine = TranscriptionEngine.shared
        // Inferring "started"/"stopped" purely from whether state == .listening afterward
        // was wrong for two reachable cases: from `.transcribing`, toggling just queues (or
        // cancels a queued) start with no state change, so it always reported "Stopped
        // listening" even though nothing was listening to stop; from `.stopped`/`.initializing`/
        // `.error`, toggleListening() is a complete no-op, but this always reported "Stopped
        // listening" there too.
        switch engine.state {
        case .listening:
            engine.toggleListening()
            return .result(dialog: "Stopped listening.")
        case .ready:
            engine.toggleListening()
            return .result(dialog: "Started listening.")
        case .transcribing:
            engine.toggleListening()
            return .result(dialog: "Toggled the queued start for after the current dictation finishes.")
        case .stopped, .initializing, .error:
            return .result(dialog: "DexDictate isn't ready yet. Open the app and try again.")
        }
    }
}

@available(macOS 13.0, *)
struct DexDictateAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartDictationIntent(),
            phrases: ["Start dictation with \(.applicationName)", "Start listening in \(.applicationName)"],
            shortTitle: "Start Dictation",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StopDictationIntent(),
            phrases: ["Stop dictation with \(.applicationName)", "Stop listening in \(.applicationName)"],
            shortTitle: "Stop Dictation",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: ToggleDictationIntent(),
            phrases: ["Toggle dictation with \(.applicationName)"],
            shortTitle: "Toggle Dictation",
            systemImageName: "mic.circle"
        )
    }
}
