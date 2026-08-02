import Foundation
import XCTest
@testable import DexDictateKit

final class HistoryPersistenceManagerTests: XCTestCase {
    private var scratchRoot: URL!
    private var historyDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        scratchRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistoryPersistenceManagerTests-\(UUID().uuidString)", isDirectory: true)
        historyDirectory = scratchRoot.appendingPathComponent("DexDictate", isDirectory: true)
        try FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let scratchRoot {
            try? FileManager.default.removeItem(at: scratchRoot)
        }
        scratchRoot = nil
        historyDirectory = nil
        try super.tearDownWithError()
    }

    func testFirstSaveCreatesVersionedHistoryFile() throws {
        let item = makeItem(text: "first launch")
        let fileURL = historyDirectory.appendingPathComponent("history.json")

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        HistoryPersistenceManager.save([item], in: historyDirectory)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        )
        XCTAssertEqual(object["version"] as? Int, 1)
        XCTAssertEqual((object["payload"] as? [[String: Any]])?.count, 1)
        assertItems(HistoryPersistenceManager.load(from: historyDirectory), equalTo: [item])
    }

    func testExistingHistoryFileIsAtomicallyReplaced() {
        let original = makeItem(text: "original")
        let replacement = makeItem(text: "replacement")

        HistoryPersistenceManager.save([original], in: historyDirectory)
        HistoryPersistenceManager.save([replacement], in: historyDirectory)

        assertItems(HistoryPersistenceManager.load(from: historyDirectory), equalTo: [replacement])
    }

    func testWriteFailureDoesNotAlterObstructingPath() throws {
        let obstruction = scratchRoot.appendingPathComponent("not-a-directory")
        let sentinel = Data("sentinel".utf8)
        try sentinel.write(to: obstruction)

        HistoryPersistenceManager.save([makeItem(text: "cannot persist")], in: obstruction)

        XCTAssertEqual(try Data(contentsOf: obstruction), sentinel)
        XCTAssertFalse(FileManager.default.fileExists(atPath: obstruction.appendingPathComponent("history.json").path))
    }

    func testLoadsLegacyRawArray() throws {
        let item = makeItem(text: "legacy")
        let fileURL = historyDirectory.appendingPathComponent("history.json")
        try JSONEncoder().encode([item]).write(to: fileURL, options: .atomic)

        assertItems(HistoryPersistenceManager.load(from: historyDirectory), equalTo: [item])
    }

    func testCorruptFileIsQuarantined() throws {
        let fileURL = historyDirectory.appendingPathComponent("history.json")
        try Data("not-json".utf8).write(to: fileURL)

        XCTAssertTrue(HistoryPersistenceManager.load(from: historyDirectory).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        let names = try FileManager.default.contentsOfDirectory(atPath: historyDirectory.path)
        XCTAssertEqual(names.filter { $0.hasPrefix("history.json.corrupt-") }.count, 1)
    }

    func testSaveFiltersBlankItemsAndKeepsFirstDuplicateID() {
        let duplicateID = UUID()
        let first = makeItem(id: duplicateID, text: "first")
        let duplicate = makeItem(id: duplicateID, text: "duplicate")
        let blank = makeItem(text: "  \n")

        HistoryPersistenceManager.save([first, duplicate, blank], in: historyDirectory)

        assertItems(HistoryPersistenceManager.load(from: historyDirectory), equalTo: [first])
    }

    func testCleanedTextRoundTripsWithoutChangingRawText() {
        let item = makeItem(text: "raw transcript", cleanedText: "clean transcript")

        HistoryPersistenceManager.save([item], in: historyDirectory)

        let loaded = HistoryPersistenceManager.load(from: historyDirectory)
        assertItems(loaded, equalTo: [item])
        XCTAssertEqual(loaded.first?.text, "raw transcript")
        XCTAssertEqual(loaded.first?.cleanedText, "clean transcript")
    }

    private func makeItem(
        id: UUID = UUID(),
        text: String,
        cleanedText: String? = nil
    ) -> HistoryItem {
        HistoryItem(
            id: id,
            text: text,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            cleanedText: cleanedText
        )
    }

    private func assertItems(
        _ actual: [HistoryItem],
        equalTo expected: [HistoryItem],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.map(\.id), expected.map(\.id), file: file, line: line)
        XCTAssertEqual(actual.map(\.text), expected.map(\.text), file: file, line: line)
        XCTAssertEqual(actual.map(\.createdAt), expected.map(\.createdAt), file: file, line: line)
        XCTAssertEqual(actual.map(\.sourceHistoryItemID), expected.map(\.sourceHistoryItemID), file: file, line: line)
        XCTAssertEqual(actual.map(\.isAccuracyRetry), expected.map(\.isAccuracyRetry), file: file, line: line)
        XCTAssertEqual(actual.map(\.cleanedText), expected.map(\.cleanedText), file: file, line: line)
    }
}
