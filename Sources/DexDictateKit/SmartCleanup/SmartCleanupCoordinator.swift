import Foundation
import Combine

/// Distinguishes every failure mode `SmartCleanupClientError` can already report — collapsing
/// all of them into a single `.unreachable` (the previous shape) meant "no server address
/// configured," "server down," "wrong model name," and "bad API key" all displayed as the
/// same unhelpful word.
public enum SmartCleanupReachability: Equatable {
    /// The feature toggle itself is off. Renamed from `.disabled` to match the vocabulary
    /// used everywhere else in the UI ("Not enabled").
    case notEnabled
    /// No check has run yet since Smart Cleanup was enabled/the app launched.
    case unknown
    /// Connection succeeded and the configured model (if any) was confirmed present.
    case ready
    /// Could not reach the server at all — includes "no address configured," network
    /// failures, and non-auth HTTP errors. `reason` is user-facing and specific.
    case serviceUnavailable(reason: String)
    /// The server responded, but the configured model name wasn't in its model list.
    case modelNotInstalled(reason: String)
    /// The server returned HTTP 401/403 — the API key is missing or wrong.
    case authenticationRequired
    /// A real cleanup attempt (not an explicit connection test) failed. Kept distinct from
    /// `.serviceUnavailable` so a transient failure during actual use reads differently from
    /// "you haven't configured this yet."
    case lastRequestFailed(reason: String)

    /// Short, user-facing label — the single word/phrase Diagnostics shows in its status row.
    public var statusLabel: String {
        switch self {
        case .notEnabled: return "Not enabled"
        case .unknown: return "Unknown — no check yet"
        case .ready: return "Ready"
        case .serviceUnavailable: return "Service unavailable"
        case .modelNotInstalled: return "Model not installed"
        case .authenticationRequired: return "Authentication required"
        case .lastRequestFailed: return "Last request failed"
        }
    }

    /// Longer explanation, when one exists beyond the label itself.
    public var detail: String? {
        switch self {
        case .serviceUnavailable(let reason), .modelNotInstalled(let reason), .lastRequestFailed(let reason):
            return reason
        case .notEnabled, .unknown, .ready, .authenticationRequired:
            return nil
        }
    }
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

    @Published public private(set) var reachability: SmartCleanupReachability = .notEnabled

    private weak var history: TranscriptionHistory?
    private let settings: SmartCleanupSettings
    private var lastSeenItemID: UUID?
    private var cancellable: AnyCancellable?
    private var didStart = false

    /// Bug sweep fix: a default-argument expression referencing a `@MainActor`-isolated
    /// static (`SmartCleanupSettings.shared`) is evaluated in a nonisolated context by
    /// Swift's own default-argument rules — a warning today ("this is an error in the
    /// Swift 6 language mode"). Resolving the default inside the (actor-isolated) body
    /// instead avoids the mismatch entirely.
    init(settings: SmartCleanupSettings? = nil) {
        self.settings = settings ?? .shared
    }

    /// Idempotent — safe to call on every popover open, matching the app's existing
    /// `historyController.setup(...)` / `adaptiveBenchmarkController.start(engine:)` pattern.
    public func start(history: TranscriptionHistory) {
        guard !didStart else { return }
        didStart = true
        self.history = history
        lastSeenItemID = history.items.first?.id
        reachability = settings.enabled ? .unknown : .notEnabled
        if settings.enabled {
            Task { await refreshReachability() }
        }

        cancellable = history.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.handleItemsChanged(items)
            }
    }

    /// Call whenever `settings.enabled` changes — `start(history:)` only runs once per
    /// process, so nothing previously re-checked reachability the moment the user flipped
    /// the toggle on; it just sat at `.unknown` until either a real dictation happened or the
    /// user separately visited the Smart Cleanup settings page and clicked Test Connection.
    public func handleEnabledSettingChanged() {
        guard settings.enabled else {
            reachability = .notEnabled
            return
        }
        reachability = .unknown
        Task { await refreshReachability() }
    }

    private func handleItemsChanged(_ items: [HistoryItem]) {
        guard settings.enabled else {
            reachability = .notEnabled
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
            reachability = .ready
            history?.setCleanedText(cleaned, forItemID: item.id)
        case .failure(let error):
            // Raw result stands regardless — single attempt, no retry, no modal. This is a
            // real cleanup attempt (not an explicit connection test), so a failure here is
            // reported as `.lastRequestFailed` rather than `.serviceUnavailable` — distinct
            // language for "it broke just now" vs. "you haven't configured this yet."
            reachability = Self.reachability(forRealRequestFailure: error)
        }
    }

    /// Called by the Diagnostics status row's "Check Again" action, the Settings page's Test
    /// Connection button, and automatically whenever Smart Cleanup is enabled — refreshes
    /// `reachability` without waiting for the next dictation, and distinguishes "server
    /// unreachable" from "server reachable but the configured model isn't installed there."
    public func refreshReachability() async {
        guard settings.enabled else {
            reachability = .notEnabled
            return
        }
        let result = await SmartCleanupClient.testConnection(
            baseURLString: settings.baseURLString,
            apiKey: settings.apiKey
        )
        switch result {
        case .success(let models):
            let configuredModel = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
            if !configuredModel.isEmpty, !models.modelIDs.isEmpty, !models.modelIDs.contains(configuredModel) {
                reachability = .modelNotInstalled(
                    reason: "Model '\(configuredModel)' not found on server. Available: \(models.modelIDs.prefix(5).joined(separator: ", "))"
                )
            } else {
                reachability = .ready
            }
        case .failure(let error):
            reachability = Self.reachability(forConnectionTestFailure: error)
        }
    }

    /// Shared HTTP-status interpretation: 401/403 always means the API key is missing or
    /// wrong, regardless of which call surfaced it.
    private static func reachability(forConnectionTestFailure error: SmartCleanupClientError) -> SmartCleanupReachability {
        switch error {
        case .http(401), .http(403):
            return .authenticationRequired
        case .invalidURL:
            return .serviceUnavailable(reason: "No server address configured.")
        default:
            return .serviceUnavailable(reason: error.localizedDescription)
        }
    }

    private static func reachability(forRealRequestFailure error: SmartCleanupClientError) -> SmartCleanupReachability {
        switch error {
        case .http(401), .http(403):
            return .authenticationRequired
        default:
            return .lastRequestFailed(reason: error.localizedDescription)
        }
    }
}
