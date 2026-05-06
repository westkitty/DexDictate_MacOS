import XCTest
@testable import DexDictateKit

// MARK: - Helpers

/// Thread-safe call counter for use inside @Sendable closures.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    var count: Int { lock.withLock { _count } }
    func increment() { lock.withLock { _count += 1 } }
}

/// Thread-safe array accumulator for use inside @Sendable closures.
private final class LockedArray<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [T] = []
    var values: [T] { lock.withLock { _values } }
    func append(_ value: T) { lock.withLock { _values.append(value) } }
}

/// Builds a BrowserMediaPauseSession manually for resume() tests.
private func makeSession(entries: [(bundleID: String, pausedCount: Int)]) -> BrowserMediaPauseSession {
    BrowserMediaPauseSession(
        entries: entries.map { .init(bundleIdentifier: $0.bundleID, pausedCount: $0.pausedCount) }
    )
}

// MARK: - Tests

final class BrowserMediaPauseServiceTests: XCTestCase {

    // MARK: - 1. Feature disabled → nil, no script calls

    func testFeatureDisabled_returnsNil_noScriptCalls() async {
        let scriptCallCount = Counter()

        let sut = BrowserMediaPauseService(
            runningAppsProvider: { ["com.google.Chrome"] },
            scriptRunner: { _ in scriptCallCount.increment(); return 3 },
            settingsProvider: { false }
        )

        let session = await sut.pauseIfNeeded()

        XCTAssertNil(session, "pauseIfNeeded() must return nil when the feature is disabled")
        XCTAssertEqual(scriptCallCount.count, 0, "scriptRunner must not be called when feature is disabled")
    }

    // MARK: - 2. Zoom running → skip entirely, no script calls

    func testZoomRunning_skipsPause_returnsNil() async {
        let scriptCallCount = Counter()

        let sut = BrowserMediaPauseService(
            runningAppsProvider: { ["us.zoom.xos", "com.google.Chrome"] },
            scriptRunner: { _ in scriptCallCount.increment(); return 3 },
            settingsProvider: { true }
        )

        let session = await sut.pauseIfNeeded()

        XCTAssertNil(session, "pauseIfNeeded() must return nil when a protected app (Zoom) is running")
        XCTAssertEqual(scriptCallCount.count, 0, "scriptRunner must not be called when Zoom is running")
    }

    // MARK: - 3. Browser running but script returns 0 → session returned, hasPausedMedia false, resume skips script

