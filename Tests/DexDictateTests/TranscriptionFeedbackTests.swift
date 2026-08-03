import XCTest
@testable import DexDictateKit

final class TranscriptionFeedbackTests: XCTestCase {
    func testFeedbackMessagesAreDistinct() {
        XCTAssertEqual(TranscriptionFeedback.noSpeechDetected.title, "No speech detected")
        XCTAssertEqual(TranscriptionFeedback.nothingToDelete.title, "Nothing to remove")
        XCTAssertEqual(TranscriptionFeedback.deletedPreviousHistory.title, "Previous entry removed")
        XCTAssertEqual(TranscriptionFeedback.restoredPreviousHistory.title, "Previous entry restored")
        XCTAssertEqual(TranscriptionFeedback.discardedCurrentUtterance.title, "Current utterance discarded")
        XCTAssertEqual(TranscriptionFeedback.savedToHistory(modified: false).title, "Saved to history")
        XCTAssertEqual(TranscriptionFeedback.savedToHistory(modified: true).title, "Saved with changes")
        XCTAssertEqual(
            TranscriptionFeedback.copiedOnlySensitiveContext(modified: false, reason: "Detected likely secure input context (password).").title,
            "Copied"
        )
        XCTAssertEqual(TranscriptionFeedback.pastedToActiveApp(modified: false).title, "Inserted")
        XCTAssertEqual(TranscriptionFeedback.pasteRequestedUnverified(modified: false).title, "Paste requested")
        XCTAssertEqual(TranscriptionFeedback.deliveryBlocked(modified: false, reason: "x").title, "Paste blocked")
        XCTAssertEqual(TranscriptionFeedback.deliveryFailed(modified: false, reason: "x").title, "Delivery failed")
        XCTAssertEqual(TranscriptionFeedback.dictationUndone.title, "Dictation undone")
        XCTAssertEqual(TranscriptionFeedback.dictationUndoUnavailable(reason: "x").title, "Couldn't undo")
    }

    func testFeedbackToneMatchesOutcome() {
        XCTAssertEqual(TranscriptionFeedback.noSpeechDetected.tone, .warning)
        XCTAssertEqual(TranscriptionFeedback.nothingToDelete.tone, .warning)
        XCTAssertEqual(TranscriptionFeedback.deletedPreviousHistory.tone, .warning)
        XCTAssertEqual(TranscriptionFeedback.discardedCurrentUtterance.tone, .warning)
        XCTAssertEqual(TranscriptionFeedback.restoredPreviousHistory.tone, .success)
        XCTAssertEqual(TranscriptionFeedback.savedToHistory(modified: false).tone, .success)
        XCTAssertEqual(
            TranscriptionFeedback.copiedOnlySensitiveContext(modified: false, reason: "Detected likely secure input context (password).").tone,
            .success
        )
        XCTAssertEqual(TranscriptionFeedback.pastedToActiveApp(modified: true).tone, .success)
        XCTAssertEqual(TranscriptionFeedback.pasteRequestedUnverified(modified: true).tone, .neutral)
        XCTAssertEqual(TranscriptionFeedback.deliveryBlocked(modified: false, reason: "x").tone, .warning)
        XCTAssertEqual(TranscriptionFeedback.deliveryFailed(modified: false, reason: "x").tone, .warning)
        XCTAssertEqual(TranscriptionFeedback.dictationUndone.tone, .success)
        XCTAssertEqual(TranscriptionFeedback.dictationUndoUnavailable(reason: "x").tone, .warning)
    }
}
