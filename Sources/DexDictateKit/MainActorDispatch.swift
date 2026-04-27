import Foundation

enum MainActorDispatch {
    /// Schedules main-actor work from foreign callback boundaries without creating a Swift
    /// Concurrency task at the boundary itself.
    static func async(_ body: @escaping @MainActor @Sendable () -> Void) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                body()
            }
        }
    }
}
