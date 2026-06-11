import Foundation

public enum DiagnosticCategory: String, Codable {
    case general
    case lifecycle
    case permissions
    case input
    case audio
    case transcription
    case settings
    case output
}

struct DiagnosticRecord: Codable, Equatable {
    let timestamp: Date
    let category: DiagnosticCategory
    let message: String
}

struct DiagnosticsStore {
    let directoryURL: URL
    let fileName: String
    let maxRecords: Int

    init(directoryURL: URL, fileName: String = "diagnostics.jsonl", maxRecords: Int = 500) {
        self.directoryURL = directoryURL
        self.fileName = fileName
        self.maxRecords = max(1, maxRecords)
    }

    var logURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }

    func append(_ record: DiagnosticRecord) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let encoded = try? encoder.encode(record),
              let lineString = String(data: encoded, encoding: .utf8),
              let lineData = (lineString + "\n").data(using: .utf8) else {
            return
        }

        // Create file if it doesn't exist, then append.
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: logURL) else { return }
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(lineData)

        // Prune when file size exceeds a conservative per-line estimate.
        // Using 80 bytes/line (the minimum serialized DiagnosticRecord size) ensures
        // pruning fires reliably for both short test records and production records.
        let approxBytesThreshold = maxRecords * 80
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: logURL.path)[.size] as? Int) ?? 0
        if fileSize > approxBytesThreshold {
            pruneIfNeeded()
        }
    }

    private func pruneIfNeeded() {
        guard let data = try? Data(contentsOf: logURL),
              let string = String(data: data, encoding: .utf8) else { return }

        let lines = string
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        guard lines.count > maxRecords else { return }

        let kept = Array(lines.suffix(maxRecords))
        let payload = kept.joined(separator: "\n") + "\n"
        try? payload.write(to: logURL, atomically: true, encoding: .utf8)
    }
}
