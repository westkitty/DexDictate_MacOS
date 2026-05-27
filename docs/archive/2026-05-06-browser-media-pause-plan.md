# Archived Implementation Plan: Browser Media Pause

> Status: Archived reference.
>
> This document is retained for historical/design reference only. It is not an active task.
> Do not mix this browser media pause plan with browser Zoom stabilization work unless the feature is explicitly reopened.
>
> PII/secrets review note: This document was reviewed during the repository PII/secrets cleanup. The public project identity `westkitty` is approved and intentionally left unredacted.

# Pause Browser Media During Dictation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional setting that pauses HTML video/audio in Chrome-family browsers when dictation starts, then resumes only the media DexDictate paused — skipping entirely when Zoom is running.

**Architecture:** A new `BrowserMediaControlling` protocol (with injectable dependencies for testability) wraps AppleScript-driven JavaScript execution per browser. `TranscriptionEngine` owns an instance, fires pause as a detached Task before `startRecordingAsync`, and calls resume from all dictation exit paths. The setting is `@AppStorage("pauseBrowserMediaDuringDictation_v1")` and the UI toggle goes in the Output panel of QuickSettingsView.

**Tech Stack:** Swift 5.9, AppKit (NSWorkspace, NSAppleScript, Process), SwiftUI, XCTest

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `Sources/DexDictateKit/Services/BrowserMediaPauseService.swift` | Protocol, value types, production implementation |
| Modify | `Sources/DexDictateKit/Settings/AppSettings.swift` | Add `pauseBrowserMediaDuringDictation_v1` setting |
| Modify | `Sources/DexDictateKit/TranscriptionEngine.swift` | Inject controller, pause before recording, resume on all exits |
| Modify | `docs/DEXDICTATE_BIBLE.md` | Construction log entry |

---

## Task 1: Add Setting to AppSettings

**Files:**
- Modify: `Sources/DexDictateKit/Settings/AppSettings.swift`

- [ ] **Step 1: Add the @AppStorage property**

In the `// MARK: - Output` section, after `enableSilenceTrim`, add:

```swift
/// When `true`, DexDictate pauses browser HTML video/audio before recording and
/// resumes only elements it paused when dictation ends. Skipped when Zoom is active.
@AppStorage("pauseBrowserMediaDuringDictation_v1") public var pauseBrowserMediaDuringDictation: Bool = false
```

- [ ] **Step 2: Add reset in restoreDefaults()**

In `restoreDefaults()`, after `enableSilenceTrim = false`, add:

```swift
pauseBrowserMediaDuringDictation = false
```

- [ ] **Step 3: Verify file compiles**

```bash
cd "<project-root>"
swift build 2>&1 | grep -E "error:|Build complete"
```

Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add "Sources/DexDictateKit/Settings/AppSettings.swift"
git commit -m "feat: add pauseBrowserMediaDuringDictation_v1 setting"
```

---

## Task 2: Create BrowserMediaPauseService

**Files:**
- Create: `Sources/DexDictateKit/Services/BrowserMediaPauseService.swift`

- [ ] **Step 1: Write the failing test stubs** (these will be filled in Task 5; create the file now as a placeholder)

Skip — tests come in Task 5. Write the service file now.

- [ ] **Step 2: Create the service file**

Create `Sources/DexDictateKit/Services/BrowserMediaPauseService.swift` with the following complete content:

```swift
import AppKit

// MARK: - Public types

/// A snapshot of browser media that DexDictate paused during a dictation session.
/// The resume script uses the `data-dexdictatePaused` DOM marker — not this struct —
/// to identify elements to resume. This struct records which browsers were targeted
/// and how many elements were paused so callers know whether a meaningful session exists.
public struct BrowserMediaPauseSession: Sendable {
    public struct BrowserEntry: Sendable {
        public let bundleIdentifier: String
        public let pausedCount: Int
    }
    public let entries: [BrowserEntry]

    public var hasPausedMedia: Bool {
        entries.contains { $0.pausedCount > 0 }
    }

    public init(entries: [BrowserEntry]) {
        self.entries = entries
    }
}

// MARK: - Protocol

/// Abstraction over browser media control. Inject a mock in tests.
public protocol BrowserMediaControlling: Sendable {
    /// Pauses all playing HTML media in supported browsers, if the feature is enabled
    /// and no protected app (e.g. Zoom) is running. Returns `nil` when skipped.
    func pauseIfNeeded() async -> BrowserMediaPauseSession?

    /// Resumes only elements that DexDictate marked with `data-dexdictatePaused`.
    /// Never resumes elements that were already paused before dictation.
    /// Failures are silently swallowed — must not affect dictation completion.
    func resume(session: BrowserMediaPauseSession) async
}

// MARK: - Production implementation

/// Drives Chrome-family browsers via AppleScript + JavaScript.
///
/// Safari is explicitly excluded: "Allow JavaScript from Apple Events" must be
/// manually enabled in Safari's developer menu and is disabled by default, making
/// it unreliable and potentially surprising for users. Document this in BIBLE.md.
public final class BrowserMediaPauseService: BrowserMediaControlling {

    // MARK: - Configuration

    /// Bundle identifiers of apps whose presence causes the pause feature to be skipped.
    public static let protectedBundleIdentifiers: Set<String> = ["us.zoom.xos"]

    /// Supported browsers in preference order.
    static let supportedBrowsers: [(displayName: String, bundleID: String)] = [
        ("Google Chrome",   "com.google.Chrome"),
        ("Brave Browser",   "com.brave.Browser"),
        ("Microsoft Edge",  "com.microsoft.edgemac"),
    ]

