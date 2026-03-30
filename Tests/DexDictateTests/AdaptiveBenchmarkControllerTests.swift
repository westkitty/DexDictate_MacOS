import XCTest
@testable import DexDictateKit

@MainActor
final class AdaptiveBenchmarkControllerTests: XCTestCase {
    func testCancelForDictationCancelsScheduledBenchmark() throws {
        let catalog = try makeCatalogWithImportedBaseModel()

        let settings = AppSettings.shared
        defer { settings.restoreDefaults() }
        settings.activeWhisperModelID = "tiny.en"
        settings.modelSelectionMode = .autoIdleBenchmark

        let controller = AdaptiveBenchmarkController(
            helperURLResolver: { URL(fileURLWithPath: "/bin/true") },
            catalogProvider: { catalog },
            resultsStoreProvider: { .shared },
            initialDelayNs: 60_000_000_000,
            postDictationDelayNs: 60_000_000_000
        )

        let engine = TranscriptionEngine()
        engine.state = .ready
        controller.start(engine: engine)

        XCTAssertEqual(controller.status, .scheduled)

        controller.cancelForDictation()
        XCTAssertEqual(controller.status, .cancelled)
    }

    func testScheduleIfNeededMarksUnavailableWhenHelperMissing() throws {
        let catalog = try makeCatalogWithImportedBaseModel()

        let settings = AppSettings.shared
        defer { settings.restoreDefaults() }
        settings.activeWhisperModelID = "tiny.en"
        settings.modelSelectionMode = .autoIdleBenchmark

        let controller = AdaptiveBenchmarkController(
            helperURLResolver: { nil },
            catalogProvider: { catalog },
            resultsStoreProvider: { .shared },
            initialDelayNs: 1,
            postDictationDelayNs: 1
        )

        let engine = TranscriptionEngine()
        engine.state = .ready
        controller.start(engine: engine)

        XCTAssertEqual(controller.status, .unavailable("VerificationRunner helper unavailable"))
    }

    func testRunBenchmarksNowPausesWhileEngineIsBusy() throws {
        let controller = AdaptiveBenchmarkController(
            helperURLResolver: { URL(fileURLWithPath: "/bin/true") },
            initialDelayNs: 1,
            postDictationDelayNs: 1
        )

        let engine = TranscriptionEngine()
        engine.state = .listening
        controller.start(engine: engine)
        controller.runBenchmarksNow()

        XCTAssertEqual(controller.status, .paused)
    }

    func testScheduleIfNeededUsesInjectedPostDictationDelay() throws {
        let catalog = try makeCatalogWithImportedBaseModel()

        let settings = AppSettings.shared
        defer { settings.restoreDefaults() }
        settings.activeWhisperModelID = "tiny.en"
        settings.modelSelectionMode = .autoIdleBenchmark

        let controller = AdaptiveBenchmarkController(
            helperURLResolver: { URL(fileURLWithPath: "/bin/true") },
            catalogProvider: { catalog },
            resultsStoreProvider: { .shared },
            initialDelayNs: 60_000_000_000,
            postDictationDelayNs: 1_000_000
        )

        let engine = TranscriptionEngine()
        engine.state = .ready
        controller.start(engine: engine)
        controller.noteDictationFinished()
        controller.scheduleIfNeeded()

        XCTAssertEqual(controller.status, .scheduled)
    }

    func testLatestStrictCapturedCorpusPrefersValidSession() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appSupportURL = tempRoot.appendingPathComponent("DexDictate", isDirectory: true)
        let capturesRoot = appSupportURL.appendingPathComponent("BenchmarkCaptures", isDirectory: true)
        try FileManager.default.createDirectory(at: capturesRoot, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let invalidSession = capturesRoot.appendingPathComponent("benchmark-capture-invalid", isDirectory: true)
        try FileManager.default.createDirectory(at: invalidSession, withIntermediateDirectories: true)
        try JSONEncoder().encode(["sample.wav": "not the strict corpus"])
            .write(to: invalidSession.appendingPathComponent("transcripts.json"))
        try Data().write(to: invalidSession.appendingPathComponent("sample.wav"))

        let validSession = capturesRoot.appendingPathComponent("benchmark-capture-valid", isDirectory: true)
        try FileManager.default.createDirectory(at: validSession, withIntermediateDirectories: true)
        try JSONEncoder().encode(BenchmarkCorpus.strictTranscriptMap)
            .write(to: validSession.appendingPathComponent("transcripts.json"))
        for fileName in BenchmarkCorpus.strictTranscriptMap.keys {
            try Data().write(to: validSession.appendingPathComponent(fileName))
        }

        try FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: invalidSession.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-60)],
            ofItemAtPath: validSession.path
        )

        let resolved = BenchmarkCorpusLocator.latestStrictCapturedCorpusDirectory(appSupportURL: appSupportURL)
        XCTAssertEqual(resolved?.standardizedFileURL, validSession.standardizedFileURL)
    }

    func testStrictCapturedCorpusValidationRejectsBundledSampleShape() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        try JSONEncoder().encode(["sample.wav": "this is a test of the benchmark harness"])
            .write(to: tempDirectory.appendingPathComponent("transcripts.json"))
        try Data().write(to: tempDirectory.appendingPathComponent("sample.wav"))

        XCTAssertFalse(BenchmarkCorpusLocator.isStrictCapturedCorpusDirectory(tempDirectory))
    }

    private func makeCatalogWithImportedBaseModel() throws -> WhisperModelCatalog {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let tinyURL = tempDirectory.appendingPathComponent("tiny.en.bin")
        let baseURL = tempDirectory.appendingPathComponent("base.en.bin")
        try Data("tiny".utf8).write(to: tinyURL)
        try Data("base".utf8).write(to: baseURL)

        let catalog = WhisperModelCatalog(
            supportDirectoryURL: tempDirectory.appendingPathComponent("Support"),
            bundledModelURLs: ["tiny.en": tinyURL]
        )
        _ = try catalog.importModel(from: baseURL)
        return catalog
    }
}
