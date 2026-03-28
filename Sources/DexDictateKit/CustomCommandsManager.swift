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

    public func add(_ command: CustomCommand) {
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
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CustomCommand].self, from: data) else { return }
        isLoading = true
        defer { isLoading = false }
        commands = decoded
    }
}
