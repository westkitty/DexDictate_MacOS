import Foundation

public enum DiagnosticCategory: String, Codable {
    case general
    case lifecycle
    case permissions
    case input
    case audio
    case transcription
    case settings
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
              let line = String(data: encoded, encoding: .utf8) else {
            return
        }

        let existingLines: [String]
        if let data = try? Data(contentsOf: logURL),
           let string = String(data: data, encoding: .utf8) {
            existingLines = string
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(String.init)
        } else {
            existingLines = []
        }

        let pruned = Array((existingLines + [line]).suffix(maxRecords))
        let payload = pruned.joined(separator: "\n") + "\n"
        try? payload.write(to: logURL, atomically: true, encoding: .utf8)
    }
}
