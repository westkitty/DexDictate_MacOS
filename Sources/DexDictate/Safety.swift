import ServiceManagement
import AppKit

/// Filesystem and diagnostic utilities called at app startup.
struct Safety {

    /// Creates `~/Library/Application Support/DexDictate/` if it does not already exist.
    ///
    /// Called once from `DexDictateApp.init()` before any other setup runs.
    static func setupDirectories() {
        let fileManager = FileManager.default
        let appSupport = try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        if let dir = appSupport?.appendingPathComponent("DexDictate") {
             try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }
    /// Opens Console.app to help the user inspect system logs during troubleshooting.
    static func openLogs() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
    }
}
