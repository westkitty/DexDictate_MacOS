import Foundation

/// A schema-versioned, atomic-write, corruption-quarantining local JSON store.
///
/// All values are persisted as a versioned envelope `{"version": Int, "payload": T}`.
/// Reads are migration-aware: if the stored version predates the current schema version,
/// the optional `legacyMigrate` closure is tried before quarantining.
/// Corrupt or unreadable files are renamed to `<name>.corrupt-<ISO8601>` and never deleted,
/// preserving forensic data while returning the caller-supplied `defaultValue`.
///
/// All disk I/O is isolated inside the `actor` — no main-actor access.
public actor LocalJSONStore<T: Codable> {

    // MARK: - Envelope

    private struct Envelope<P: Codable>: Codable {
        let version: Int
        let payload: P
    }

    // MARK: - Stored properties

    private let fileURL: URL
    private let schemaVersion: Int
    private let defaultValue: T
    private let legacyMigrate: ((Data) throws -> T)?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Init

    /// Creates a store backed by `fileURL`.
    ///
    /// - Parameters:
    ///   - fileURL: Destination file. The parent directory must already exist.
    ///   - schemaVersion: Current schema version written into every envelope.
    ///   - defaultValue: Returned when the file is absent, quarantined, or unreadable.
    ///   - legacyMigrate: Optional closure that attempts to decode a raw (non-enveloped)
    ///     `Data` blob. Called before quarantining when the versioned decode fails.
    public init(
        fileURL: URL,
        schemaVersion: Int,
        defaultValue: T,
        legacyMigrate: ((Data) throws -> T)? = nil
    ) {
        self.fileURL = fileURL
        self.schemaVersion = schemaVersion
        self.defaultValue = defaultValue
        self.legacyMigrate = legacyMigrate
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Public API

    /// Loads the stored value.
    ///
    /// Resolution order:
    /// 1. Decode versioned envelope — accept any version (forward-compatible).
    /// 2. If envelope decode fails and `legacyMigrate` is provided, try it on raw data.
    /// 3. Otherwise quarantine the file and return `defaultValue`.
    /// 4. If the file is absent, return `defaultValue` silently.
    public func load() -> T {
        let fm = FileManager.default

        guard fm.fileExists(atPath: fileURL.path) else {
            return defaultValue
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            Safety.log(
                "[LocalJSONStore] Failed to read \(fileURL.lastPathComponent) — quarantining.",
                category: .general
            )
            quarantine(fm: fm)
            return defaultValue
        }

        // Attempt versioned envelope decode.
        if let envelope = try? decoder.decode(Envelope<T>.self, from: data) {
            // Forward-compatible: accept stored versions >= or <= schemaVersion.
            return envelope.payload
        }

        // Envelope decode failed — try legacy migration if a closure was provided.
        if let migrate = legacyMigrate {
            do {
                let migrated = try migrate(data)
                Safety.log(
                    "[LocalJSONStore] Migrated legacy payload in \(fileURL.lastPathComponent).",
                    category: .general
                )
                return migrated
            } catch {
                Safety.log(
                    "[LocalJSONStore] Legacy migration of \(fileURL.lastPathComponent) failed: \(error) — quarantining.",
                    category: .general
                )
            }
        } else {
            Safety.log(
                "[LocalJSONStore] Cannot decode \(fileURL.lastPathComponent) (no legacy migrator) — quarantining.",
                category: .general
            )
        }

        quarantine(fm: fm)
        return defaultValue
    }

    /// Saves `value` atomically.
    ///
    /// Writes a temp file in the same directory, then renames it over the target so
    /// partial writes are never visible to readers.
    public func save(_ value: T) {
        let envelope = Envelope(version: schemaVersion, payload: value)
        let data: Data
        do {
            data = try encoder.encode(envelope)
        } catch {
            Safety.log(
                "[LocalJSONStore] Encode failed for \(fileURL.lastPathComponent): \(error)",
                category: .general
            )
            return
        }

        let dir = fileURL.deletingLastPathComponent()
        let tempURL = dir.appendingPathComponent(
            "\(fileURL.lastPathComponent).tmp-\(UUID().uuidString)"
        )

        do {
            try data.write(to: tempURL, options: .atomic)
            // Rename over the destination — atomic on the same filesystem.
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } catch {
            // Clean up the temp file if rename failed.
            try? FileManager.default.removeItem(at: tempURL)
            Safety.log(
                "[LocalJSONStore] Write failed for \(fileURL.lastPathComponent): \(error)",
                category: .general
            )
        }
    }

    /// Removes the backing file, e.g. for "clear history".
    public func delete() {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            // Ignore "file not found"; log anything else.
            let nsErr = error as NSError
            if nsErr.domain != NSCocoaErrorDomain || nsErr.code != NSFileNoSuchFileError {
                Safety.log(
                    "[LocalJSONStore] Delete failed for \(fileURL.lastPathComponent): \(error)",
                    category: .general
                )
            }
        }
    }

    // MARK: - Private helpers

    /// Renames the corrupt file to `<name>.corrupt-<ISO8601timestamp>` in the same directory.
    private func quarantine(fm: FileManager) {
        let iso = ISO8601DateFormatter().string(from: Date())
        let quarantineName = "\(fileURL.lastPathComponent).corrupt-\(iso)"
        let quarantineURL = fileURL.deletingLastPathComponent().appendingPathComponent(quarantineName)
        do {
            try fm.moveItem(at: fileURL, to: quarantineURL)
            Safety.log(
                "[LocalJSONStore] Quarantined \(fileURL.lastPathComponent) → \(quarantineName)",
                category: .general
            )
        } catch {
            Safety.log(
                "[LocalJSONStore] Failed to quarantine \(fileURL.lastPathComponent): \(error)",
                category: .general
            )
        }
    }
}
