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
            save()
        }
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
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([VocabularyItem].self, from: data) {
            items = decoded
        }
    }
}
