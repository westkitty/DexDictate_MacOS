import Foundation
import AppKit
import CryptoKit

public enum WhisperModelOrigin: String, Codable {
    case bundled
    case imported
    /// A whisper.cpp GGML model the user placed directly in the Models directory
    /// (discovered by scanning, not via the in-app import flow). Kept distinct from
    /// `.imported` so the "remove imported" path never deletes user-managed files.
    case installed
}

public struct WhisperModelDescriptor: Identifiable, Equatable {
    public let id: String
    public let displayName: String
    public let fileName: String
    public let origin: WhisperModelOrigin
    public let url: URL
    public let fileSizeBytes: UInt64
    public let sha256: String?

    public var isBundled: Bool { origin == .bundled }
}

private struct ImportedModelMetadata: Codable, Equatable {
    let id: String
    let originalFileName: String
    let storedFileName: String
    let fileSizeBytes: UInt64
    let sha256: String
    let importedAt: Date
}

@MainActor
public final class WhisperModelCatalog: ObservableObject {
    public static let shared = WhisperModelCatalog()

    @Published public private(set) var availableModels: [WhisperModelDescriptor] = []
    @Published public private(set) var lastImportError: String?
    /// Set when the persisted model selection could not be found on disk and the catalog
    /// fell back to another model. Surfaced in the UI so the fallback is never silent.
    @Published public private(set) var availabilityWarning: String?

    private let fileManager: FileManager
    private let supportDirectoryOverride: URL?
    private let bundledModelURLs: [String: URL]?

    public init(
        fileManager: FileManager = .default,
        supportDirectoryURL: URL? = nil,
        bundledModelURLs: [String: URL]? = nil
    ) {
        self.fileManager = fileManager
        self.supportDirectoryOverride = supportDirectoryURL
        self.bundledModelURLs = bundledModelURLs
        refresh()
    }

    public func refresh() {
        var models: [WhisperModelDescriptor] = []

        let resolvedBundledModels = bundledModelURLs ?? [
            "tiny.en": Safety.resourceBundle.url(forResource: "tiny.en", withExtension: "bin")
        ].compactMapValues { $0 }

        if let tinyURL = resolvedBundledModels["tiny.en"],
           let tinySize = fileSize(for: tinyURL) {
            models.append(
                WhisperModelDescriptor(
                    id: "tiny.en",
                    displayName: "tiny.en (Bundled)",
                    fileName: tinyURL.lastPathComponent,
                    origin: .bundled,
                    url: tinyURL,
                    fileSizeBytes: tinySize,
                    sha256: nil
                )
            )
        }

        for metadata in loadImportedMetadata().sorted(by: { $0.id < $1.id }) {
            let url = modelsDirectoryURL.appendingPathComponent(metadata.storedFileName)
            guard fileManager.fileExists(atPath: url.path) else { continue }

            models.append(
                WhisperModelDescriptor(
                    id: metadata.id,
                    displayName: "\(metadata.id) (Imported)",
                    fileName: metadata.storedFileName,
                    origin: .imported,
                    url: url,
                    fileSizeBytes: metadata.fileSizeBytes,
                    sha256: metadata.sha256
                )
            )
        }

        // Discover whisper.cpp GGML model files the user placed directly in the Models
        // directory (no in-app import sidecar). Bundled and imported entries take
        // precedence on id collisions, so we never duplicate or shadow them.
        for url in scanInstalledModelFiles() {
            guard let recognized = Self.recognizedInstalledModel(fileName: url.lastPathComponent) else { continue }
            guard !models.contains(where: { $0.id == recognized.id }) else { continue }
            guard let size = fileSize(for: url), size > 0 else { continue }

            models.append(
                WhisperModelDescriptor(
                    id: recognized.id,
                    displayName: recognized.displayName,
                    fileName: url.lastPathComponent,
                    origin: .installed,
                    url: url,
                    fileSizeBytes: size,
                    sha256: nil
                )
            )
        }

        availableModels = models
    }

