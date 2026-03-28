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
        let punctuated = processPunctuation(text)
        let trimmed = punctuated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (punctuated, .none) }

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

        return (punctuated, .none)
    }

    private func processPunctuation(_ text: String) -> String {
        // Patterns that consume a preceding space and attach to the word before them.
        let attachBefore: [(pattern: String, replacement: String)] = [
            (#"\s*\bopen paren(?:thesis)?\b\s*"#,      " ("),
            (#"\s+\bclose paren(?:thesis)?\b"#,        ")"),
            (#"\s*\bopen (?:quote|quotes)\b\s*"#,      " \""),
            (#"\s+\bclose (?:quote|quotes)\b"#,        "\""),
            (#"\s+\bnew paragraph\b"#,                 "\n\n"),
            (#"\s+\bexclamation (?:point|mark)\b"#,    "!"),
            (#"\s+\bquestion mark\b"#,                 "?"),
            (#"\s+\bfull stop\b"#,                     "."),
            (#"\s+\bsemicolon\b"#,                     ";"),
            (#"\s+\bellipsis\b"#,                      "..."),
            (#"\s+\bperiod\b"#,                        "."),
            (#"\s+\bcomma\b"#,                         ","),
            (#"\s+\bcolon\b"#,                         ":"),
            (#"\s+\bdash\b\s+"#,                       "-"),
            (#"\s+\bhyphen\b\s+"#,                     "-"),
        ]

        var result = text
        for (pattern, replacement) in attachBefore {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
            }
        }
        return result
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
