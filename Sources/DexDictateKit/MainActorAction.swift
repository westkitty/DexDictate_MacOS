import Foundation

/// Schedules UI-triggered work onto the main actor without executing it inline in
/// SwiftUI's gesture dispatch stack.
///
/// DexDictate uses this trampoline for button and gesture callbacks that touch
/// `@MainActor`-isolated objects. The initial hop uses the main dispatch queue instead
/// of `Task { @MainActor in ... }` so UI actions do not create a Swift Concurrency
/// task directly from the gesture callback stack.
public enum MainActorAction {
    public static func run(_ action: @escaping @MainActor () -> Void) {
        MainActorDispatch.async {
            action()
        }
    }

    public static func run(_ action: @escaping @MainActor () async -> Void) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                _ = Task<Void, Never> {
                    await action()
                }
            }
        }
    }
}
