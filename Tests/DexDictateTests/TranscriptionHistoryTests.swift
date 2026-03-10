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
}
