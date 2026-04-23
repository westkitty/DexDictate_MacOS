import Foundation

/// Schedules UI-triggered work onto the main actor without executing it inline in
/// SwiftUI's gesture dispatch stack.
///
/// DexDictate uses this trampoline for button and gesture callbacks that touch
/// `@MainActor`-isolated objects. Running the work in a fresh main-actor task avoids
/// SwiftUI calling into actor-isolated methods directly through
/// `MainActor.assumeIsolated`.
public enum MainActorAction {
    public static func run(_ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            action()
        }
    }

    public static func run(_ action: @escaping @MainActor () async -> Void) {
        Task { @MainActor in
            await action()
        }
    }
}
