import XCTest
@testable import DexDictateKit

/// BUG-006A: `ModelSelectionActions` is the single shared layer Settings' "Active Dictation
/// Model" picker, its "Model Library" list, and the popover's model chip all read/write through
/// — these tests exercise that layer directly so the three surfaces can't silently drift apart
/// again. `AppSettings` is `@AppStorage`-backed by `UserDefaults.standard` with no override hook
/// (same constraint `AppSettingsRestoreDefaultsTests`/`AdaptiveBenchmarkControllerTests` work
/// under), so every test that touches `preferredPrimaryEngineID`, `liveTranscriptionEnabled`, or
/// `commandModeEnabled` (none of which `restoreDefaults()` resets) saves and restores them.
@MainActor
final class ModelSelectionActionsTests: XCTestCase {
    private func makeIsolatedCatalog() throws -> WhisperModelCatalog {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let tinyURL = tempDirectory.appendingPathComponent("tiny.en.bin")
        try Data("tiny".utf8).write(to: tinyURL)
        return WhisperModelCatalog(
            supportDirectoryURL: tempDirectory.appendingPathComponent("Support"),
            bundledModelURLs: ["tiny.en": tinyURL]
        )
    }

    // MARK: - The core BUG-006A binding fix

    func testApplyWhisperSelectionUpdatesActiveModelAndPinsWhisperAsPrimary() {
        let settings = AppSettings.shared
        let originalActiveModel = settings.activeWhisperModelID
        let originalPin = settings.preferredPrimaryEngineID
        defer {
            settings.activeWhisperModelID = originalActiveModel
            settings.preferredPrimaryEngineID = originalPin
        }

        settings.preferredPrimaryEngineID = TranscriptionProviderID.parakeetTDT06Bv3.rawValue

        ModelSelectionActions.applyWhisperSelection(id: "medium.en", settings: settings)

        // This is the exact binding BUG-006A fixed: selecting a Whisper model must flip the real
        // primary-engine pin, not just record which size *would* be used if Whisper were already
        // primary.
        XCTAssertEqual(settings.activeWhisperModelID, "medium.en")
        XCTAssertEqual(settings.preferredPrimaryEngineID, TranscriptionProviderID.whisperKit.rawValue)
    }

    func testApplyProviderSelectionForEngineRolesNeverPinsPrimaryEngine() {
        let settings = AppSettings.shared
        let originalPin = settings.preferredPrimaryEngineID
        let originalLiveTranscription = settings.liveTranscriptionEnabled
        let originalCommandMode = settings.commandModeEnabled
        defer {
            settings.preferredPrimaryEngineID = originalPin
            settings.liveTranscriptionEnabled = originalLiveTranscription
            settings.commandModeEnabled = originalCommandMode
        }

        settings.preferredPrimaryEngineID = ""
        settings.liveTranscriptionEnabled = false
        settings.commandModeEnabled = false

        ModelSelectionActions.applyProviderSelection(.nemotron35ASRStreaming06B, settings: settings)
        XCTAssertTrue(settings.liveTranscriptionEnabled, "Nemotron should enable the Live Transcription feature toggle")
        XCTAssertEqual(settings.preferredPrimaryEngineID, "", "Nemotron must never become the pinned primary dictation engine")

        ModelSelectionActions.applyProviderSelection(.moonshineV2, settings: settings)
        XCTAssertTrue(settings.commandModeEnabled, "Moonshine should enable the Command Mode feature toggle")
        XCTAssertEqual(settings.preferredPrimaryEngineID, "", "Moonshine must never become the pinned primary dictation engine")
    }

    func testActiveModelRowsReflectSameStateSettingsAndPopoverShare() throws {
        let catalog = try makeIsolatedCatalog()
        let settings = AppSettings.shared
        let registry = TranscriptionEngine().transcriptionProviderRegistry
        let originalActiveModel = settings.activeWhisperModelID
        let originalPin = settings.preferredPrimaryEngineID
        defer {
            settings.activeWhisperModelID = originalActiveModel
            settings.preferredPrimaryEngineID = originalPin
        }

        ModelSelectionActions.applyWhisperSelection(id: "tiny.en", settings: settings)

        // Both Settings' "Active Dictation Model" picker and the popover's model chip build their
        // rows from this exact same call — if one of them showed something different, it would
        // have to be reading a different piece of state, which is precisely the bug this fixes.
        let rows = ModelSelectionActions.activeModelRows(settings: settings, registry: registry, modelCatalog: catalog)
        let selected = rows.filter(\.isSelected)
        XCTAssertEqual(selected.count, 1, "Exactly one row should be selected at a time")
        XCTAssertEqual(selected.first?.kind, .whisper(id: "tiny.en"))
    }

    // MARK: - Download-gated activation