    func testBrowserRunning_scriptReturnsZero_sessionReturnedButNoPausedMedia() async {
        let sut = BrowserMediaPauseService(
            runningAppsProvider: { ["com.google.Chrome"] },
            scriptRunner: { _ in 0 },
            settingsProvider: { true }
        )

        let session = await sut.pauseIfNeeded()

        XCTAssertNotNil(session, "Session must be returned when a supported browser is running")
        XCTAssertFalse(session!.hasPausedMedia, "hasPausedMedia must be false when all pausedCounts are 0")
        XCTAssertEqual(session!.entries.count, 1)
        XCTAssertEqual(session!.entries[0].bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(session!.entries[0].pausedCount, 0)

        // Resume on a session with no paused media must not call the script runner
        let resumeCallCount = Counter()
        let resumeSut = BrowserMediaPauseService(
            runningAppsProvider: { ["com.google.Chrome"] },
            scriptRunner: { _ in resumeCallCount.increment(); return 0 },
            settingsProvider: { true }
        )
        await resumeSut.resume(session: session!)
        XCTAssertEqual(resumeCallCount.count, 0, "resume() must not call scriptRunner when hasPausedMedia is false")
    }

    // MARK: - 4. Chrome running with playing media → correct session entry

    func testChromePauses3Elements_sessionCaptured() async {
        let scriptCallCount = Counter()

        let sut = BrowserMediaPauseService(
            runningAppsProvider: { ["com.google.Chrome"] },
            scriptRunner: { _ in scriptCallCount.increment(); return 3 },
            settingsProvider: { true }
        )

        let session = await sut.pauseIfNeeded()

        XCTAssertNotNil(session)
        XCTAssertTrue(session!.hasPausedMedia)
        XCTAssertEqual(session!.entries.count, 1)
        XCTAssertEqual(session!.entries[0].bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(session!.entries[0].pausedCount, 3)
        XCTAssertEqual(scriptCallCount.count, 1, "scriptRunner must be called exactly once for one running browser")
    }

    // MARK: - 5. Multiple browsers running → all captured, script called once per browser

    func testMultipleBrowsersRunning_allCaptured() async {
        let scriptCallCount = Counter()

        // Chrome returns 2, Brave returns 1
        let sut = BrowserMediaPauseService(
            runningAppsProvider: { ["com.google.Chrome", "com.brave.Browser"] },
            scriptRunner: { script in
                scriptCallCount.increment()
                if script.contains("com.google.Chrome") { return 2 }
                if script.contains("com.brave.Browser") { return 1 }
                return 0
            },
            settingsProvider: { true }
        )

        let session = await sut.pauseIfNeeded()

        XCTAssertNotNil(session)
        XCTAssertTrue(session!.hasPausedMedia)
        XCTAssertEqual(session!.entries.count, 2, "Session must contain exactly one entry per running browser")
        XCTAssertEqual(scriptCallCount.count, 2, "scriptRunner must be called once per running supported browser")

        let chromeEntry = session!.entries.first { $0.bundleIdentifier == "com.google.Chrome" }
        let braveEntry  = session!.entries.first { $0.bundleIdentifier == "com.brave.Browser" }

        XCTAssertNotNil(chromeEntry, "Session must contain an entry for Chrome")
        XCTAssertNotNil(braveEntry,  "Session must contain an entry for Brave")
        XCTAssertEqual(chromeEntry?.pausedCount, 2)
        XCTAssertEqual(braveEntry?.pausedCount,  1)
    }

    // MARK: - 6. Resume only runs for entries with pausedCount > 0

    func testResume_onlyCallsScriptForEntriesWithPausedCount() async {
        let scriptCallCount = Counter()
        let resumedBundleIDs = LockedArray<String>()

        let sut = BrowserMediaPauseService(
            runningAppsProvider: { ["com.google.Chrome", "com.brave.Browser"] },
            scriptRunner: { script in
                scriptCallCount.increment()
                if script.contains("com.google.Chrome") { resumedBundleIDs.append("com.google.Chrome") }
                if script.contains("com.brave.Browser") { resumedBundleIDs.append("com.brave.Browser") }
                return 1
            },
            settingsProvider: { true }
        )

        // Build session manually: Chrome paused 2, Brave paused 0
        let session = makeSession(entries: [
            ("com.google.Chrome", 2),
            ("com.brave.Browser", 0)
        ])

        await sut.resume(session: session)

        XCTAssertEqual(scriptCallCount.count, 1, "resume() must only call scriptRunner for entries with pausedCount > 0")
        XCTAssertEqual(resumedBundleIDs.values, ["com.google.Chrome"])
    }

    // MARK: - 7. Resume with no paused media → scriptRunner not called at all

    func testResume_noPausedMedia_scriptNotCalled() async {
        let scriptCallCount = Counter()

        let sut = BrowserMediaPauseService(
            runningAppsProvider: { [] },
            scriptRunner: { _ in scriptCallCount.increment(); return 0 },
            settingsProvider: { true }
        )

        let session = makeSession(entries: [
            ("com.google.Chrome", 0),
            ("com.brave.Browser", 0)
        ])

        XCTAssertFalse(session.hasPausedMedia)
        await sut.resume(session: session)

        XCTAssertEqual(scriptCallCount.count, 0, "resume() must not call scriptRunner when hasPausedMedia is false")
    }

    // MARK: - 8. Script failure for browser A doesn't prevent browser B from being processed

    func testScriptFailureForOneBrowser_otherBrowserStillProcessed() async {
        let scriptCallCount = Counter()

        // Chrome returns 0 (no media / failure), Brave returns 1
        let sut = BrowserMediaPauseService(
            runningAppsProvider: { ["com.google.Chrome", "com.brave.Browser"] },
            scriptRunner: { script in
                scriptCallCount.increment()
                if script.contains("com.google.Chrome") { return 0 }
                if script.contains("com.brave.Browser") { return 1 }
                return 0
            },
            settingsProvider: { true }
        )

        let session = await sut.pauseIfNeeded()

        XCTAssertNotNil(session)
        XCTAssertEqual(scriptCallCount.count, 2, "scriptRunner must be called for every running browser regardless of individual results")

        let chromeEntry = session!.entries.first { $0.bundleIdentifier == "com.google.Chrome" }
        let braveEntry  = session!.entries.first { $0.bundleIdentifier == "com.brave.Browser" }

        XCTAssertNotNil(chromeEntry)
        XCTAssertNotNil(braveEntry)
        XCTAssertEqual(chromeEntry?.pausedCount, 0, "Chrome entry must record count 0 on script failure")
        XCTAssertEqual(braveEntry?.pausedCount,  1, "Brave entry must record the correct paused count")
        XCTAssertTrue(session!.hasPausedMedia, "hasPausedMedia must be true because Brave paused media")
    }

    // MARK: - Invariant: Safari is not in supportedBrowsers

    func testSafariNotInSupportedBrowsers() {
        let safariID = "com.apple.Safari"
        let isSafariSupported = BrowserMediaPauseService.supportedBrowsers.contains { $0.bundleID == safariID }
        XCTAssertFalse(isSafariSupported, "Safari must not be in supportedBrowsers (it does not support execute tab javascript)")
    }

    // MARK: - Invariant: No browsers running → nil (not empty session)

    func testNoBrowsersRunning_returnsNil() async {
        let sut = BrowserMediaPauseService(
            runningAppsProvider: { [] },
            scriptRunner: { _ in 0 },
            settingsProvider: { true }
        )

        let session = await sut.pauseIfNeeded()
        XCTAssertNil(session, "pauseIfNeeded() must return nil when no supported browsers are running")
    }
}
