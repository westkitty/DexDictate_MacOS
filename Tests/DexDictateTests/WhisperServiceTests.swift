import XCTest
@testable import DexDictateKit

final class WhisperServiceTests: XCTestCase {
    func testLiveDictationParamsStayLatencyOptimized() {
        let params = WhisperService.makeParams(for: .speed, mode: .liveDictation)

        XCTAssertTrue(params.single_segment)
        XCTAssertEqual(params.max_tokens, 128)
        XCTAssertTrue(params.no_context)
        XCTAssertTrue(params.speed_up)
        XCTAssertTrue(params.suppress_non_speech_tokens)
    }

    func testImportedFileParamsAllowFullFileDecoding() {
        let params = WhisperService.makeParams(for: .speed, mode: .importedFile)

        XCTAssertFalse(params.single_segment)
        XCTAssertEqual(params.max_tokens, 0)
        XCTAssertFalse(params.no_context)
        XCTAssertFalse(params.speed_up)
        XCTAssertTrue(params.suppress_non_speech_tokens)
    }
}
