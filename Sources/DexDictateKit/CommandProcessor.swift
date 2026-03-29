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

        if !customCommands.isEmpty,
           let result = processHotWordCommand(trimmed, commands: customCommands) {
            return result
        }

        if matchesCommand(trimmed, pattern: #"(?i)(?:^|\s)scratch that$"#) {
            return ("", .deleteLastSentence)
        }

        if matchesCommand(trimmed, pattern: #"(?i)(?:^|\s)all caps$"#) {
            let content = trimmed.replacingOccurrences(
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
