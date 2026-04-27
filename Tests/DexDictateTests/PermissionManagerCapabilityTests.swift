import XCTest
@testable import DexDictateKit

@MainActor
final class PermissionManagerCapabilityTests: XCTestCase {
    func testCapabilityReportPopulatedImmediatelyAfterInit() {
        let manager = PermissionManager()
        XCTAssertNotNil(manager.capabilityReport, "capabilityReport should be set after init() because init() calls checkPermissions()")
    }

    func testCapabilityReportUpdatedOnRefresh() {
        let manager = PermissionManager()
        let firstReport = manager.capabilityReport
        manager.refreshPermissions()
        // Report should still be non-nil after subsequent refresh
        XCTAssertNotNil(manager.capabilityReport)
        // Both reports should have the same structure (same system state)
        XCTAssertEqual(manager.capabilityReport?.allPassed, firstReport?.allPassed)
    }

    func testPassingCheckerNeverProducesFailedStatus() {
        let manager = PermissionManager()
        manager.capabilityChecker = PermissionCapabilityChecker(
            checkAXFocusedElementRead: { true },
            checkEventTapPreflight: { true }
        )
        manager.refreshPermissions()

        guard let report = manager.capabilityReport else {
            return XCTFail("capabilityReport must not be nil after refresh")
        }

        // With a passing probe, result is .passed (permission granted) or .skipped (not granted).
        // It must never be .failed.
        XCTAssertNotEqual(
            report.accessibilityElementRead,
            .failed(reason: "Accessibility API returned an error reading the focused element.")
        )
        XCTAssertNotEqual(
            report.eventTapPreflight,
            .failed(reason: "CGPreflightListenEventAccess() returned false despite permission appearing granted.")
        )
    }

    func testFailingCheckerNeverProducesPassedStatus() {
        let manager = PermissionManager()
        manager.capabilityChecker = PermissionCapabilityChecker(
            checkAXFocusedElementRead: { false },
            checkEventTapPreflight: { false }
        )
        manager.refreshPermissions()

        guard let report = manager.capabilityReport else {
            return XCTFail("capabilityReport must not be nil after refresh")
        }

        // With a failing probe, result is .failed (permission granted) or .skipped (not granted).
        // It must never be .passed.
        XCTAssertNotEqual(report.accessibilityElementRead, .passed)
        XCTAssertNotEqual(report.eventTapPreflight, .passed)
    }
}
