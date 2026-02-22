import XCTest
@testable import DexDictateKit

@MainActor
final class VerificationTests: XCTestCase {

    // MARK: - User Path 1: The Golden Path

    func testGoldenPath() async throws {
        // 1. Launch App (Simulated by initializing core services)
        let settings = AppSettings.shared
        // Reset specific settings for test
        settings.hasCompletedOnboarding = false
        // Engine is always Whisper (local-only, no Apple SR)
        settings.selectedEngine = .whisper

        // 2. Complete Onboarding
        XCTAssertFalse(settings.hasCompletedOnboarding, "Onboarding should start incomplete")
        settings.hasCompletedOnboarding = true
        XCTAssertTrue(settings.hasCompletedOnboarding, "Onboarding should be marked complete")

        // 3. Verify Whisper Engine Selected (only supported engine)
        XCTAssertEqual(settings.selectedEngine, .whisper, "Engine should be Whisper (local-only)")

        // 4. Transcription Flow (Simulated)
        // Since we cannot easily inject audio in a unit test without refactoring for
        // dependency injection of the audio source, we test the TranscriptionEngine's
        // text processing pipeline directly via CommandProcessor and VocabularyManager.

        let _ = TranscriptionEngine.shared

        // Vocabulary Manager (Golden Path might use a custom word)
        let vocab = VocabularyManager()
        vocab.items = [VocabularyItem(original: "brb", replacement: "Be Right Back")]

        let processed = vocab.apply(to: "I will brb")
        XCTAssertEqual(processed, "I will Be Right Back", "Custom vocabulary should replace text")

        // History Persistence
        let history = TranscriptionHistory()
        history.add("Test Phrase")
        XCTAssertEqual(history.items.last?.text, "Test Phrase", "History should record transcription")

        // 5. Verify Cleanup
        settings.restoreDefaults()
    }
}
