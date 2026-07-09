import Foundation
import Combine

public enum SmartCleanupReachability: Equatable {
    case disabled
    case unknown
    case reachable
    case unreachable
}

/// Watches `TranscriptionHistory.items` for newly-committed transcripts and, when Smart
/// Cleanup is enabled, requests a cleaned variant and attaches it via
/// `TranscriptionHistory.setCleanedText(_:forItemID:)`.
///
/// Deliberately reactive to `TranscriptionHistory` (not `TranscriptionEngine`, which is
/// forbidden) — `TranscriptionHistory.$items` is the only observation point needed to know
/// "a transcript was just committed," and it already exists, published, on a non-forbidden
/// file. This coordinator never touches insertion/output timing: by the time an item
/// appears in history, delivery has already happened. Cleanup is single-attempt per item —
/// no retry storm, no polling loop, no modal — matching "raw stands on failure."
@MainActor
public final class SmartCleanupCoordinator: ObservableObject {
    public static let shared = SmartCleanupCoordinator()

    @Published public private(set) var reachability: SmartCleanupReachability = .disabled

    private weak var history: TranscriptionHistory?
    private let settings: SmartCleanupSettings
    private var lastSeenItemID: UUID?
    private var cancellable: AnyCancellable?
    private var didStart = false

    init(settings: SmartCleanupSettings = .shared) {
        self.settings = settings
    }

    /// Idempotent — safe to call on every popover open, matching the app's existing
    /// `historyController.setup(...)` / `adaptiveBenchmarkController.start(engine:)` pattern.
    public func start(history: TranscriptionHistory) {
        guard !didStart else { return }
        didStart = true
        self.history = history
        lastSeenItemID = history.items.first?.id
        reachability = settings.enabled ? .unknown : .disabled

        cancellable = history.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.handleItemsChanged(items)
            }
    }

    private func handleItemsChanged(_ items: [HistoryItem]) {
        guard settings.enabled else {
            reachability = .disabled
            return
        }
        guard let newest = items.first, newest.id != lastSeenItemID else { return }
        lastSeenItemID = newest.id
        guard newest.cleanedText == nil, !newest.text.isEmpty else { return }

        Task { await attemptCleanup(item: newest) }
    }

    private func attemptCleanup(item: HistoryItem) async {
        let result = await SmartCleanupClient.cleanup(
            text: item.text,
            baseURLString: settings.baseURLString,
            model: settings.model,
            apiKey: settings.apiKey
        )
        switch result {
        case .success(let cleaned):
            reachability = .reachable
            history?.setCleanedText(cleaned, forItemID: item.id)
        case .failure:
            // Raw result stands. Single attempt — no retry, no modal.
            reachability = .unreachable
        }
    }

    /// Called by the Diagnostics status row and the Settings page's Test Connection button
    /// to refresh `reachability` without waiting for the next dictation.
    public func refreshReachability() async {
        guard settings.enabled else {
            reachability = .disabled
            return
        }
        let result = await SmartCleanupClient.testConnection(
            baseURLString: settings.baseURLString,
            apiKey: settings.apiKey
        )
        switch result {
        case .success: reachability = .reachable
        case .failure: reachability = .unreachable
        }
    }
}
