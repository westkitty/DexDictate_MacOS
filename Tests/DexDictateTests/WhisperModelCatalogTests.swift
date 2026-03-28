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
