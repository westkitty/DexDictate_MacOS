import Foundation
import Combine

/// Holds the currently visible toast notification and handles auto-dismiss timing.
///
/// Observed by SwiftUI views in both `FloatingHUDView` and `DexNanoHUDView`.
/// All mutations are expected on `@MainActor`.
@MainActor
public final class ToastState: ObservableObject {
    /// The currently presented event, or `nil` when no toast is shown.
    @Published public private(set) var current: ToastEvent? = nil

    private let dismissAfter: TimeInterval
    private var dismissTask: Task<Void, Never>?

    public init(dismissAfter: TimeInterval = 2.5) {
        self.dismissAfter = dismissAfter
    }

    /// Present a toast event and schedule auto-dismiss.
    /// Calling this while a toast is already showing replaces it and resets the timer.
    public func show(_ event: ToastEvent) {
        dismissTask?.cancel()
        current = event
        let delay = dismissAfter
        dismissTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                // Cancelled — a newer event is taking over.
                return
            }
            guard let self else { return }
            self.current = nil
            self.dismissTask = nil
        }
    }

    /// Immediately clear the current toast (e.g. on engine stop).
    public func clear() {
        dismissTask?.cancel()
        dismissTask = nil
        current = nil
    }
}