    /// Known whisper.cpp size stems mapped to their human-readable labels.
    private static let knownModelStems: [String: String] = [
        "tiny": "Tiny",
        "base": "Base",
        "small": "Small",
        "medium": "Medium",
        "large": "Large",
        "large-v1": "Large v1",
        "large-v2": "Large v2",
        "large-v3": "Large v3"
    ]

    /// Stems that also have an English-only (`.en`) entry in `downloadableCatalog`. A legacy,
    /// non-English `ggml-<stem>.bin` file for one of these (e.g. a `ggml-base.bin` fetched by
    /// hand via whisper.cpp's own `download-ggml-model.sh`, rather than through this app) is a
    /// genuinely different model from its `.en` catalog counterpart — but displayed as a bare
    /// `"Base"`, it looked confusingly like a duplicate of `"Base English"` sitting right next
    /// to it under Download, reading as though DexDictate had "forgotten" an already-downloaded
    /// model (BUG-007). `large`/`large-v1`/`large-v2`/`large-v3` have no `.en` counterpart at
    /// all, so no such ambiguity exists for them and they're deliberately excluded here.
    private static let stemsWithEnglishCatalogCounterpart: Set<String> = ["tiny", "base", "small", "medium"]

    /// Recognizes a whisper.cpp GGML model filename (e.g. `ggml-base.en.bin`) and returns a
    /// stable id plus a readable display label. Returns `nil` for anything that isn't a
    /// recognized GGML model file, so unrelated files in the directory are ignored.
    public static func recognizedInstalledModel(fileName: String) -> (id: String, displayName: String)? {
        let lower = fileName.lowercased()
        guard lower.hasPrefix("ggml-"), lower.hasSuffix(".bin") else { return nil }

        let core = String(lower.dropFirst("ggml-".count).dropLast(".bin".count))
        guard !core.isEmpty else { return nil }

        let isEnglish = core.hasSuffix(".en")
        let stem = isEnglish ? String(core.dropLast(".en".count)) : core
        guard let label = knownModelStems[stem] else { return nil }

        let displayName: String
        if isEnglish {
            displayName = "\(label) English"
        } else if stemsWithEnglishCatalogCounterpart.contains(stem) {
            displayName = "\(label) (Multilingual)"
        } else {
            displayName = label
        }
        return (id: core, displayName: displayName)
    }

