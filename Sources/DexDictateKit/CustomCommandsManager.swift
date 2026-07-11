import Foundation

/// A user-defined voice command triggered by saying "Dex [keyword]".
public struct CustomCommand: Identifiable, Codable {
    public var id: UUID
    public var keyword: String       // what to say after "Dex", e.g. "comma"
    public var insertText: String    // text inserted when command fires, e.g. ","

    public init(id: UUID = UUID(), keyword: String, insertText: String) {
        self.id = id
        self.keyword = keyword
        self.insertText = insertText
    }
}

/// Persists and vends the user's custom voice commands.
///
/// Commands are triggered by saying "Dex [keyword]" during dictation.
/// Stored as JSON in `UserDefaults` under `"customVoiceCommands_v1"`.
public final class CustomCommandsManager: ObservableObject {
    @Published public var commands: [CustomCommand] = [] {
        didSet { if !isLoading { save() } }
    }

    private let storageKey = "customVoiceCommands_v1"
    private var isLoading = false

    public init() { load() }

    /// Adds `command`, or replaces the existing command with the same keyword (case/whitespace-
    /// insensitive) if one exists. `CommandProcessor` resolves a spoken keyword via `first(where:)`,
    /// so two commands sharing a keyword previously meant the second was silently unreachable —
    /// added or imported with no indication it would never fire.
    public func add(_ command: CustomCommand) {
        let normalizedKeyword = command.keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let existingIndex = commands.firstIndex(where: {
            $0.keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedKeyword
        }) {
            commands[existingIndex] = command
            return
        }
        commands.append(command)
    }

    public func remove(at offsets: IndexSet) {
        commands.remove(atOffsets: offsets)
    }

    public func remove(id: UUID) {
        commands.removeAll { $0.id == id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(commands) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }  // absent = fine
        do {
            let decoded = try JSONDecoder().decode([CustomCommand].self, from: data)
            isLoading = true
            defer { isLoading = false }
            commands = decoded
        } catch {
            Safety.log("[CustomCommandsManager] Corrupt data for key '\(storageKey)': \(error). Leaving commands empty; stored data preserved.", category: .settings)
            // Do NOT overwrite commands — leave them as []
        }
    }
}
