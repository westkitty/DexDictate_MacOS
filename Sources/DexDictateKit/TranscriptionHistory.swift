import Foundation

/// A single entry in the transcription history.
///
/// Wraps the transcribed text with a stable `UUID` identity so SwiftUI's `ForEach` can
/// animate insertions and deletions correctly (unlike an index-based approach).
public struct HistoryItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public let text: String
    public let createdAt: Date
    public let sourceHistoryItemID: UUID?
    public let isAccuracyRetry: Bool
    /// Smart Cleanup's post-processed variant, set asynchronously after this item is
    /// already in history (Packet 13). `nil` when Smart Cleanup is off, still pending, or
    /// failed. `text` above is always the raw transcript and is never overwritten — this
    /// field is purely additive and optional so existing persisted history (and any test
    /// fixture) decodes unchanged without it.
    public var cleanedText: String?

    public init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        sourceHistoryItemID: UUID? = nil,
        isAccuracyRetry: Bool = false,
        cleanedText: String? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.sourceHistoryItemID = sourceHistoryItemID
        self.isAccuracyRetry = isAccuracyRetry
        self.cleanedText = cleanedText
    }
}

/// An ordered, size-bounded list of ``HistoryItem`` values for the current session.
///
/// Items are prepended (most-recent first) and the list is capped at 50 entries.
/// Persistence to disk is opt-in via `AppSettings.persistHistory` and managed externally.
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
    @discardableResult
    public func add(
        _ text: String,
        sourceHistoryItemID: UUID? = nil,
        isAccuracyRetry: Bool = false
    ) -> HistoryItem? {
        guard !text.isEmpty else { return nil }
        let item = HistoryItem(
            text: text,
            sourceHistoryItemID: sourceHistoryItemID,
            isAccuracyRetry: isAccuracyRetry
        )
        items.insert(item, at: 0)
        if items.count > maxItems {
            items.removeLast()
        }
        return item
    }

    /// Appends a pre-existing item (e.g. loaded from disk) to the end of the list,
    /// trimming the oldest entry if the list exceeds `maxItems`.
    /// Used only during session restore — not for new dictations.
    public func insert(_ item: HistoryItem) {
        items.append(item)
        if items.count > maxItems {
            items.removeLast()
        }
    }

    public func clear() {
        items.removeAll(keepingCapacity: false)
        lastRemovedItem = nil
    }

    /// Attaches a Smart Cleanup variant to an existing item, found by id (Packet 13). A
    /// no-op if the item has since scrolled out of the capped list (e.g. many dictations
    /// happened before the cleanup round-trip returned) — the raw item is unaffected
    /// either way, so a missed attachment never loses data, just the cleaned display.
    public func setCleanedText(_ cleanedText: String, forItemID id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].cleanedText = cleanedText
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
