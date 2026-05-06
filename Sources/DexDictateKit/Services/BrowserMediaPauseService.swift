import AppKit

// MARK: - Session

public struct BrowserMediaPauseSession: Sendable {
    public struct BrowserEntry: Sendable {
        public let bundleIdentifier: String
        public let pausedCount: Int
    }
    public let entries: [BrowserEntry]
    public var hasPausedMedia: Bool { entries.contains { $0.pausedCount > 0 } }
    public init(entries: [BrowserEntry]) { self.entries = entries }
}

// MARK: - Protocol

public protocol BrowserMediaControlling: Sendable {
    func pauseIfNeeded() async -> BrowserMediaPauseSession?
    func resume(session: BrowserMediaPauseSession) async
}

// MARK: - Service

public final class BrowserMediaPauseService: BrowserMediaControlling {

    /// Returns the bundle identifiers of currently running applications.
    /// Changed from `[NSRunningApplication]` to `[String]` so tests can inject
    /// arbitrary bundle IDs without needing real system processes.
    public typealias RunningAppsProvider = @Sendable () -> [String]
    public typealias ScriptRunner = @Sendable (_ script: String) async -> Int

    public static let protectedBundleIdentifiers: Set<String> = ["us.zoom.xos"]

    // Safari excluded: it does not support `execute tab javascript` via AppleScript.
    static let supportedBrowsers: [(displayName: String, bundleID: String)] = [
        ("Google Chrome", "com.google.Chrome"),
        ("Brave Browser", "com.brave.Browser"),
        ("Microsoft Edge",  "com.microsoft.edgemac"),
    ]

    static let pauseScript: String = """
        (function(){
            var els = document.querySelectorAll('video,audio');
            var count = 0;
            for (var i = 0; i < els.length; i++) {
                var el = els[i];
                if (!el.paused && !el.ended) {
                    el.dataset.dexdictatePaused = 'true';
                    el.pause();
                    count++;
                }
            }
            return count;
        })()
        """

    static let resumeScript: String = """
        (function(){
            var els = document.querySelectorAll('video,audio');
            var count = 0;
            for (var i = 0; i < els.length; i++) {
                var el = els[i];
                if (el.dataset.dexdictatePaused === 'true') {
                    delete el.dataset.dexdictatePaused;
                    el.play();
                    count++;
                }
            }
            return count;
        })()
        """

    private let runningAppsProvider: RunningAppsProvider
    private let scriptRunner: ScriptRunner
    private let settingsProvider: @Sendable () -> Bool

    public init(
        runningAppsProvider: @escaping RunningAppsProvider = { NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier) },
        scriptRunner: @escaping ScriptRunner = BrowserMediaPauseService.defaultScriptRunner,
        // TODO: wire to AppSettings.shared.pauseBrowserMediaDuringDictation
        settingsProvider: @escaping @Sendable () -> Bool = { false }
    ) {
        self.runningAppsProvider = runningAppsProvider
        self.scriptRunner = scriptRunner
        self.settingsProvider = settingsProvider
    }

    // MARK: - BrowserMediaControlling

    public func pauseIfNeeded() async -> BrowserMediaPauseSession? {
        guard settingsProvider() else { return nil }
        guard !isProtectedAppRunning() else {
            Safety.log("BrowserMediaPauseService: skipping pause — protected app is running", category: .audio)
            return nil
        }
        var entries: [BrowserMediaPauseSession.BrowserEntry] = []
        for browser in Self.supportedBrowsers {
            guard isBrowserRunning(bundleID: browser.bundleID) else { continue }
            let count = await pauseMediaInBrowser(displayName: browser.displayName, bundleID: browser.bundleID)
            entries.append(.init(bundleIdentifier: browser.bundleID, pausedCount: count))
        }
        guard !entries.isEmpty else { return nil }
        let total = entries.reduce(0) { $0 + $1.pausedCount }
        if total > 0 {
            Safety.log("BrowserMediaPauseService: paused \(total) media element(s) across browsers", category: .audio)
        }
        return BrowserMediaPauseSession(entries: entries)
    }

    public func resume(session: BrowserMediaPauseSession) async {
        guard session.hasPausedMedia else { return }
        for entry in session.entries where entry.pausedCount > 0 {
            guard let browser = Self.supportedBrowsers.first(where: { $0.bundleID == entry.bundleIdentifier }) else {
                Safety.log("BrowserMediaPauseService: resume skipped unknown bundleID \(entry.bundleIdentifier)", category: .audio)
                continue
            }
            _ = await resumeMediaInBrowser(displayName: browser.displayName, bundleID: browser.bundleID)
        }
    }

    // MARK: - Helpers

    private func isProtectedAppRunning() -> Bool {
        runningAppsProvider().contains { Self.protectedBundleIdentifiers.contains($0) }
    }

    private func isBrowserRunning(bundleID: String) -> Bool {
        runningAppsProvider().contains { $0 == bundleID }
    }

    private func pauseMediaInBrowser(displayName: String, bundleID: String) async -> Int {
        let script = appleScriptForAllTabs(bundleID: bundleID, js: Self.pauseScript)
        let count = await scriptRunner(script)
        if count > 0 {
            Safety.log("BrowserMediaPauseService: paused \(count) element(s) in \(displayName)", category: .audio)
        }
        return count
    }

    private func resumeMediaInBrowser(displayName: String, bundleID: String) async -> Int {
        let script = appleScriptForAllTabs(bundleID: bundleID, js: Self.resumeScript)
        let count = await scriptRunner(script)
        if count > 0 {
            Safety.log("BrowserMediaPauseService: resumed \(count) element(s) in \(displayName)", category: .audio)
        }
        return count
    }

    private func appleScriptForAllTabs(bundleID: String, js: String) -> String {
        // Escape order matters: backslashes first, then newlines (AppleScript string
        // literals cannot span lines), then double-quotes.
        let escaped = js
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
            tell application id "\(bundleID)"
                set totalCount to 0
                repeat with w in windows
                    repeat with t in tabs of w
                        try
                            set tabResult to execute t javascript "\(escaped)"
                            if class of tabResult is integer then
                                set totalCount to totalCount + tabResult
                            end if
                        end try
                    end repeat
                end repeat
                return totalCount
            end tell
            """
    }

    // MARK: - Default Script Runner

    /// Runs an AppleScript string via `osascript` and returns the integer result (0 on any error).
    /// Uses Process rather than NSAppleScript to avoid Swift bridging issues with
    /// NSAppleEventDescriptor value accessors on macOS 26 / Swift 6.
    nonisolated public static func defaultScriptRunner(_ script: String) async -> Int {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: Int(output) ?? 0)
                } catch {
                    Safety.log("BrowserMediaPauseService: osascript launch failed — \(error)", category: .audio)
                    continuation.resume(returning: 0)
                }
            }
        }
    }
}
