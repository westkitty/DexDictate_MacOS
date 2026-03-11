import Foundation

/// A single entry in the transcription history.
///
/// Wraps the transcribed text with a stable `UUID` identity so SwiftUI's `ForEach` can
/// animate insertions and deletions correctly (unlike an index-based approach).
public struct HistoryItem: Identifiable {
    public let id = UUID()
    public let text: String
    public let createdAt: Date
    
    public init(text: String, createdAt: Date = Date()) {
        self.text = text
        self.createdAt = createdAt
    }
}

/// An ordered, size-bounded list of ``HistoryItem`` values for the current session.
///
/// Items are prepended (most-recent first) and the list is capped at 50 entries.
/// History is **not** persisted to disk — it resets on every app launch.
@MainActor
public final class TranscriptionHistory: ObservableObject {

    /// The list of history items, most-recent first. Read-only outside this class.
    @Published public private(set) var items: [HistoryItem] = []
    @Published public private(set) var lastRemovedItem: HistoryItem?

    private let maxItems = 50

    public var isEmpty: Bool { items.isEmpty }
    public var canRestoreLastRemovedItem: Bool { lastRemovedItem != nil }

    public init() {}

    /// Prepends a new item and trims the list when it exceeds `maxItems`.
    ///
    /// - Parameter text: The transcription text to add. Empty strings are silently ignored.
    public func add(_ text: String) {
        guard !text.isEmpty else { return }
        items.insert(HistoryItem(text: text), at: 0)
        if items.count > maxItems {
            items.removeLast()
        }
    }

    public func clear() {
        items.removeAll(keepingCapacity: false)
        lastRemovedItem = nil
    }
    
    @discardableResult
    public func removeMostRecent() -> HistoryItem? {
        guard !items.isEmpty else { return nil }
        let removed = items.removeFirst()
        lastRemovedItem = removed
        return removed
    }

    @discardableResult
    public func restoreMostRecentRemoval() -> Bool {
        guard let lastRemovedItem else { return false }
        items.insert(lastRemovedItem, at: 0)
        if items.count > maxItems {
            items.removeLast()
        }
        self.lastRemovedItem = nil
        return true
    }
}