    func testSelectWhisperWithUnknownDownloadableIDDoesNotActivate() async throws {
        let catalog = try makeIsolatedCatalog()
        let settings = AppSettings.shared
        let originalActiveModel = settings.activeWhisperModelID
        let originalPin = settings.preferredPrimaryEngineID
        defer {
            settings.activeWhisperModelID = originalActiveModel
            settings.preferredPrimaryEngineID = originalPin
        }
        settings.activeWhisperModelID = "tiny.en"
        settings.preferredPrimaryEngineID = TranscriptionProviderID.parakeetTDT06Bv3.rawValue

        // Not present in `WhisperModelCatalog.downloadableCatalog` — the guard must fail closed
        // rather than silently activating a model that was never actually fetched.
        await ModelSelectionActions.selectWhisper(
            id: "not-a-real-model", isInstalled: false, settings: settings, modelCatalog: catalog
        )

        XCTAssertEqual(settings.activeWhisperModelID, "tiny.en", "Unknown/undownloaded model must not become active")
        XCTAssertEqual(settings.preferredPrimaryEngineID, TranscriptionProviderID.parakeetTDT06Bv3.rawValue, "Primary engine pin must not change on a failed/skipped download")
    }

    // MARK: - Catalog display honesty

    func testWhisperRowsDistinguishInstalledFromDownloadable() throws {
        let catalog = try makeIsolatedCatalog()
        let rows = ModelSelectionActions.whisperRows(modelCatalog: catalog)

        let tiny = try XCTUnwrap(rows.first { $0.id == "tiny.en" })
        XCTAssertTrue(tiny.isInstalled)

        let mediumRow = try XCTUnwrap(rows.first { $0.id == "medium.en" })
        XCTAssertFalse(mediumRow.isInstalled)
        XCTAssertTrue(mediumRow.displayName.contains("MB"), "Downloadable rows must show their size, not read like an installed selection")

        // No id should ever appear twice (installed and downloadable both), regardless of catalog
        // contents.
        XCTAssertEqual(rows.map(\.id).count, Set(rows.map(\.id)).count)
    }

    func testWhisperRowsMarkImportedModelsInstalled() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let tinyURL = tempDirectory.appendingPathComponent("tiny.en.bin")
        try Data("tiny".utf8).write(to: tinyURL)
        let baseURL = tempDirectory.appendingPathComponent("base.en.bin")
        try Data("base".utf8).write(to: baseURL)

        let catalog = WhisperModelCatalog(
            supportDirectoryURL: tempDirectory.appendingPathComponent("Support"),
            bundledModelURLs: ["tiny.en": tinyURL]
        )
        _ = try catalog.importModel(from: baseURL)

        let rows = ModelSelectionActions.whisperRows(modelCatalog: catalog)
        let imported = try XCTUnwrap(rows.first { $0.id == "base.en" })
        XCTAssertTrue(imported.isInstalled)
        XCTAssertTrue(imported.displayName.contains("(Imported)"))
    }

    // MARK: - BUG-007: legacy multilingual installs must not mask their English counterpart

    /// Reproduces the exact real-world state that caused BUG-007: a `ggml-base.bin` placed
    /// directly in the Models directory (e.g. fetched by hand via whisper.cpp's own
    /// `download-ggml-model.sh`, not through this app) is a genuinely different model from the
    /// app's own `base.en` download-catalog entry. Both must appear as separate, honestly
    /// labeled rows — the installed multilingual model must not be conflated with, and must not
    /// suppress, the still-not-downloaded English row.
    func testLegacyMultilingualInstallDoesNotMaskEnglishCatalogCounterpart() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let tinyURL = tempDirectory.appendingPathComponent("tiny.en.bin")
        try Data("tiny".utf8).write(to: tinyURL)

        let supportDirectory = tempDirectory.appendingPathComponent("Support")
        let modelsDirectory = supportDirectory.appendingPathComponent("Models")
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        try Data("legacy base".utf8).write(to: modelsDirectory.appendingPathComponent("ggml-base.bin"))

        let catalog = WhisperModelCatalog(
            supportDirectoryURL: supportDirectory,
            bundledModelURLs: ["tiny.en": tinyURL]
        )

        let rows = ModelSelectionActions.whisperRows(modelCatalog: catalog)

        let multilingualBase = try XCTUnwrap(rows.first { $0.id == "base" })
        XCTAssertTrue(multilingualBase.isInstalled)
        XCTAssertTrue(
            multilingualBase.displayName.contains("(Multilingual)"),
            "Installed legacy non-English model must be visually distinct from its English catalog counterpart"
        )

        let englishBase = try XCTUnwrap(rows.first { $0.id == "base.en" })
        XCTAssertFalse(englishBase.isInstalled, "base.en genuinely was never downloaded and must still show as downloadable")
        XCTAssertTrue(englishBase.displayName.contains("MB"))

        // Two distinct rows — the legacy install must never be deduped against or presented as
        // satisfying the English catalog entry.
        XCTAssertNotEqual(multilingualBase.id, englishBase.id)
    }
}