    /// Returns the URLs of files directly inside the Models directory. Empty if the
    /// directory does not exist yet.
    private func scanInstalledModelFiles() -> [URL] {
        guard let items = try? fileManager.contentsOfDirectory(
            at: modelsDirectoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return items.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func descriptor(for id: String) -> WhisperModelDescriptor? {
        availableModels.first(where: { $0.id == id })
    }

    public func activeDescriptor(settings: AppSettings = .shared) -> WhisperModelDescriptor? {
        descriptor(for: settings.activeWhisperModelID) ?? descriptor(for: "tiny.en")
    }

    public var importedModels: [WhisperModelDescriptor] {
        availableModels.filter { $0.origin == .imported }
    }

    public struct ModelSelectionResolution: Equatable {
        public let resolvedID: String
        public let warning: String?
    }

    /// Validates a persisted model selection against the models currently available on disk.
    /// If the saved model is still present, returns it unchanged. Otherwise falls back to the
    /// best available model and records a user-facing warning (also published via
    /// `availabilityWarning`) so the fallback is never silent.
    @discardableResult
    public func resolveSelection(savedID: String) -> ModelSelectionResolution {
        if descriptor(for: savedID) != nil {
            availabilityWarning = nil
            return ModelSelectionResolution(resolvedID: savedID, warning: nil)
        }

        guard let best = bestAvailableModel() else {
            // No models at all — keep the saved id and warn.
            let warning = "No Whisper models are installed. Add a model file to the Models folder."
            availabilityWarning = warning
            return ModelSelectionResolution(resolvedID: savedID, warning: warning)
        }

        let warning = "Selected model “\(savedID)” is no longer installed. Falling back to “\(best.displayName)”."
        availabilityWarning = warning
        return ModelSelectionResolution(resolvedID: best.id, warning: warning)
    }

    /// The most capable model currently available, used as the fallback target.
    private func bestAvailableModel() -> WhisperModelDescriptor? {
        availableModels.max { Self.qualityRank(forID: $0.id) < Self.qualityRank(forID: $1.id) }
    }

    /// Relative accuracy ranking for a model id (higher = more accurate). English variants
    /// share the rank of their size stem; unknown ids rank lowest.
    private static func qualityRank(forID id: String) -> Int {
        let stem = id.hasSuffix(".en") ? String(id.dropLast(".en".count)) : id
        switch stem {
        case "tiny": return 0
        case "base": return 1
        case "small": return 2
        case "medium": return 3
        case "large": return 4
        case "large-v1": return 5
        case "large-v2": return 6
        case "large-v3": return 7
        default: return -1
        }
    }

    @discardableResult
    public func importModelFromOpenPanel() -> WhisperModelDescriptor? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        panel.prompt = "Import"
        panel.message = "Choose a local Whisper model file named base.en.bin or small.en.bin."

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        do {
            return try importModel(from: url)
        } catch {
            lastImportError = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    public func importModel(from sourceURL: URL) throws -> WhisperModelDescriptor {
        let allowedFileNames = ["base.en.bin", "small.en.bin"]
        let normalizedName = sourceURL.lastPathComponent.lowercased()

        guard allowedFileNames.contains(normalizedName) else {
            throw DictationError.unknown("Only base.en.bin and small.en.bin can be imported.")
        }

        let size = try fileSizeOrThrow(for: sourceURL)
        let sha256 = try Self.sha256(for: sourceURL)

        try fileManager.createDirectory(at: modelsDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: metadataDirectoryURL, withIntermediateDirectories: true)

        let id = normalizedName.replacingOccurrences(of: ".bin", with: "")
        let destinationURL = modelsDirectoryURL.appendingPathComponent(normalizedName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        let metadata = ImportedModelMetadata(
            id: id,
            originalFileName: sourceURL.lastPathComponent,
            storedFileName: normalizedName,
            fileSizeBytes: size,
            sha256: sha256,
            importedAt: Date()
        )
        let metadataURL = metadataDirectoryURL.appendingPathComponent("\(id).json")
        let encoded = try JSONEncoder().encode(metadata)
        try encoded.write(to: metadataURL, options: .atomic)

        refresh()
        lastImportError = nil
        return descriptor(for: id)
            ?? WhisperModelDescriptor(
                id: id,
                displayName: "\(id) (Imported)",
                fileName: normalizedName,
                origin: .imported,
                url: destinationURL,
                fileSizeBytes: size,
                sha256: sha256
            )
    }

    /// A Whisper model that can be fetched by URL, whether or not it's currently downloaded.
    /// Distinct from `WhisperModelDescriptor`, which only describes models already on disk.
    public struct WhisperDownloadableModel: Identifiable, Equatable {
        public let id: String
        public let displayName: String
        public let approximateSizeMB: Int
        public let downloadURL: URL
    }

    /// Every Whisper size DexDictate knows how to fetch, regardless of install state. Hosted at
    /// ggerganov/whisper.cpp's stable HuggingFace model mirror — the same files `whisper.cpp`
    /// itself documents downloading (`models/download-ggml-model.sh`).
    public static let downloadableCatalog: [WhisperDownloadableModel] = [
        "tiny.en": ("Tiny English", 75),
        "base.en": ("Base English", 142),
        "small.en": ("Small English", 466),
        "medium.en": ("Medium English", 1500),
        "large-v3": ("Large v3", 2900),
    ].compactMap { id, info in
        guard let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-\(id).bin") else {
            return nil
        }
        return WhisperDownloadableModel(id: id, displayName: info.0, approximateSizeMB: info.1, downloadURL: url)
    }

    /// The downloadable-catalog id currently being fetched, if any. Published for UI progress display.
    @Published public private(set) var downloadingModelID: String?
    public private(set) var lastDownloadError: String?

    /// Downloads a model from `WhisperModelCatalog.downloadableCatalog` and registers it exactly
    /// like a manually-imported one (same metadata sidecar, same `.imported` origin, discoverable
    /// afterward through `availableModels`). No-ops (returns the existing descriptor) if already
    /// downloaded. Explicit, user-triggered — never called automatically.
    @discardableResult
    public func downloadModel(_ entry: WhisperDownloadableModel) async throws -> WhisperModelDescriptor {
        if let existing = descriptor(for: entry.id) {
            return existing
        }
        guard downloadingModelID == nil else {
            throw DictationError.unknown("Another model download is already in progress.")
        }
        downloadingModelID = entry.id
        lastDownloadError = nil
        defer { downloadingModelID = nil }

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: entry.downloadURL)
            defer { try? fileManager.removeItem(at: tempURL) }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw DictationError.unknown("Failed to download \(entry.displayName) (unexpected server response).")
            }

            try fileManager.createDirectory(at: modelsDirectoryURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: metadataDirectoryURL, withIntermediateDirectories: true)

            let storedFileName = "\(entry.id).bin"
            let destinationURL = modelsDirectoryURL.appendingPathComponent(storedFileName)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: tempURL, to: destinationURL)

            let size = try fileSizeOrThrow(for: destinationURL)
            let sha256 = try Self.sha256(for: destinationURL)
            let metadata = ImportedModelMetadata(
                id: entry.id,
                originalFileName: storedFileName,
                storedFileName: storedFileName,
                fileSizeBytes: size,
                sha256: sha256,
                importedAt: Date()
            )
            let metadataURL = metadataDirectoryURL.appendingPathComponent("\(entry.id).json")
            let encoded = try JSONEncoder().encode(metadata)
            try encoded.write(to: metadataURL, options: .atomic)

            refresh()
            return descriptor(for: entry.id)
                ?? WhisperModelDescriptor(
                    id: entry.id,
                    displayName: "\(entry.displayName) (Imported)",
                    fileName: storedFileName,
                    origin: .imported,
                    url: destinationURL,
                    fileSizeBytes: size,
                    sha256: sha256
                )
        } catch {
            lastDownloadError = error.localizedDescription
            throw error
        }
    }

    public func removeImportedModel(id: String) {
        guard let model = descriptor(for: id), model.origin == .imported else { return }
        try? fileManager.removeItem(at: model.url)
        try? fileManager.removeItem(at: metadataDirectoryURL.appendingPathComponent("\(id).json"))
        refresh()
    }

    /// Computes the SHA-256 digest of the file at `url` using a streaming approach so
    /// that large model files (potentially hundreds of MB) are never fully loaded into RAM.
    /// Reads the file in 64 KB chunks, which keeps the memory footprint essentially flat
    /// regardless of file size.
    public static func sha256(for url: URL) throws -> String {
        guard let stream = InputStream(url: url) else {
            throw DictationError.unknown("Cannot open model file for hashing: \(url.lastPathComponent)")
        }
        stream.open()
        defer { stream.close() }

        var hasher = SHA256()
        let bufferSize = 65_536
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                throw DictationError.unknown(
                    "Read error while hashing \(url.lastPathComponent): \(stream.streamError?.localizedDescription ?? "unknown")"
                )
            }
            if bytesRead == 0 { break }
            hasher.update(data: Data(buffer[..<bytesRead]))
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadImportedMetadata() -> [ImportedModelMetadata] {
        guard let items = try? fileManager.contentsOfDirectory(at: metadataDirectoryURL, includingPropertiesForKeys: nil) else {
            return []
        }

        return items.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(ImportedModelMetadata.self, from: data)
        }
    }

    private func fileSize(for url: URL) -> UInt64? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.size] as? UInt64
    }

    private func fileSizeOrThrow(for url: URL) throws -> UInt64 {
        guard let size = fileSize(for: url), size > 0 else {
            throw DictationError.unknown("The model file is empty or unreadable.")
        }
        return size
    }

    private var supportDirectoryURL: URL {
        if let supportDirectoryOverride {
            return supportDirectoryOverride
        }
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("DexDictate", isDirectory: true)
    }

    private var modelsDirectoryURL: URL {
        supportDirectoryURL.appendingPathComponent("Models", isDirectory: true)
    }

    private var metadataDirectoryURL: URL {
        supportDirectoryURL.appendingPathComponent("ModelMetadata", isDirectory: true)
    }
}
