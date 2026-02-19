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
        let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Command: "Scratch that" (Delete last)
        if lower.hasSuffix("scratch that") || lower == "scratch that" {
            // If the text is JUST "scratch that", we return empty and the command to delete previous.
            // If it's "Hello world scratch that", we return "Hello" (conceptually? or just delete last bit?)
            // Simple logic: "Scratch that" at end = Delete entire current segment/previous segment.
            return ("", .deleteLastSentence)
        }
        
        // Command: "New line" or "Next line"
        if lower.contains("new line") || lower.contains("next line") {
            let processed = text.replacingOccurrences(of: "new line", with: "\n", options: .caseInsensitive)
                                .replacingOccurrences(of: "next line", with: "\n", options: .caseInsensitive)
            return (processed, .newLine) // .newLine action might not be needed if we just replaced text
        }
        
        // Command: "All caps" (Uppercases the whole segment)
        if lower.hasSuffix("all caps") {
            let contentObj = text.dropLast("all caps".count).trimmingCharacters(in: .whitespaces)
            return (contentObj.uppercased(), .none)
        }
        
        return (text, .none)
    }
}
