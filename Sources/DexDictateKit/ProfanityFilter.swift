import Foundation

/// Stateless text filter that substitutes offensive words with whimsical replacements.
public enum ProfanityFilter {
    
    private struct FilterData: Decodable {
        let strictReplacements: [String: String]
        let whimsicalMap: [String: String]
    }
    
    private static var filterData: FilterData = {
        guard let url = Bundle.module.url(forResource: "profanity_list", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(FilterData.self, from: data) else {
            print("⚠️ Failed to load profanity_list.json. Using empty filter.")
            return FilterData(strictReplacements: [:], whimsicalMap: [:])
        }
        return decoded
    }()

    private static let whimsicalRegexMap: [(NSRegularExpression, String)] = {
        return filterData.whimsicalMap.compactMap { (word, replacement) in
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return nil
            }
            return (regex, replacement)
        }
    }()

    /// Returns a copy of `text` with all matched words replaced by their whimsical equivalents.
    ///
    /// - Parameter text: The raw transcription string.
    /// - Returns: The filtered string, or the original string unchanged if no words match.
    public static func filter(_ text: String) -> String {
        var result = text

        // 1. Strict case-sensitive replacements first
        for (target, replacement) in filterData.strictReplacements {
            result = result.replacingOccurrences(of: target, with: replacement)
        }

        // 2. Case-insensitive word-boundary replacements
        for (regex, replacement) in whimsicalRegexMap {
             let range = NSRange(location: 0, length: result.utf16.count)
             result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
        }

        return result
    }
}
