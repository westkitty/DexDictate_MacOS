import AppIntents
import DexDictateKit

@available(macOS 13.0, *)
struct StartDictationIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Dictation"
    static var description = IntentDescription("Starts the DexDictate listening process.")
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let engine = TranscriptionEngine.shared
        if engine.state != .listening {
            engine.toggleListening()
            return .result(dialog: "Listening started.")
        } else {
            return .result(dialog: "Already listening.")
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
        engine.toggleListening()
        let status = engine.state == .listening ? "Started listening" : "Stopped listening"
        return .result(dialog: IntentDialog(stringLiteral: status))
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
