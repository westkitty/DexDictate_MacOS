import Foundation

/// Saves and loads transcription history to disk for opt-in cross-session persistence.
///
/// History is written to `~/Library/Application Support/DexDictate/history.json`
/// as a schema-versioned envelope `{"version": Int, "payload": [HistoryItem]}`.
/// The on-disk list is capped at 200 items (oldest trimmed first).
///
/// Hardening over the original implementation:
/// - Versioned envelope with legacy migration for existing raw-array files.
/// - Atomic rename-over write (temp file → `replaceItemAt`).
/// - Corruption quarantine: bad files are renamed `history.json.corrupt-<ISO8601>`
///   and the caller receives an empty list rather than a crash.
/// - Blank-text items are filtered on both save and load.
/// - Duplicate UUIDs are deduplicated (first occurrence wins).
/// - All I/O is serialised on a private `DispatchQueue`, making sync `save/load/clear`
///   safe to call from `@MainActor` code without blocking the run-loop for long.
public enum HistoryPersistenceManager {

    // MARK: - Constants

    private static let filename = "history.json"
    private static let maxDiskItems = 200
    private static let schemaVersion = 1

    // MARK: - Internal queue

    /// Serial queue that owns all disk I/O. Using a dedicated queue keeps the
    /// sync API safe (no actor re-entrancy, no semaphore hacks).
    private static let queue = DispatchQueue(
        label: "com.dexdictate.HistoryPersistenceManager",
        qos: .utility
    )

    // MARK: - Envelope

    private struct Envelope: Codable {
        let version: Int
        let payload: [HistoryItem]
    }

    // MARK: - Public sync API (call-site compatible with original)

    /// Saves `items` to disk synchronously. Safe to call from `@MainActor`.
    public static func save(_ items: [HistoryItem]) {
        queue.sync { _save(items) }
    }

    /// Loads items from disk synchronously. Safe to call from `@MainActor`.
    public static func load() -> [HistoryItem] {
        queue.sync { _load() }
    }

    /// Deletes the history file synchronously. Safe to call from `@MainActor`.
    public static func clear() {
        queue.sync { _clear() }
    }

    // MARK: - Public async API (for future async call sites)

    /// Saves `items` to disk asynchronously.
    public static func saveAsync(_ items: [HistoryItem]) async {
        await withCheckedContinuation { continuation in
            queue.async {
                _save(items)
                continuation.resume()
            }
        }
    }

    /// Loads items from disk asynchronously.
    public static func loadAsync() async -> [HistoryItem] {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: _load())
            }
        }
    }

    // MARK: - Internal directory-scoped API

    /// Directory-scoped variants keep tests and diagnostics isolated from the user's
    /// real Application Support data while exercising the production persistence path.
    static func save(_ items: [HistoryItem], in directoryURL: URL) {
        queue.sync { _save(items, in: directoryURL) }
    }

    static func load(from directoryURL: URL) -> [HistoryItem] {
        queue.sync { _load(from: directoryURL) }
    }

    static func clear(in directoryURL: URL) {
        queue.sync { _clear(in: directoryURL) }
    }

    // MARK: - Private implementation (must be called on `queue`)

    private static func _save(_ items: [HistoryItem]) {
        guard let dir = Safety.appSupportURL else { return }
        _save(items, in: dir)
    }

    private static func _load() -> [HistoryItem] {
        guard let dir = Safety.appSupportURL else { return [] }
        return _load(from: dir)
    }

    private static func _clear() {
        guard let dir = Safety.appSupportURL else { return }
        _clear(in: dir)
    }

    private static func _save(_ items: [HistoryItem], in dir: URL) {
        // Normalize: filter blank text, deduplicate by UUID, cap.
        let normalized = deduplicated(items.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        let toSave = Array(normalized.prefix(maxDiskItems))

        let envelope = Envelope(version: schemaVersion, payload: toSave)
        let encoder = JSONEncoder()
        let data: Data
        do {
            data = try encoder.encode(envelope)
        } catch {
            Safety.log(
                "[HistoryPersistenceManager] Encode failed: \(error)",
                category: .general
            )
            return
        }

        let fileURL = dir.appendingPathComponent(filename)
        let tempURL = dir.appendingPathComponent("\(filename).tmp-\(UUID().uuidString)")
        do {
            try data.write(to: tempURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            Safety.log(
                "[HistoryPersistenceManager] Write failed: \(error)",
                category: .general
            )
        }
    }

    private static func _load(from dir: URL) -> [HistoryItem] {
        let fileURL = dir.appendingPathComponent(filename)
        let fm = FileManager.default

        guard fm.fileExists(atPath: fileURL.path) else { return [] }

        guard let data = try? Data(contentsOf: fileURL) else {
            Safety.log(
                "[HistoryPersistenceManager] Failed to read history.json — quarantining.",
                category: .general
            )
            quarantine(fileURL: fileURL, fm: fm)
            return []
        }

        let decoder = JSONDecoder()

        // Attempt versioned envelope decode.
        if let envelope = try? decoder.decode(Envelope.self, from: data) {
            return postProcess(envelope.payload)
        }

        // Envelope decode failed — try legacy migration (raw [HistoryItem] array).
        if let legacy = try? decoder.decode([HistoryItem].self, from: data) {
            Safety.log(
                "[HistoryPersistenceManager] Migrated legacy history.json payload.",
                category: .general
            )
            return postProcess(legacy)
        }

        // Both attempts failed — quarantine and return empty.
        Safety.log(
            "[HistoryPersistenceManager] Cannot decode history.json — quarantining.",
            category: .general
        )
        quarantine(fileURL: fileURL, fm: fm)
        return []
    }

    private static func _clear(in dir: URL) {
        let fileURL = dir.appendingPathComponent(filename)
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            let nsErr = error as NSError
            if nsErr.domain != NSCocoaErrorDomain || nsErr.code != NSFileNoSuchFileError {
                Safety.log(
                    "[HistoryPersistenceManager] Delete failed: \(error)",
                    category: .general
                )
            }
        }
    }

    // MARK: - Helpers

    /// Normalizes loaded items: filter blank text, deduplicate by UUID.
    private static func postProcess(_ items: [HistoryItem]) -> [HistoryItem] {
        let filtered = items.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return deduplicated(filtered)
    }

    /// Returns `items` with duplicate UUIDs removed (first occurrence wins).
    private static func deduplicated(_ items: [HistoryItem]) -> [HistoryItem] {
        var seen = Set<UUID>()
        return items.filter { seen.insert($0.id).inserted }
    }

    /// Renames the corrupt file to `history.json.corrupt-<ISO8601>` for forensics.
    private static func quarantine(fileURL: URL, fm: FileManager) {
        let iso = ISO8601DateFormatter().string(from: Date())
        let quarantineName = "\(fileURL.lastPathComponent).corrupt-\(iso)"
        let quarantineURL = fileURL.deletingLastPathComponent().appendingPathComponent(quarantineName)
        do {
            try fm.moveItem(at: fileURL, to: quarantineURL)
            Safety.log(
                "[HistoryPersistenceManager] Quarantined history.json → \(quarantineName)",
                category: .general
            )
        } catch {
            Safety.log(
                "[HistoryPersistenceManager] Failed to quarantine history.json: \(error)",
                category: .general
            )
        }
    }
}
