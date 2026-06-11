import AppKit
import XCTest
@testable import DexDictateKit

final class ArchitectureHardeningTests: XCTestCase {

    // MARK: - LocalJSONStore

    func testLocalJSONStoreWritesVersionedEnvelope() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = LocalJSONStore<[Int]>(fileURL: url, schemaVersion: 1, defaultValue: [])
        await store.save([1, 2, 3])

        let rawData = try Data(contentsOf: url)
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: rawData) as? [String: Any]
        )
        XCTAssertEqual(json["version"] as? Int, 1)
        XCTAssertEqual(json["payload"] as? [Int], [1, 2, 3])
    }

    func testLocalJSONStoreRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = LocalJSONStore<[Int]>(fileURL: url, schemaVersion: 1, defaultValue: [])
        await store.save([10, 20, 30])
        let loaded = await store.load()
        XCTAssertEqual(loaded, [10, 20, 30])
    }

    func testLocalJSONStoreMigratesLegacyPayload() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }

        // Write legacy format: raw [Int] array without envelope.
        let legacyData = try! JSONEncoder().encode([1, 2, 3])
        try! legacyData.write(to: url)

        let store = LocalJSONStore<[Int]>(
            fileURL: url,
            schemaVersion: 1,
            defaultValue: [],
            legacyMigrate: { data in try JSONDecoder().decode([Int].self, from: data) }
        )
        let loaded = await store.load()
        XCTAssertEqual(loaded, [1, 2, 3])
    }

    func testLocalJSONStoreQuarantinesCorruptFile() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer {
            try? FileManager.default.removeItem(at: url)
            // Clean up any quarantine files produced by the test.
            let dir = url.deletingLastPathComponent()
            let name = url.lastPathComponent
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
                for file in contents where file.hasPrefix(name + ".corrupt-") {
                    try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
                }
            }
        }

        // Write corrupt JSON.
        try! "NOT VALID JSON {{{".data(using: .utf8)!.write(to: url)

        let store = LocalJSONStore<[Int]>(fileURL: url, schemaVersion: 1, defaultValue: [99])
        let loaded = await store.load()

        // Should return default value.
        XCTAssertEqual(loaded, [99])
        // Original file should be quarantined (moved away from original path).
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: url.path),
            "Corrupt file should have been quarantined to a .corrupt-* path"
        )
    }

    func testLocalJSONStoreReturnsDefaultWhenFileAbsent() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        // Deliberately do not create the file.

        let store = LocalJSONStore<[Int]>(fileURL: url, schemaVersion: 1, defaultValue: [42])
        let loaded = await store.load()
        XCTAssertEqual(loaded, [42])
    }

    func testLocalJSONStoreDeleteRemovesFile() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = LocalJSONStore<[Int]>(fileURL: url, schemaVersion: 1, defaultValue: [])
        await store.save([7])
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        await store.delete()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - DiagnosticsStore

    func testDiagnosticsStoreAppendIsAccretive() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = DiagnosticsStore(directoryURL: dir, fileName: "test.jsonl", maxRecords: 100)

        let r1 = DiagnosticRecord(timestamp: Date(), category: .general, message: "first")
        store.append(r1)
        let content1 = try String(contentsOf: store.logURL, encoding: .utf8)

        let r2 = DiagnosticRecord(timestamp: Date(), category: .general, message: "second")
        store.append(r2)
        let content2 = try String(contentsOf: store.logURL, encoding: .utf8)

        // Both records must be present after two appends.
        XCTAssertTrue(content2.contains("first"), "First record should still be present after second append")
        XCTAssertTrue(content2.contains("second"), "Second record should be present")
        // The second file should strictly grow: the original content should be a prefix.
        let trimmed1 = content1.trimmingCharacters(in: .newlines)
        XCTAssertTrue(
            content2.hasPrefix(trimmed1),
            "Append should not rewrite previous content; content2 should start with content1"
        )
    }

    func testDiagnosticsStorePrunesWhenOverLimit() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // maxRecords=5; write enough large records to exceed the byte-size threshold
        // (threshold = maxRecords * 250 = 1250 bytes).
        let store = DiagnosticsStore(directoryURL: dir, fileName: "test.jsonl", maxRecords: 5)

        for i in 0..<30 {
            let record = DiagnosticRecord(
                timestamp: Date(),
                category: .general,
                message: String(repeating: "x", count: 200) + " record \(i)"
            )
            store.append(record)
        }

        let content = try String(contentsOf: store.logURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)

        XCTAssertLessThanOrEqual(lines.count, 5, "Should prune to at most maxRecords=5 lines")
    }

    func testDiagnosticsStoreKeepsNewestRecordsAfterPrune() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = DiagnosticsStore(directoryURL: dir, fileName: "test.jsonl", maxRecords: 3)

        // Write enough large records to trigger pruning.
        for i in 1...10 {
            let record = DiagnosticRecord(
                timestamp: Date(),
                category: .general,
                message: String(repeating: "y", count: 200) + " record \(i)"
            )
            store.append(record)
        }

        let content = try String(contentsOf: store.logURL, encoding: .utf8)
        // The oldest records should have been pruned; the newest should survive.
        XCTAssertTrue(content.contains("record 10"), "Newest record should be retained after prune")
        // "record 1\"}" is the JSON tail of the message field for exactly record 1
        // (records 10+ end with "record 10\"}", "record 11\"}", etc., none end with bare "record 1\"}").
        XCTAssertFalse(content.contains("record 1\"}"), "Oldest record (record 1) should be pruned")
    }

    // MARK: - ClipboardManager snapshot cap

    func testClipboardManagerSnapshotCapReturnsEmptyItemsWhenOversized() {
        let item = NSPasteboardItem()
        // 11 MB of data — exceeds the 10 MB cap.
        let largeData = Data(repeating: 0xAB, count: 11 * 1024 * 1024)
        item.setData(largeData, forType: .string)

        let result = ClipboardManager.clonePasteboardItems([item])

        XCTAssertTrue(result.hadOriginalContents)
        XCTAssertTrue(
            result.items.isEmpty,
            "Snapshot should be empty when total data exceeds 10 MB cap"
        )
    }

    func testClipboardManagerSnapshotCapAllowsSmallPayloads() {
        let item = NSPasteboardItem()
        item.setString("hello world", forType: .string)

        let result = ClipboardManager.clonePasteboardItems([item])

        XCTAssertTrue(result.hadOriginalContents)
        XCTAssertFalse(result.items.isEmpty, "Small payload should be cloned normally")
    }

    // MARK: - AudioRecorderService buffer seam

    #if DEBUG
    func testAudioRecorderBufferInjectAndCollect() {
        let service = AudioRecorderService()
        service.injectMockSamples([1.0, 2.0, 3.0])
        let collected = service.collectRecording()
        XCTAssertEqual(collected, [1.0, 2.0, 3.0])
    }

    func testAudioRecorderBufferClearedAfterCollect() {
        let service = AudioRecorderService()
        service.injectMockSamples([4.0, 5.0])
        _ = service.collectRecording()
        let second = service.collectRecording()
        XCTAssertTrue(second.isEmpty, "Buffer should be empty after collect")
    }
    #endif
}
