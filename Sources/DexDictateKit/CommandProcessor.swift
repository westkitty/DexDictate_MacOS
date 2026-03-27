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
    /// - Returns: Tuple containing processed text (if any remains) and the command action.
    public func process(_ text: String) -> (String, DictationCommand) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (text, .none) }

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
