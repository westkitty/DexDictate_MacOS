import Foundation

/// Stateless text filter that substitutes offensive words with whimsical replacements.
public enum ProfanityFilter {

    private struct FilterData: Decodable {
        let strictReplacements: [String: String]
        let whimsicalMap: [String: String]
    }

    private static var filterData: FilterData = {
        guard let url = Safety.resourceBundle.url(forResource: "profanity_list", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(FilterData.self, from: data) else {
            Safety.log("WARNING: Failed to load profanity_list.json. Using empty filter.")
            return FilterData(strictReplacements: [:], whimsicalMap: [:])
        }
        return decoded
    }()

    private static let whimsicalRegexMap: [(word: String, regex: NSRegularExpression, replacement: String)] = {
        return filterData.whimsicalMap.compactMap { (word, replacement) in
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return nil
            }
            return (word, regex, replacement)
        }
    }()

    /// Number of words in the bundled filter list.
    public static var bundledWordCount: Int {
        filterData.strictReplacements.count + filterData.whimsicalMap.count
    }

    /// Returns a copy of `text` with all matched words replaced by their whimsical equivalents.
    ///
    /// - Parameters:
    ///   - text: The raw transcription string.
    ///   - additions: Extra words to filter (replaced with "****").
    ///   - removals: Bundled words to skip filtering (case-insensitive).
    /// - Returns: The filtered string, or the original string unchanged if no words match.
    public static func filter(_ text: String, additions: [String] = [], removals: [String] = []) -> String {
        var result = text
        let removalSet = Set(removals.map { $0.lowercased() })

        // 1. Strict case-sensitive replacements first (skip words in removals)
        for (target, replacement) in filterData.strictReplacements {
            guard !removalSet.contains(target.lowercased()) else { continue }
            result = result.replacingOccurrences(of: target, with: replacement)
        }

        // 2. Case-insensitive word-boundary replacements (skip words in removals)
        for (word, regex, replacement) in whimsicalRegexMap {
            guard !removalSet.contains(word.lowercased()) else { continue }
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
        }

        // 3. Custom additions: replace each added word with "****"
        for word in additions {
            let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let escaped = NSRegularExpression.escapedPattern(for: trimmed)
            let pattern = "\\b\(escaped)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "****")
            }
        }

        return result
    }
}
