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
    private let clock: any Clock<Duration>
    private var dismissTask: Task<Void, Never>?

    /// - Parameter clock: Source of the auto-dismiss delay. Defaults to a real
    ///   `ContinuousClock`; tests inject a virtual clock to advance the dismiss
    ///   timer deterministically instead of racing real wall-clock sleeps.
    public init(dismissAfter: TimeInterval = 2.5, clock: any Clock<Duration> = ContinuousClock()) {
        self.dismissAfter = dismissAfter
        self.clock = clock
    }

    /// Present a toast event and schedule auto-dismiss.
    /// Calling this while a toast is already showing replaces it and resets the timer.
    public func show(_ event: ToastEvent) {
        dismissTask?.cancel()
        current = event
        let delay = dismissAfter
        let clock = self.clock
        dismissTask = Task { [weak self] in
            do {
                try await clock.sleep(for: .seconds(delay))
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
