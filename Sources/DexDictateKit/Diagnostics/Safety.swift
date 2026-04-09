import AppKit

/// Filesystem and diagnostic utilities called at app startup.
public struct Safety {
    private final class BundleLocator: NSObject {}

    private static let isRunningUnderTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private static let resourceBundleName = "DexDictate_MacOS_DexDictateKit.bundle"
    private static let requiredResourceMarkers = [
        ("tiny.en", "bin"),
        ("profanity_list", "json"),
    ]

    /// The bundle containing DexDictateKit's bundled resources (images, JSON, models).
    /// Use this instead of `Bundle.main` when accessing resources declared in this library target.
    public static let resourceBundle: Bundle = {
        if let bundle = resolveResourceBundle() {
            return bundle
        }

        NSLog("[DexDictate] WARNING: Failed to resolve \(resourceBundleName). Falling back to Bundle.main.")
        return Bundle.main
    }()

    /// URL to ~/Library/Application Support/DexDictate/
    static var appSupportURL: URL? {
        let fm = FileManager.default
        return try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("DexDictate")
    }

    private static let diagnosticsQueue = DispatchQueue(label: "com.dexdictate.diagnostics", qos: .utility)

    private static func resolveResourceBundle() -> Bundle? {
        for url in resourceBundleCandidateURLs() {
            guard let bundle = Bundle(url: url), bundleContainsRequiredResources(bundle) else {
                continue
            }
            return bundle
        }

        return nil
    }

    private static func resourceBundleCandidateURLs() -> [URL] {
        let locatorBundle = Bundle(for: BundleLocator.self)
        let candidateRoots = uniqueURLs([
            Bundle.main.bundleURL,
            Bundle.main.resourceURL,
            Bundle.main.sharedSupportURL,
            Bundle.main.executableURL?.deletingLastPathComponent(),
            locatorBundle.bundleURL,
            locatorBundle.resourceURL,
            locatorBundle.sharedSupportURL,
            locatorBundle.executableURL?.deletingLastPathComponent(),
        ] + Bundle.allBundles.flatMap { [$0.bundleURL, $0.resourceURL, $0.sharedSupportURL] })

        let candidateURLs = candidateRoots.flatMap { root in
            [
                root.appendingPathComponent(resourceBundleName, isDirectory: true),
                root.appendingPathComponent("Contents/Resources", isDirectory: true)
                    .appendingPathComponent(resourceBundleName, isDirectory: true),
                root.deletingLastPathComponent()
                    .appendingPathComponent(resourceBundleName, isDirectory: true),
            ]
        }

        return uniqueURLs(candidateURLs)
    }

    private static func bundleContainsRequiredResources(_ bundle: Bundle) -> Bool {
        requiredResourceMarkers.allSatisfy { resourceName, resourceExtension in
            bundle.url(forResource: resourceName, withExtension: resourceExtension) != nil
        }
    }

    private static func uniqueURLs(_ urls: [URL?]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []

        for url in urls.compactMap({ $0?.standardizedFileURL }) where seen.insert(url.path).inserted {
            result.append(url)
        }

        return result
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

    /// Writes a diagnostic message to NSLog (appears in Console.app) and to local log files.
    ///
    /// Logging stays local-only. Structured records are retained in bounded JSONL form.
    public static func log(_ message: String, category: DiagnosticCategory = .general) {
        NSLog("[DexDictate] %@", message)
        guard !isRunningUnderTests, let dir = appSupportURL else { return }

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
