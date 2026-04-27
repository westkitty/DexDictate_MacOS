import ApplicationServices
import CoreGraphics
import Foundation

/// Separates TCC permission state from live capability.
///
/// `PermissionManager` polls TCC state (`AXIsProcessTrusted`, `authorizationStatus`, etc.).
/// This checker performs actual capability probes so the caller can distinguish
/// "permission granted" from "permission granted AND working."
///
/// Checks are injected as closures so they can be replaced in unit tests without
/// requiring real system UI or event taps.
public struct PermissionCapabilityChecker {
    public enum Status: Equatable {
        case passed
        case failed(reason: String)
        case skipped
    }

    public struct Report: Equatable {
        public let accessibilityElementRead: Status
        public let eventTapPreflight: Status

        /// True when every non-skipped check passed.
        public var allPassed: Bool {
            [accessibilityElementRead, eventTapPreflight]
                .allSatisfy { $0 == .passed || $0 == .skipped }
        }
    }

    var checkAXFocusedElementRead: () -> Bool
    var checkEventTapPreflight: () -> Bool

    /// Runs capability probes based on current permission grants.
    /// Skips a probe if the corresponding TCC permission is not yet granted.
    public func run(accessibilityGranted: Bool, inputMonitoringGranted: Bool) -> Report {
        let axStatus: Status
        if accessibilityGranted {
            axStatus = checkAXFocusedElementRead()
                ? .passed
                : .failed(reason: "Accessibility API returned an error reading the focused element.")
        } else {
            axStatus = .skipped
        }

        let tapStatus: Status
        if inputMonitoringGranted {
            tapStatus = checkEventTapPreflight()
                ? .passed
                : .failed(reason: "CGPreflightListenEventAccess() returned false despite permission appearing granted.")
        } else {
            tapStatus = .skipped
        }

        return Report(accessibilityElementRead: axStatus, eventTapPreflight: tapStatus)
    }

    /// Production checker using real system calls.
    public static let system = PermissionCapabilityChecker(
        checkAXFocusedElementRead: {
            let systemWide = AXUIElementCreateSystemWide()
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                systemWide, kAXFocusedUIElementAttribute as CFString, &value
            )
            // .noValue means AX is working but nothing is focused — that's fine.
            return result == .success || result == .noValue
        },
        checkEventTapPreflight: {
            CGPreflightListenEventAccess()
        }
    )
}

/// Convenience typealiases for call sites.
public typealias PermissionCapabilityReport = PermissionCapabilityChecker.Report
