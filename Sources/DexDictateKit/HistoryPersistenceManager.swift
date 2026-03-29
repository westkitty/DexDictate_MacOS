import Foundation

/// Saves and loads transcription history to disk for opt-in cross-session persistence.
///
/// History is written to `~/Library/Application Support/DexDictate/history.json`.
/// The on-disk list is capped at 200 items (oldest trimmed first).
public enum HistoryPersistenceManager {

    private static let filename = "history.json"
    private static let maxDiskItems = 200

    public static func save(_ items: [HistoryItem]) {
        guard let dir = Safety.appSupportURL else { return }
        let url = dir.appendingPathComponent(filename)
        let toSave = Array(items.prefix(maxDiskItems))
        if let data = try? JSONEncoder().encode(toSave) {
            try? data.write(to: url, options: .atomic)
        }
    }

    public static func load() -> [HistoryItem] {
        guard let dir = Safety.appSupportURL else { return [] }
        let url = dir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return []
        }
        return decoded
    }

    public static func clear() {
        guard let dir = Safety.appSupportURL else { return }
        let url = dir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
