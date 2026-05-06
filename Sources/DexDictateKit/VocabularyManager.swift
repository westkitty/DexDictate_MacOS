import Foundation
import Combine
import os

public struct VocabularyItem: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var original: String
    public var replacement: String
    
    public init(original: String, replacement: String) {
        self.original = original
        self.replacement = replacement
    }
}

public enum VocabularyManagerError: LocalizedError {
    case emptyPattern
    case duplicatePattern(String)

    public var errorDescription: String? {
        switch self {
        case .emptyPattern:
            return "Vocabulary pattern must not be blank."
        case .duplicatePattern(let original):
            return "A vocabulary entry for \"\(original)\" already exists."
        }
    }
}

public class VocabularyManager: ObservableObject {
    @Published public var items: [VocabularyItem] = [] {
        didSet {
            invalidateCache()
            if !isLoading { save() }
        }
    }

    @Published public private(set) var bundledItems: [VocabularyItem] = [] {
        didSet { invalidateCache() }
    }

    /// Surfaced persistence errors observable by the UI.
    @Published public var persistenceError: String? = nil

    /// Set to `true` during `load()` to prevent the `items` `didSet` observer from
    /// writing data back to `UserDefaults` immediately after reading it.
    private var isLoading = false

    // MARK: - Regex cache

    /// Cache of compiled NSRegularExpression objects keyed on the full pattern string.
    private var regexCache: [String: NSRegularExpression] = [:]

    private func invalidateCache() {
        regexCache.removeAll()
    }

    /// Returns a compiled regex, using the cache on hit and storing on miss.
    private func compiledRegex(for pattern: String, options: NSRegularExpression.Options) throws -> NSRegularExpression {
        if let cached = regexCache[pattern] { return cached }
        let regex = try NSRegularExpression(pattern: pattern, options: options)
        regexCache[pattern] = regex
        return regex
    }

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.dexdictate", category: "VocabularyManager")

    public var effectiveItems: [VocabularyItem] {
        effectiveItems(additionalItems: [])
    }

    public func effectiveItems(additionalItems: [VocabularyItem]) -> [VocabularyItem] {
        var mergedByOriginal: [String: VocabularyItem] = [:]
        var orderedKeys: [String] = []

        for item in bundledItems {
            let key = item.original.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            if mergedByOriginal[key] == nil {
                orderedKeys.append(key)
            }
            mergedByOriginal[key] = item
        }

        for item in additionalItems {
            let key = item.original.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            if mergedByOriginal[key] == nil {
                orderedKeys.append(key)
            }
            mergedByOriginal[key] = item
        }

        for item in items {
            let key = item.original.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            if mergedByOriginal[key] == nil {
                orderedKeys.append(key)
            }
            mergedByOriginal[key] = item
        }

        return orderedKeys.compactMap { mergedByOriginal[$0] }
    }
    
    private let storageKey = "customVocabulary"
    
    public init() {
        load()
    }
    
    public func add(original: String, replacement: String) throws {
        let trimmed = original.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw VocabularyManagerError.emptyPattern
        }
        guard !items.contains(where: { $0.original.lowercased() == trimmed.lowercased() }) else {
            throw VocabularyManagerError.duplicatePattern(trimmed)
        }
        let item = VocabularyItem(original: original, replacement: replacement)
        items.append(item)
    }
    
    public func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    public func apply(to text: String) -> String {
        apply(text, using: items)
    }

    public func applyEffective(to text: String) -> String {
        applyEffective(to: text, additionalItems: [])
    }

    public func applyEffective(to text: String, additionalItems: [VocabularyItem]) -> String {
        apply(text, using: effectiveItems(additionalItems: additionalItems))
    }

    public func setBundledItems(_ items: [VocabularyItem]) {
        bundledItems = items
    }

    public func clearBundledItems() {
        bundledItems = []
    }

    private func apply(_ text: String, using items: [VocabularyItem]) -> String {
        var processed = text
        for item in items {
            // Conditional word boundaries: only apply if the pattern starts/ends with a word character
            let escaped = NSRegularExpression.escapedPattern(for: item.original)
            let useStartBoundary = item.original.first?.isLetter == true || item.original.first?.isNumber == true
            let useEndBoundary = item.original.last?.isLetter == true || item.original.last?.isNumber == true
            let startBoundary = useStartBoundary ? "\\b" : ""
            let endBoundary = useEndBoundary ? "\\b" : ""

            let pattern = "\(startBoundary)\(escaped)\(endBoundary)"

            // Use unicode word boundaries when the pattern contains any \b anchor.
            var options: NSRegularExpression.Options = .caseInsensitive
            if useStartBoundary || useEndBoundary {
                options.insert(.useUnicodeWordBoundaries)
            }

            do {
                let regex = try compiledRegex(for: pattern, options: options)
                let range = NSRange(processed.startIndex..<processed.endIndex, in: processed)
                let escapedReplacement = NSRegularExpression.escapedTemplate(for: item.replacement)
                processed = regex.stringByReplacingMatches(in: processed, options: [], range: range, withTemplate: escapedReplacement)
            } catch {
                processed = processed.replacingOccurrences(of: item.original, with: item.replacement, options: .caseInsensitive)
            }
        }
        return processed
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            logger.error("VocabularyManager save failed: \(error)")
            persistenceError = "Vocabulary save failed: \(error.localizedDescription)"
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([VocabularyItem].self, from: data)
            isLoading = true
            defer { isLoading = false }
            items = decoded
            persistenceError = nil
        } catch {
            logger.error("VocabularyManager load failed: \(error)")
            persistenceError = "Vocabulary load failed: \(error.localizedDescription)"
        }
    }
}
