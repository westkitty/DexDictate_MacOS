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

    func testCustomHotWordCommandResolvesBeforeBuiltIns() {
        let processor = CommandProcessor()
        let commands = [CustomCommand(keyword: "comma", insertText: ",")]

        let (text, command) = processor.process("Dex comma", customCommands: commands)

        XCTAssertEqual(text, ",")
        XCTAssertEqual(command, .none)
    }

    // MARK: - Trailing punctuation (Whisper commonly appends a period to short utterances)

    func testScratchThatMatchesWithTrailingPeriod() {
        let processor = CommandProcessor()

        let (text, command) = processor.process("Hello world scratch that.")

        XCTAssertEqual(text, "")
        XCTAssertEqual(command, .deleteLastSentence)
    }

    func testAllCapsMatchesWithTrailingPeriod() {
        let processor = CommandProcessor()

        let (text, command) = processor.process("DexDictate all caps.")

        XCTAssertEqual(text, "DEXDICTATE")
        XCTAssertEqual(command, .none)
    }

    func testCustomHotWordCommandMatchesWithTrailingPeriod() {
        let processor = CommandProcessor()
        let commands = [CustomCommand(keyword: "comma", insertText: ",")]

        let (text, command) = processor.process("Dex comma.", customCommands: commands)

        XCTAssertEqual(text, ",")
        XCTAssertEqual(command, .none)
    }

    // MARK: - Spoken punctuation

    func testSpokenPunctuationCommands() {
        let processor = CommandProcessor()
        let cases = [
            ("send it period", "send it."),
            ("hello comma world", "hello, world"),
            ("are you there question mark", "are you there?"),
            ("wow exclamation point", "wow!"),
            ("done full stop", "done."),
            ("items colon one semicolon two", "items: one; two"),
            ("and then ellipsis", "and then..."),
            ("self dash serve", "self-serve"),
            ("well hyphen known", "well-known"),
            ("see open paren below close paren", "see (below)"),
            ("say open quote hello close quote", "say \"hello\""),
        ]

        for (input, expected) in cases {
            let (text, command) = processor.process(input)
            XCTAssertEqual(text, expected, "input: \(input)")
            XCTAssertEqual(command, .none, "input: \(input)")
        }
    }

    func testNewParagraphCommandInsertsTwoLineBreaks() {
        let (text, command) = CommandProcessor().process("first new paragraph second")

        XCTAssertEqual(text, "first\n\n second")
        XCTAssertEqual(command, .newLine)
    }

    func testCustomCommandStillWinsOverSpokenPunctuation() {
        let commands = [CustomCommand(keyword: "comma", insertText: "CUSTOM")]

        let (text, command) = CommandProcessor().process("Dex comma", customCommands: commands)

        XCTAssertEqual(text, "CUSTOM")
        XCTAssertEqual(command, .none)
    }

    func testSpokenPunctuationDoesNotMatchInsideWords() {
        let input = "A periodic commafish remains intact"

        let (text, command) = CommandProcessor().process(input)

        XCTAssertEqual(text, input)
        XCTAssertEqual(command, .none)
    }
}
