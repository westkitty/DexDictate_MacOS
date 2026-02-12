import Foundation

/// A single entry in the transcription history.
///
/// Wraps the transcribed text with a stable `UUID` identity so SwiftUI's `ForEach` can
/// animate insertions and deletions correctly (unlike an index-based approach).
struct HistoryItem: Identifiable {
    let id = UUID()
    let text: String
}

/// An ordered, size-bounded list of ``HistoryItem`` values for the current session.
///
/// Items are prepended (most-recent first) and the list is capped at 50 entries.
/// History is **not** persisted to disk — it resets on every app launch.
@MainActor
final class TranscriptionHistory: ObservableObject {

    /// The list of history items, most-recent first. Read-only outside this class.
    @Published private(set) var items: [HistoryItem] = []

    private let maxItems = 50

    var isEmpty: Bool { items.isEmpty }

    /// Prepends a new item and trims the list when it exceeds `maxItems`.
    ///
    /// - Parameter text: The transcription text to add. Empty strings are silently ignored.
    func add(_ text: String) {
        guard !text.isEmpty else { return }
        items.insert(HistoryItem(text: text), at: 0)
        if items.count > maxItems {
            items.removeLast()
        }
    }

    func clear() {
        items.removeAll()
    }
}
