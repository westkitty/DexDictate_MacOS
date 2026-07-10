import XCTest
@testable import DexDictateKit

@MainActor
final class WhisperModelCatalogTests: XCTestCase {
    func testImportRejectsUnexpectedFileNames() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let tinyURL = tempDirectory.appendingPathComponent("tiny.en.bin")
        let invalidURL = tempDirectory.appendingPathComponent("medium.en.bin")
        try Data("tiny".utf8).write(to: tinyURL)
        try Data("medium".utf8).write(to: invalidURL)

        let catalog = WhisperModelCatalog(
            supportDirectoryURL: tempDirectory.appendingPathComponent("Support"),
            bundledModelURLs: ["tiny.en": tinyURL]
        )

        XCTAssertThrowsError(try catalog.importModel(from: invalidURL))
    }

    func testImportReplacesExistingModelMetadata() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let tinyURL = tempDirectory.appendingPathComponent("tiny.en.bin")
        let baseURL = tempDirectory.appendingPathComponent("base.en.bin")
        try Data("tiny".utf8).write(to: tinyURL)
        try Data("base-v1".utf8).write(to: baseURL)

        let catalog = WhisperModelCatalog(
            supportDirectoryURL: tempDirectory.appendingPathComponent("Support"),
            bundledModelURLs: ["tiny.en": tinyURL]
        )

        let first = try catalog.importModel(from: baseURL)
        try Data("base-v2".utf8).write(to: baseURL)
        let second = try catalog.importModel(from: baseURL)

        XCTAssertEqual(first.id, "base.en")
        XCTAssertEqual(second.id, "base.en")
        XCTAssertNotEqual(first.sha256, second.sha256)
        XCTAssertEqual(catalog.importedModels.count, 1)
    }

    // MARK: - Installed model discovery

    func testRecognizesGGMLFilenamesWithDisplayNames() {
        // BUG-007: stems with a real `.en` counterpart in `downloadableCatalog` (tiny/base/
        // small/medium) get a "(Multilingual)" qualifier on their non-English display name so
        // an already-installed legacy `ggml-<stem>.bin` (e.g. fetched by hand via whisper.cpp's
        // own download-ggml-model.sh) can't be visually mistaken for a duplicate of its
        // separately-cataloged, still-not-downloaded English counterpart. `large`/`large-v1`/
        // `large-v2`/`large-v3` have no `.en` counterpart at all, so they're unaffected.
        let cases: [(file: String, id: String, display: String)] = [
            ("ggml-tiny.bin", "tiny", "Tiny (Multilingual)"),
            ("ggml-base.bin", "base", "Base (Multilingual)"),
            ("ggml-small.bin", "small", "Small (Multilingual)"),
            ("ggml-medium.bin", "medium", "Medium (Multilingual)"),
            ("ggml-large.bin", "large", "Large"),
            ("ggml-large-v1.bin", "large-v1", "Large v1"),
            ("ggml-large-v2.bin", "large-v2", "Large v2"),
            ("ggml-large-v3.bin", "large-v3", "Large v3"),
            ("ggml-tiny.en.bin", "tiny.en", "Tiny English"),
            ("ggml-base.en.bin", "base.en", "Base English"),
            ("ggml-small.en.bin", "small.en", "Small English"),
            ("ggml-medium.en.bin", "medium.en", "Medium English")
        ]

        for entry in cases {
            let recognized = WhisperModelCatalog.recognizedInstalledModel(fileName: entry.file)
            XCTAssertEqual(recognized?.id, entry.id, "id for \(entry.file)")
            XCTAssertEqual(recognized?.displayName, entry.display, "display name for \(entry.file)")
        }

        // Case-insensitive on the filename.
        XCTAssertEqual(WhisperModelCatalog.recognizedInstalledModel(fileName: "GGML-Base.bin")?.id, "base")
    }

    func testRecognizerRejectsUnrelatedFiles() {
        let rejects = [
            "README.md",
            "ggml-bogus.bin",      // unknown stem
            "base.bin",            // missing ggml- prefix
            "ggml-base.txt",       // wrong extension
            "ggml-.bin",           // empty stem
            ".DS_Store",
            "ggml-base.en.bin.tmp",
            "model.bin"
        ]
        for name in rejects {
            XCTAssertNil(
                WhisperModelCatalog.recognizedInstalledModel(fileName: name),
                "should reject \(name)"
            )
        }
    }

    func testScansModelsDirectoryForInstalledGGMLModels() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let supportDirectory = tempDirectory.appendingPathComponent("Support")
        let modelsDirectory = supportDirectory.appendingPathComponent("Models")
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        try Data("base".utf8).write(to: modelsDirectory.appendingPathComponent("ggml-base.bin"))
        try Data("small".utf8).write(to: modelsDirectory.appendingPathComponent("ggml-small.bin"))
        try Data("notes".utf8).write(to: modelsDirectory.appendingPathComponent("notes.txt"))

        let tinyURL = tempDirectory.appendingPathComponent("tiny.en.bin")
        try Data("tiny".utf8).write(to: tinyURL)

        let catalog = WhisperModelCatalog(
            supportDirectoryURL: supportDirectory,
            bundledModelURLs: ["tiny.en": tinyURL]
        )

        let ids = catalog.availableModels.map(\.id)
        XCTAssertTrue(ids.contains("base"), "ggml-base.bin should be discovered")
        XCTAssertTrue(ids.contains("small"), "ggml-small.bin should be discovered")
        XCTAssertEqual(catalog.descriptor(for: "base")?.displayName, "Base (Multilingual)")
        XCTAssertEqual(catalog.descriptor(for: "small")?.displayName, "Small (Multilingual)")

        // Unrelated files are ignored.
        XCTAssertFalse(catalog.availableModels.contains { $0.fileName == "notes.txt" })

        // Installed models are not flagged as imported, so the "remove imported"
        // path and the benchmark candidate pool never touch user-placed files.
        XCTAssertTrue(catalog.importedModels.isEmpty)
        XCTAssertEqual(catalog.descriptor(for: "base")?.origin, .installed)
    }

    func testResolveSelectionFallsBackToBestAvailableWhenSavedMissing() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let supportDirectory = tempDirectory.appendingPathComponent("Support")
        let modelsDirectory = supportDirectory.appendingPathComponent("Models")
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        try Data("base".utf8).write(to: modelsDirectory.appendingPathComponent("ggml-base.bin"))
        try Data("small".utf8).write(to: modelsDirectory.appendingPathComponent("ggml-small.bin"))

        let tinyURL = tempDirectory.appendingPathComponent("tiny.en.bin")
        try Data("tiny".utf8).write(to: tinyURL)

        let catalog = WhisperModelCatalog(
            supportDirectoryURL: supportDirectory,
            bundledModelURLs: ["tiny.en": tinyURL]
        )

        let resolution = catalog.resolveSelection(savedID: "medium")
        XCTAssertEqual(resolution.resolvedID, "small", "should fall back to the best available model")
        XCTAssertNotNil(resolution.warning)
        XCTAssertNotNil(catalog.availabilityWarning)
    }

    func testResolveSelectionKeepsValidSavedSelection() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let supportDirectory = tempDirectory.appendingPathComponent("Support")
        let modelsDirectory = supportDirectory.appendingPathComponent("Models")
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        try Data("base".utf8).write(to: modelsDirectory.appendingPathComponent("ggml-base.bin"))

        let tinyURL = tempDirectory.appendingPathComponent("tiny.en.bin")
        try Data("tiny".utf8).write(to: tinyURL)

        let catalog = WhisperModelCatalog(
            supportDirectoryURL: supportDirectory,
            bundledModelURLs: ["tiny.en": tinyURL]
        )

        let resolution = catalog.resolveSelection(savedID: "base")
        XCTAssertEqual(resolution.resolvedID, "base")
        XCTAssertNil(resolution.warning)
        XCTAssertNil(catalog.availabilityWarning)
    }

    func testRemoveImportedModelHandlesMissingEntriesGracefully() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let tinyURL = tempDirectory.appendingPathComponent("tiny.en.bin")
        try Data("tiny".utf8).write(to: tinyURL)

        let catalog = WhisperModelCatalog(
            supportDirectoryURL: tempDirectory.appendingPathComponent("Support"),
            bundledModelURLs: ["tiny.en": tinyURL]
        )

        catalog.removeImportedModel(id: "base.en")
        XCTAssertEqual(catalog.availableModels.count, 1)
        XCTAssertEqual(catalog.availableModels.first?.id, "tiny.en")
    }
}
