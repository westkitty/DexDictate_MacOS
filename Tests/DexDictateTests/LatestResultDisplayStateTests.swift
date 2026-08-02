import XCTest
@testable import DexDictateKit

/// Covers the repair for "a new result inherits the previous result's Raw/Cleaned choice and
/// expanded state". `PopoverResultView` drives exactly this value from
/// `.onChange(of: latestHistoryItem.id)`.
final class LatestResultDisplayStateTests: XCTestCase {
    func testDefaultsAreCollapsedAndCleaned() {
        let state = LatestResultDisplayState()

        XCTAssertEqual(state.preferredVariant, .cleaned)
        XCTAssertFalse(state.isExpanded)
        XCTAssertNil(state.itemID)
    }

    func testChangingItemResetsVariantAndExpansion() {
        var state = LatestResultDisplayState()
        let first = UUID()
        state.synchronize(with: first)

        state.toggleVariant(displayed: .cleaned)
        state.toggleExpansion()
        XCTAssertEqual(state.preferredVariant, .raw)
        XCTAssertTrue(state.isExpanded)

        let second = UUID()
        let didReset = state.synchronize(with: second)

        XCTAssertTrue(didReset)
        XCTAssertEqual(state.itemID, second)
        XCTAssertEqual(state.preferredVariant, .cleaned)
        XCTAssertFalse(state.isExpanded)
    }

    func testSameItemDoesNotResetUserChoice() {
        var state = LatestResultDisplayState()
        let item = UUID()
        state.synchronize(with: item)
        state.toggleVariant(displayed: .cleaned)
        state.toggleExpansion()

        let didReset = state.synchronize(with: item)

        XCTAssertFalse(didReset, "Re-rendering the same item must not discard the user's choice")
        XCTAssertEqual(state.preferredVariant, .raw)
        XCTAssertTrue(state.isExpanded)
    }

    /// Moving from an item with distinct cleaned text (where the Raw/Cleaned switch is shown)
    /// to one without it must not leave a stale "Raw" selection behind: the reset returns the
    /// preference to `.cleaned`, and `HistoryDisplayContent` resolves that to raw text without
    /// offering a misleading switch.
    func testMovingToItemWithoutDistinctCleanedTextCannotLeaveStaleRawSelection() {
        var state = LatestResultDisplayState()
        let distinct = HistoryItem(text: "raw form", cleanedText: "cleaned form")
        let plain = HistoryItem(text: "identical", cleanedText: nil)

        state.synchronize(with: distinct.id)
        state.toggleVariant(displayed: .cleaned)
        XCTAssertEqual(state.preferredVariant, .raw)

        state.synchronize(with: plain.id)

        let content = HistoryDisplayContent(item: plain)
        XCTAssertEqual(state.preferredVariant, .cleaned)
        XCTAssertFalse(content.hasDistinctCleanedText, "No Cleaned/Raw switch should be offered")
        XCTAssertEqual(content.effectiveVariant(preferred: state.preferredVariant), .raw)
        XCTAssertEqual(content.text(preferred: state.preferredVariant), "identical")
    }

    func testToggleVariantCollapsesExpansion() {
        var state = LatestResultDisplayState()
        state.synchronize(with: UUID())
        state.toggleExpansion()
        XCTAssertTrue(state.isExpanded)

        state.toggleVariant(displayed: .cleaned)

        XCTAssertFalse(state.isExpanded, "Switching variant re-measures the text, so collapse first")
    }
}
