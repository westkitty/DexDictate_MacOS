import XCTest
@testable import DexDictateKit

@MainActor
final class PersistentHistoryTests: XCTestCase {

    var testURL: URL!

    override func setUp() {
        super.setUp()
        testURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("history_test_\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testURL)
        super.tearDown()
    }

    func testHistoryItemIsCodable() throws {
        let item = HistoryItem(text: "Hello world")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(HistoryItem.self, from: data)
        XCTAssertEqual(decoded.text, item.text)
    }

    func testSaveAndLoad() throws {
        let history = TranscriptionHistory()
        history.add("First entry")
        history.add("Second entry")

        try history.save(to: testURL)

        let history2 = TranscriptionHistory()
        try history2.load(from: testURL)

        XCTAssertEqual(history2.items.count, 2)
        XCTAssertEqual(history2.items.first?.text, "Second entry") // most-recent first
    }

    func testSaveEmptyHistory() throws {
        let history = TranscriptionHistory()
        XCTAssertNoThrow(try history.save(to: testURL))
    }

    func testLoadFromMissingFileReturnsEmpty() throws {
        let missing = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID()).json")
        let history = TranscriptionHistory()
        try history.load(from: missing)
        XCTAssertTrue(history.isEmpty)
    }
}
