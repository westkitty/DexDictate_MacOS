import Foundation
import AppKit
import CryptoKit

public enum WhisperModelOrigin: String, Codable {
    case bundled
    case imported
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

        availableModels = models
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
