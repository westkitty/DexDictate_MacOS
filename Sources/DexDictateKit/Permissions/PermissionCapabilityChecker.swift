import ApplicationServices
import CoreGraphics
import Foundation

/// Separates TCC permission state from live capability.
///
/// DexDictate's global trigger uses a modifying CGEvent tap (`.defaultTap`). That path is
/// governed by Accessibility, not standalone Input Monitoring. The checker therefore validates
/// both Accessibility element access and actual modifying-event-tap creation under one grant.
public struct PermissionCapabilityChecker {
    public enum Status: Equatable {
        case passed
        case failed(reason: String)
        case skipped
    }

    public struct Report: Equatable {
        public let accessibilityElementRead: Status
        public let eventTapPreflight: Status

        public var allPassed: Bool {
            [accessibilityElementRead, eventTapPreflight]
                .allSatisfy { $0 == .passed || $0 == .skipped }
        }
    }

    var checkAXFocusedElementRead: () -> Bool
    var checkEventTapPreflight: () -> Bool

    /// The second parameter is retained as a source-compatibility shim for existing call sites.
    /// It is intentionally ignored; Accessibility governs both production capability probes.
    public func run(accessibilityGranted: Bool, inputMonitoringGranted _: Bool) -> Report {
        guard accessibilityGranted else {
            return Report(accessibilityElementRead: .skipped, eventTapPreflight: .skipped)
        }

        let axStatus: Status = checkAXFocusedElementRead()
            ? .passed
            : .failed(reason: "Accessibility API returned an error reading the focused element.")

        let tapStatus: Status = checkEventTapPreflight()
            ? .passed
            : .failed(reason: "Modifying CGEvent tap could not be created despite Accessibility trust.")

        return Report(accessibilityElementRead: axStatus, eventTapPreflight: tapStatus)
    }

    public static let system = PermissionCapabilityChecker(
        checkAXFocusedElementRead: {
            let systemWide = AXUIElementCreateSystemWide()
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                systemWide, kAXFocusedUIElementAttribute as CFString, &value
            )
            return result == .success || result == .noValue
        },
        checkEventTapPreflight: {
            TriggerValidationProbe.runCheck().isSuccess
        }
    )
}

public typealias PermissionCapabilityReport = PermissionCapabilityChecker.Report
