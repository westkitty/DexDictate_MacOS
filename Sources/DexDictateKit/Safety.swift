import ServiceManagement
import AppKit

/// Filesystem and diagnostic utilities called at app startup.
public struct Safety {

    /// The bundle containing DexDictateKit's bundled resources (images, JSON, models).
    /// Use this instead of `Bundle.main` when accessing resources declared in this library target.
    public static let resourceBundle: Bundle = Bundle.module

    /// URL to ~/Library/Application Support/DexDictate/
    private static var appSupportURL: URL? {
        let fm = FileManager.default
        return try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("DexDictate")
    }

    /// Creates `~/Library/Application Support/DexDictate/` if it does not already exist.
    ///
    /// Called once from `DexDictateApp.init()` before any other setup runs.
    public static func setupDirectories() {
        let fileManager = FileManager.default
        if let dir = appSupportURL {
             try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }

    /// Writes a diagnostic message to NSLog (appears in Console.app) and to a log file.
    ///
    /// In release builds this is a no-op. In debug builds:
    /// - NSLog output appears in Console.app when filtering by process "DexDictate"
    /// - Also appended to ~/Library/Application Support/DexDictate/debug.log
    public static func log(_ message: String) {
        #if DEBUG
        NSLog("[DexDictate] %@", message)
        if let dir = appSupportURL {
            let logURL = dir.appendingPathComponent("debug.log")
            let line = "\(Date()): \(message)\n"
            if let data = line.data(using: .utf8) {
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
        #endif
    }

    /// Opens Console.app to help the user inspect system logs during troubleshooting.
    public static func openLogs() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
    }
}
