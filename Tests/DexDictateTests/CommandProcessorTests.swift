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

    func testPeriodCommand() {
        let processor = CommandProcessor()
        let (result, _) = processor.process("send it period")
        XCTAssertEqual(result, "send it.")
    }

    func testCommaCommand() {
        let (result, _) = CommandProcessor().process("hello comma world")
        XCTAssertEqual(result, "hello, world")
    }

    func testQuestionMarkCommand() {
        let (result, _) = CommandProcessor().process("are you there question mark")
        XCTAssertEqual(result, "are you there?")
    }

    func testExclamationCommand() {
        let (result, _) = CommandProcessor().process("wow exclamation point")
        XCTAssertEqual(result, "wow!")
    }

    func testNewParagraphCommand() {
        let (result, _) = CommandProcessor().process("end of section new paragraph start")
        XCTAssertTrue(result.contains("\n\n"))
    }

    func testOpenCloseParen() {
        let (result, _) = CommandProcessor().process("see open paren below close paren")
        XCTAssertEqual(result, "see (below)")
    }

    func testFullStopAlias() {
        let (result, _) = CommandProcessor().process("done full stop")
        XCTAssertEqual(result, "done.")
    }

    func testColonAndSemicolon() {
        let (result, _) = CommandProcessor().process("items colon one semicolon two")
        XCTAssertEqual(result, "items: one; two")
    }

    func testEllipsisCommand() {
        let (result, _) = CommandProcessor().process("and then ellipsis")
        XCTAssertEqual(result, "and then...")
    }

    func testDashCommand() {
        let (result, _) = CommandProcessor().process("self dash serve")
        XCTAssertEqual(result, "self-serve")
    }
}
