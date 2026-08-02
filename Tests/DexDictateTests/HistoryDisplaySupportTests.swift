import XCTest
@testable import DexDictateKit

final class HistoryDisplaySupportTests: XCTestCase {
    func testEqualCleanedTextUsesRawWithoutVariantChoice() {
        let item = HistoryItem(text: "Exact transcript", cleanedText: "Exact transcript")
        let content = HistoryDisplayContent(item: item)

        XCTAssertFalse(content.hasDistinctCleanedText)
        XCTAssertEqual(content.effectiveVariant(preferred: .cleaned), .raw)
        XCTAssertEqual(content.text(preferred: .cleaned), "Exact transcript")
    }

    func testDistinctCleanedTextPreservesBothStringsExactly() {
        let item = HistoryItem(text: " raw transcript ", cleanedText: "raw transcript")
        let content = HistoryDisplayContent(item: item)

        XCTAssertTrue(content.hasDistinctCleanedText)
        XCTAssertEqual(content.text(preferred: .raw), " raw transcript ")
        XCTAssertEqual(content.text(preferred: .cleaned), "raw transcript")
    }

    func testCopyWritesTheExactDisplayedVariant() {
        let item = HistoryItem(text: "raw", cleanedText: "cleaned")
        let displayedText = HistoryDisplayContent(item: item).text(preferred: .cleaned)
        var writtenText: String?

        let result = TranscriptCopyAction.copy(displayedText) { text in
            writtenText = text
            return true
        }

        XCTAssertEqual(result, .copied)
        XCTAssertEqual(writtenText, "cleaned")
    }

    func testCopyReportsWriterFailure() {
        let result = TranscriptCopyAction.copy("represented row") { _ in false }

        XCTAssertEqual(result, .failed)
        XCTAssertEqual(result.feedbackText, "Copy failed")
    }

    func testRelativeTimestampUsesSystemRelativeFormatting() {
        let reference = Date(timeIntervalSince1970: 1_735_776_000)
        let date = reference.addingTimeInterval(-3_600)

        let value = HistoryPresentation.relativeTimestamp(
            for: date,
            relativeTo: reference,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertTrue(value.contains("1h") || value.contains("hr") || value.contains("hour"), value)
        XCTAssertTrue(value.contains("ago"), value)
    }

    func testExactTimestampIncludesLocalizedDateAndTime() {
        let date = makeDate()
        let value = HistoryPresentation.exactTimestamp(
            for: date,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertTrue(value.contains("January 2, 2025"), value)
        XCTAssertTrue(value.contains("3:04:05"), value)
        XCTAssertTrue(value.contains("PM"), value)
    }

    func testShowMoreEligibilityRequiresMeaningfulOverflow() {
        XCTAssertFalse(HistoryPresentation.shouldOfferExpansion(for: "Short transcription"))
        XCTAssertFalse(HistoryPresentation.shouldOfferExpansion(for: String(repeating: "a", count: 180)))
        XCTAssertTrue(HistoryPresentation.shouldOfferExpansion(for: String(repeating: "a", count: 181)))
        XCTAssertTrue(HistoryPresentation.shouldOfferExpansion(for: "one\ntwo\nthree\nfour"))
    }

    func testAccessibilitySummaryUsesOnlyStoredRowFacts() {
        let item = HistoryItem(
            text: "raw",
            createdAt: makeDate(),
            isAccuracyRetry: true,
            cleanedText: "cleaned"
        )
        let summary = HistoryPresentation.accessibilitySummary(
            item: item,
            displayedText: "cleaned",
            variant: .cleaned,
            position: 2,
            total: 3
        )

        XCTAssertTrue(summary.contains("Recent transcription 2 of 3."), summary)
        XCTAssertTrue(summary.contains("cleaned"), summary)
        XCTAssertTrue(summary.contains("2025"), summary)
        XCTAssertTrue(summary.contains("Cleaned text."), summary)
        XCTAssertTrue(summary.contains("Quality retry."), summary)
        XCTAssertFalse(summary.localizedCaseInsensitiveContains("provider"), summary)
        XCTAssertFalse(summary.localizedCaseInsensitiveContains("application"), summary)
    }

    private func makeDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(
            year: 2025,
            month: 1,
            day: 2,
            hour: 15,
            minute: 4,
            second: 5
        ))!
    }
}
