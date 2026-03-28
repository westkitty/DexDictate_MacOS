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
