import ServiceManagement
import AppKit

/// Filesystem and diagnostic utilities called at app startup.
public struct Safety {

    /// The bundle containing DexDictateKit's bundled resources (images, JSON, models).
    /// Use this instead of `Bundle.main` when accessing resources declared in this library target.
    public static let resourceBundle: Bundle = Bundle.module

    /// URL to ~/Library/Application Support/DexDictate/
    static var appSupportURL: URL? {
        let fm = FileManager.default
        return try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("DexDictate")
    }

    private static let diagnosticsQueue = DispatchQueue(label: "com.dexdictate.diagnostics", qos: .utility)

    /// Creates `~/Library/Application Support/DexDictate/` if it does not already exist.
    ///
    /// Called once from `DexDictateApp.init()` before any other setup runs.
    public static func setupDirectories() {
        let fileManager = FileManager.default
        if let dir = appSupportURL {
             try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }

    /// Writes a diagnostic message to NSLog (appears in Console.app) and to local log files.
    ///
    /// Logging stays local-only. Structured records are retained in bounded JSONL form.
    public static func log(_ message: String, category: DiagnosticCategory = .general) {
        NSLog("[DexDictate] %@", message)
        guard let dir = appSupportURL else { return }

        diagnosticsQueue.async {
            let record = DiagnosticRecord(timestamp: Date(), category: category, message: message)
            DiagnosticsStore(directoryURL: dir).append(record)
            appendLegacyLogLine(message, in: dir)
        }
    }

    /// Opens Console.app to help the user inspect system logs during troubleshooting.
    public static func openLogs() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
    }

    private static func appendLegacyLogLine(_ message: String, in directory: URL) {
        let logURL = directory.appendingPathComponent("debug.log")
        let line = "\(Date()): \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logURL.path) {
            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }
}
