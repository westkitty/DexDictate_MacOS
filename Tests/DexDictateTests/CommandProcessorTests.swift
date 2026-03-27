import XCTest
@testable import DexDictateKit

final class CommandProcessorTests: XCTestCase {
    func testNewLineCommandUsesWordBoundaries() {
        let processor = CommandProcessor()

        let (text, command) = processor.process("Hello new line world")

        XCTAssertEqual(text, "Hello \n world")
        XCTAssertEqual(command, .newLine)
    }

    func testNewLineDoesNotTriggerOnConcatenatedWord() {
        let processor = CommandProcessor()

        let (text, command) = processor.process("newline should stay intact")

        XCTAssertEqual(text, "newline should stay intact")
        XCTAssertEqual(command, .none)
    }

    func testScratchThatOnlyDeletesAsStandaloneSuffix() {
        let processor = CommandProcessor()

        let (text, command) = processor.process("Hello world scratch that")

        XCTAssertEqual(text, "")
        XCTAssertEqual(command, .deleteLastSentence)
    }

    func testScratchThatDoesNotTriggerInNormalSentenceTail() {
        let processor = CommandProcessor()

        let (text, command) = processor.process("scratch that please")

        XCTAssertEqual(text, "scratch that please")
        XCTAssertEqual(command, .none)
    }

    func testAllCapsUppercasesOnlyTheContentBeforeTheCommand() {
        let processor = CommandProcessor()

        let (text, command) = processor.process("DexDictate all caps")

        XCTAssertEqual(text, "DEXDICTATE")
        XCTAssertEqual(command, .none)
    }
}
