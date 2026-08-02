import Foundation

public enum DictationCommand {
    case none
    case deleteLastSentence
    case newLine
    case allCaps
}

public class CommandProcessor {
    public init() {}
    
    /// Processes text for commands.
    ///
    /// Custom commands use a "Dex [keyword]" hot-word prefix. Built-in commands
    /// (scratch that, all caps, new line, and spoken punctuation) are checked if
    /// no custom command fires.
    ///
    /// - Parameters:
    ///   - text: Raw transcribed text.
    ///   - customCommands: User-defined hot-word commands to check first.
    /// - Returns: Tuple containing processed text (if any remains) and the command action.
    public func process(_ text: String, customCommands: [CustomCommand] = []) -> (String, DictationCommand) {
        let originalTrimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !originalTrimmed.isEmpty else { return (text, .none) }

        // Whisper frequently appends terminal punctuation to short utterances (e.g.
        // "Scratch that."), which would otherwise defeat the end-anchored ($) patterns
        // below and silently insert the phrase as literal text instead of running the
        // command. Strip trailing punctuation/whitespace for matching purposes only —
        // `text`/`trimmed` (with punctuation intact) are still what's returned/inserted
        // when no command matches.
        let originalCommandMatchText = strippedForCommandMatch(originalTrimmed)

        if !customCommands.isEmpty,
           let result = processHotWordCommand(originalCommandMatchText, commands: customCommands) {
            return result
        }

        let punctuationResult = processPunctuation(text)
        let trimmed = punctuationResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let commandMatchText = strippedForCommandMatch(trimmed)

        if matchesCommand(commandMatchText, pattern: #"(?i)(?:^|\s)scratch that$"#) {
            return ("", .deleteLastSentence)
        }

        if matchesCommand(commandMatchText, pattern: #"(?i)(?:^|\s)all caps$"#) {
            let content = commandMatchText.replacingOccurrences(
                of: #"(?i)(?:^|\s)all caps$"#,
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespaces)
            return (content.uppercased(), .none)
        }

        let replaced = replaceCommands(trimmed)
        if replaced != trimmed {
            return (replaced, .newLine)
        }

        return (
            punctuationResult.text,
            punctuationResult.insertedParagraph ? .newLine : .none
        )
    }

    private func processPunctuation(_ text: String) -> (text: String, insertedParagraph: Bool) {
        let replacements: [(pattern: String, replacement: String)] = [
            (#"\s*\bopen paren(?:thesis)?\b\s*"#, " ("),
            (#"\s+\bclose paren(?:thesis)?\b"#, ")"),
            (#"\s*\bopen (?:quote|quotes)\b\s*"#, " \""),
            (#"\s+\bclose (?:quote|quotes)\b"#, "\""),
            (#"\s+\bnew paragraph\b"#, "\n\n"),
            (#"\s+\bexclamation (?:point|mark)\b"#, "!"),
            (#"\s+\bquestion mark\b"#, "?"),
            (#"\s+\bfull stop\b"#, "."),
            (#"\s+\bsemicolon\b"#, ";"),
            (#"\s+\bellipsis\b"#, "..."),
            (#"\s+\bperiod\b"#, "."),
            (#"\s+\bcomma\b"#, ","),
            (#"\s+\bcolon\b"#, ":"),
            (#"\s+\bdash\b\s+"#, "-"),
            (#"\s+\bhyphen\b\s+"#, "-"),
        ]

        let paragraphPattern = #"\s+\bnew paragraph\b"#
        let insertedParagraph = text.range(
            of: paragraphPattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil

        var result = text
        for (pattern, replacement) in replacements {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: replacement
            )
        }
        return (result, insertedParagraph)
    }

    private func strippedForCommandMatch(_ text: String) -> String {
        var result = Substring(text)
        while let last = result.last, last.isPunctuation || last.isWhitespace {
            result.removeLast()
        }
        return String(result)
    }

    private func processHotWordCommand(_ text: String, commands: [CustomCommand]) -> (String, DictationCommand)? {
        let hotWordPattern = #"(?i)^dex\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: hotWordPattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let keywordRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        let spokenKeyword = String(text[keywordRange])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let command = commands.first(where: { $0.keyword.lowercased() == spokenKeyword }) else {
            return nil
        }
        return (command.insertText, .none)
    }

    private func matchesCommand(_ text: String, pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private func replaceCommands(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(?i)\b(?:new line|next line)\b"#) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "\n")
    }
}
