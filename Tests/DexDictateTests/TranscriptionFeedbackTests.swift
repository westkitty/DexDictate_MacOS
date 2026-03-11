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
        XCTAssertEqual(TranscriptionFeedback.pastedToActiveApp(modified: false).title, "Pasted into active app")
    }

    func testFeedbackToneMatchesOutcome() {
        XCTAssertEqual(TranscriptionFeedback.noSpeechDetected.tone, .warning)
        XCTAssertEqual(TranscriptionFeedback.nothingToDelete.tone, .warning)
        XCTAssertEqual(TranscriptionFeedback.deletedPreviousHistory.tone, .warning)
        XCTAssertEqual(TranscriptionFeedback.discardedCurrentUtterance.tone, .warning)
        XCTAssertEqual(TranscriptionFeedback.restoredPreviousHistory.tone, .success)
        XCTAssertEqual(TranscriptionFeedback.savedToHistory(modified: false).tone, .success)
        XCTAssertEqual(TranscriptionFeedback.pastedToActiveApp(modified: true).tone, .success)
    }
}
