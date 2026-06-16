import Foundation

/// Pure decision logic for the single-instance guard, separated from AppKit so it is
/// unit-testable without spawning real processes.
///
/// DexDictate is a menu-bar app: launching a second copy (e.g. when two app bundles are
/// installed) produces a second `MenuBarExtra` status item and popover, which users perceive
/// as "two instances". The guard detects an already-running instance and defers to it.
public enum InstanceGuard {
    /// Given the process identifiers of every running instance that shares this app's bundle
    /// identifier (the list normally includes the current process) and the current process id,
    /// returns the pid of an existing *other* instance this process should defer to, or `nil`
    /// if this is the only instance and should continue launching.
    ///
    /// When multiple other instances exist, the lowest pid is chosen deterministically so the
    /// behavior is stable and testable.
    public static func existingInstancePID(allInstancePIDs: [Int32], currentPID: Int32) -> Int32? {
        allInstancePIDs
            .filter { $0 != currentPID }
            .min()
    }
}