    // JavaScript injected into each tab to pause playing media and mark paused elements.
    static let pauseScript = """
    (() => {
      let pausedCount = 0;
      document.querySelectorAll("video,audio").forEach((el) => {
        if (!el.paused && !el.ended) {
          el.dataset.dexdictatePaused = "true";
          el.pause();
          pausedCount += 1;
        }
      });
      return pausedCount;
    })()
    """

    // JavaScript injected to resume only elements DexDictate paused.
    static let resumeScript = """
    (() => {
      let resumedCount = 0;
      document.querySelectorAll("video,audio").forEach((el) => {
        if (el.dataset.dexdictatePaused === "true") {
          delete el.dataset.dexdictatePaused;
          el.play();
          resumedCount += 1;
        }
      });
      return resumedCount;
    })()
    """

    // MARK: - Injectable dependencies

    public typealias RunningAppsProvider = @Sendable () -> [NSRunningApplication]
    /// Runs an AppleScript string and returns its integer result (0 on error).
    public typealias ScriptRunner = @Sendable (_ script: String) async -> Int

    private let runningAppsProvider: RunningAppsProvider
    private let scriptRunner: ScriptRunner
    private let settingsProvider: @Sendable () -> Bool

    // MARK: - Init

    public init(
        runningAppsProvider: @escaping RunningAppsProvider = { NSWorkspace.shared.runningApplications },
        scriptRunner: @escaping ScriptRunner = BrowserMediaPauseService.defaultScriptRunner,
        settingsProvider: @escaping @Sendable () -> Bool = { AppSettings.shared.pauseBrowserMediaDuringDictation }
    ) {
        self.runningAppsProvider = runningAppsProvider
        self.scriptRunner = scriptRunner
        self.settingsProvider = settingsProvider
    }

    // MARK: - BrowserMediaControlling

    public func pauseIfNeeded() async -> BrowserMediaPauseSession? {
        guard settingsProvider() else { return nil }
        guard !isProtectedAppRunning() else {
            Safety.log("BrowserMediaPauseService — skipping pause: protected app is running", category: .audio)
            return nil
        }

        var entries: [BrowserMediaPauseSession.BrowserEntry] = []
        for browser in Self.supportedBrowsers {
            guard isBrowserRunning(bundleID: browser.bundleID) else { continue }
            let count = await pauseMediaInBrowser(displayName: browser.displayName, bundleID: browser.bundleID)
            entries.append(.init(bundleIdentifier: browser.bundleID, pausedCount: count))
        }

        guard !entries.isEmpty else { return nil }
        let session = BrowserMediaPauseSession(entries: entries)
        if session.hasPausedMedia {
            Safety.log("BrowserMediaPauseService — paused media in \(entries.filter { $0.pausedCount > 0 }.count) browser(s)", category: .audio)
        }
        return session
    }

    public func resume(session: BrowserMediaPauseSession) async {
        guard session.hasPausedMedia else { return }
        for entry in session.entries where entry.pausedCount > 0 {
            guard let browser = Self.supportedBrowsers.first(where: { $0.bundleID == entry.bundleIdentifier }) else { continue }
            _ = await resumeMediaInBrowser(displayName: browser.displayName, bundleID: entry.bundleIdentifier)
        }
    }

    // MARK: - Private helpers

    private func isProtectedAppRunning() -> Bool {
        let running = runningAppsProvider()
        return running.contains { app in
            guard let bid = app.bundleIdentifier else { return false }
            return Self.protectedBundleIdentifiers.contains(bid)
        }
    }

    private func isBrowserRunning(bundleID: String) -> Bool {
        runningAppsProvider().contains { $0.bundleIdentifier == bundleID }
    }

    private func pauseMediaInBrowser(displayName: String, bundleID: String) async -> Int {
        let script = appleScriptForAllTabs(bundleID: bundleID, js: Self.pauseScript, action: "pause")
        let count = await scriptRunner(script)
        if count > 0 {
            Safety.log("BrowserMediaPauseService — paused \(count) element(s) in \(displayName)", category: .audio)
        }
        return count
    }

    private func resumeMediaInBrowser(displayName: String, bundleID: String) async -> Int {
        let script = appleScriptForAllTabs(bundleID: bundleID, js: Self.resumeScript, action: "resume")
        let count = await scriptRunner(script)
        if count > 0 {
            Safety.log("BrowserMediaPauseService — resumed \(count) element(s) in \(displayName)", category: .audio)
        }
        return count
    }

    /// Builds an AppleScript that iterates all tabs in all windows of the given browser
    /// and executes the provided JS, summing integer return values.
    private func appleScriptForAllTabs(bundleID: String, js: String, action: String) -> String {
        // The JS is embedded in a quoted AppleScript string. We must escape backslashes
        // and double-quotes for AppleScript string literals.
        let escaped = js
            .replacingOccurrences(of: "\\", with: "\\\\")
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

    // MARK: - Default script runner

    /// Runs an AppleScript string synchronously on a background thread and returns
    /// the integer result. Returns 0 on any error. Marked nonisolated so it can be
    /// called from detached tasks.
    nonisolated public static func defaultScriptRunner(_ script: String) async -> Int {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = NSAppleScript(source: script)
                var errorDict: NSDictionary?
                let result = appleScript?.executeAndReturnError(&errorDict)
                if let errorDict {
                    Safety.log("BrowserMediaPauseService — AppleScript error: \(errorDict)", category: .audio)
                    continuation.resume(returning: 0)
                    return
                }
                let intValue = result?.int32Value.flatMap { Int($0) } ?? 0
                continuation.resume(returning: intValue)
            }
        }
    }
}
```
