import Foundation

/// A fully virtual `Clock` for deterministic timer tests: no real sleeping
/// occurs. Tests advance time explicitly with `advance(by:)`, so assertions
/// about "before/after a timer fires" never race against real wall-clock
/// scheduling jitter (as they would with `Task.sleep` under CI load).
final class ManualClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        fileprivate var offset: Duration
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
    }

    private struct Waiter {
        let id: Int
        let deadline: Instant
        let continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    private var currentInstant = Instant(offset: .zero)
    private var waiters: [Waiter] = []
    private var nextWaiterID = 0

    var minimumResolution: Duration { .zero }

    var now: Instant {
        lock.lock()
        defer { lock.unlock() }
        return currentInstant
    }

    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        try Task.checkCancellation()

        lock.lock()
        if currentInstant >= deadline {
            lock.unlock()
            return
        }
        let id = nextWaiterID
        nextWaiterID += 1
        lock.unlock()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.lock()
                if currentInstant >= deadline {
                    lock.unlock()
                    continuation.resume()
                    return
                }
                waiters.append(Waiter(id: id, deadline: deadline, continuation: continuation))
                lock.unlock()
            }
        } onCancel: { [self] in
            lock.lock()
            let index = waiters.firstIndex { $0.id == id }
            let cancelled = index.map { waiters.remove(at: $0) }
            lock.unlock()
            cancelled?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves virtual time forward and resumes any sleeps whose deadline has passed.
    func advance(by duration: Duration) {
        lock.lock()
        currentInstant = currentInstant.advanced(by: duration)
        let now = currentInstant
        let ready = waiters.filter { $0.deadline <= now }
        waiters.removeAll { $0.deadline <= now }
        lock.unlock()
        for waiter in ready {
            waiter.continuation.resume()
        }
    }
}
