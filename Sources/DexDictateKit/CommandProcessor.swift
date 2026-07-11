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
    /// (scratch that, all caps, new line) are checked if no custom command fires.
    ///
    /// - Parameters:
    ///   - text: Raw transcribed text.
    ///   - customCommands: User-defined hot-word commands to check first.
    /// - Returns: Tuple containing processed text (if any remains) and the command action.
    public func process(_ text: String, customCommands: [CustomCommand] = []) -> (String, DictationCommand) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (text, .none) }

        // Whisper frequently appends terminal punctuation to short utterances (e.g.
        // "Scratch that."), which would otherwise defeat the end-anchored ($) patterns
        // below and silently insert the phrase as literal text instead of running the
        // command. Strip trailing punctuation/whitespace for matching purposes only —
        // `text`/`trimmed` (with punctuation intact) are still what's returned/inserted
        // when no command matches.
        let commandMatchText = strippedForCommandMatch(trimmed)

        if !customCommands.isEmpty,
           let result = processHotWordCommand(commandMatchText, commands: customCommands) {
            return result
        }

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

        return (text, .none)
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
