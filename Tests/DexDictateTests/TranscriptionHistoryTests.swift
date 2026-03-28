import XCTest
@testable import DexDictateKit

@MainActor
final class TranscriptionHistoryTests: XCTestCase {
    func testHistoryItemsCaptureCreationDate() {
        let before = Date()
        let history = TranscriptionHistory()
        history.add("Timestamped entry")

        XCTAssertEqual(history.items.count, 1)
        XCTAssertGreaterThanOrEqual(history.items[0].createdAt.timeIntervalSince1970, before.timeIntervalSince1970)
    }

    func testRemovedHistoryCanBeRestored() {
        let history = TranscriptionHistory()

        history.add("first")
        history.add("second")

        let removed = history.removeMostRecent()

        XCTAssertEqual(removed?.text, "second")
        XCTAssertEqual(history.items.map(\.text), ["first"])
        XCTAssertTrue(history.canRestoreLastRemovedItem)
        XCTAssertTrue(history.restoreMostRecentRemoval())
        XCTAssertEqual(history.items.map(\.text), ["second", "first"])
        XCTAssertFalse(history.canRestoreLastRemovedItem)
    }

    func testHistoryCapturesAccuracyRetryMetadata() {
        let history = TranscriptionHistory()
        let source = history.add("original")
        let retry = history.add(
            "corrected",
            sourceHistoryItemID: source?.id,
            isAccuracyRetry: true
        )

        XCTAssertEqual(history.items.first?.text, "corrected")
        XCTAssertEqual(retry?.sourceHistoryItemID, source?.id)
        XCTAssertEqual(retry?.isAccuracyRetry, true)
    }
}
