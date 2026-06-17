import Foundation

/// Installs a process-wide handler for uncaught Objective-C exceptions so that a crash leaves
/// a durable, symbolicable record in the local diagnostics before the process dies.
///
/// This complements the AVAudioEngine installTap bridge: that bridge converts a *known*
/// recoverable exception into a Swift error, whereas this is the last-resort net for any
/// *unanticipated* uncaught exception. It does not (and cannot) catch fatal Swift errors or
/// signals — only Objective-C `NSException`s — but those are the most common silent-abort class.
public enum CrashReporter {
    /// Installs the uncaught-exception handler. Call once, as early as possible in launch.
    public static func install() {
        NSSetUncaughtExceptionHandler { exception in
            let message = CrashReporter.formatMessage(
                name: exception.name.rawValue,
                reason: exception.reason,
                stack: exception.callStackSymbols
            )
            Safety.logCrash(message)
        }
    }

    /// Pure formatter for an uncaught-exception record. Separated for unit testing.
    static func formatMessage(name: String, reason: String?, stack: [String]) -> String {
        let reasonText = (reason?.isEmpty == false) ? reason! : "(no reason)"
        let header = "UNCAUGHT EXCEPTION: \(name): \(reasonText)"
        guard !stack.isEmpty else { return header }
        return header + "\n" + stack.joined(separator: "\n")
    }
}
