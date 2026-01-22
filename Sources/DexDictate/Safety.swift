import ServiceManagement
import AppKit

struct Safety {
    static func setupDirectories() {
        let fileManager = FileManager.default
        let appSupport = try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        if let dir = appSupport?.appendingPathComponent("DexDictate") {
             try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }
    static func openLogs() { 
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
    }
}
