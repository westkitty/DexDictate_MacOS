/// Pure idempotency gate backing `LaunchIntroController`'s teardown (the `DexDictate`
/// executable target's launch-animation panel) — kept here, in `DexDictateKit`, rather than
/// inline in that controller, so `Tests/DexDictateTests` can exercise "first caller wins, every
/// other caller is a no-op" without constructing a real `NSPanel`/`AVPlayer` (unsafe/flaky in a
/// headless test run — the same reasoning `FloatingHUDVisibilityTests`'s doc comment gives for
/// keeping that suite free of real `NSWindow`/`NSPanel` construction).
///
/// The launch intro has several independent paths that can all want to tear the panel down —
/// the exit fade's completion handler, a fallback timer, a hard-deadline timer, and app
/// shutdown — plus stale callbacks that can fire after a dismissal already happened. This gate
/// is the single source of truth for "has teardown already run," so exactly one of those
/// callers performs the real work and the rest (including anything stale) safely no-op.
public final class LaunchIntroDismissalGate {
    private var hasFired = false

    public init() {}

    /// Returns `true` on the first call since construction (or since the last `reset()`);
    /// every subsequent call returns `false` without changing state.
    @discardableResult
    public func fireOnce() -> Bool {
        guard !hasFired else { return false }
        hasFired = true
        return true
    }

    /// Whether `fireOnce()` has already returned `true` since the last `reset()`.
    public var hasFiredAlready: Bool { hasFired }

    /// Rearms the gate for a new intro run (e.g. a later app launch reusing the same
    /// controller instance).
    public func reset() {
        hasFired = false
    }
}
