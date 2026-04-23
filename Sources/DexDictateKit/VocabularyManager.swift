import Foundation
import Combine

public struct VocabularyItem: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var original: String
    public var replacement: String
    
    public init(original: String, replacement: String) {
        self.original = original
        self.replacement = replacement
    }
}

public class VocabularyManager: ObservableObject {
    @Published public var items: [VocabularyItem] = [] {
        didSet {
            if !isLoading { save() }
        }
    }

    @Published public private(set) var bundledItems: [VocabularyItem] = []

    /// Set to `true` during `load()` to prevent the `items` `didSet` observer from
    /// writing data back to `UserDefaults` immediately after reading it.
    private var isLoading = false

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
    
    public func add(original: String, replacement: String) {
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
            let startBoundary = item.original.first?.isLetter == true || item.original.first?.isNumber == true ? "\\b" : ""
            let endBoundary = item.original.last?.isLetter == true || item.original.last?.isNumber == true ? "\\b" : ""
            
            let pattern = "\(startBoundary)\(escaped)\(endBoundary)"
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(processed.startIndex..<processed.endIndex, in: processed)
                processed = regex.stringByReplacingMatches(in: processed, options: [], range: range, withTemplate: item.replacement)
            } else {
                 processed = processed.replacingOccurrences(of: item.original, with: item.replacement, options: .caseInsensitive)
            }
        }
        return processed
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([VocabularyItem].self, from: data) else { return }
        isLoading = true
        defer { isLoading = false }
        items = decoded
    }
}
