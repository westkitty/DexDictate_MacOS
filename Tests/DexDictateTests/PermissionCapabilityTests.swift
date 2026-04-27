import XCTest
@testable import DexDictateKit

/// Tests that `PermissionCapabilityChecker` correctly separates TCC permission state
/// from live capability, skipping checks when permissions are not yet granted.
final class PermissionCapabilityTests: XCTestCase {

    // MARK: - Accessibility element read

    func testAccessibilityReadPassesWhenGrantedAndCheckSucceeds() {
        let checker = PermissionCapabilityChecker(
            checkAXFocusedElementRead: { true },
            checkEventTapPreflight: { true }
        )
        let report = checker.run(accessibilityGranted: true, inputMonitoringGranted: true)
        XCTAssertEqual(report.accessibilityElementRead, .passed)
    }

    func testAccessibilityReadSkippedWhenNotGranted() {
        let checker = PermissionCapabilityChecker(
            checkAXFocusedElementRead: { XCTFail("Should not run check when not granted"); return false },
            checkEventTapPreflight: { true }
        )
        let report = checker.run(accessibilityGranted: false, inputMonitoringGranted: true)
        XCTAssertEqual(report.accessibilityElementRead, .skipped)
    }

    func testAccessibilityReadFailsWhenGrantedButCheckFails() {
        let checker = PermissionCapabilityChecker(
            checkAXFocusedElementRead: { false },
            checkEventTapPreflight: { true }
        )
        let report = checker.run(accessibilityGranted: true, inputMonitoringGranted: true)
        guard case .failed = report.accessibilityElementRead else {
            XCTFail("Expected .failed, got \(report.accessibilityElementRead)")
            return
        }
    }

    // MARK: - Event tap preflight

    func testEventTapPassesWhenGrantedAndCheckSucceeds() {
        let checker = PermissionCapabilityChecker(
            checkAXFocusedElementRead: { true },
            checkEventTapPreflight: { true }
        )
        let report = checker.run(accessibilityGranted: true, inputMonitoringGranted: true)
        XCTAssertEqual(report.eventTapPreflight, .passed)
    }

    func testEventTapSkippedWhenNotGranted() {
        let checker = PermissionCapabilityChecker(
            checkAXFocusedElementRead: { true },
            checkEventTapPreflight: { XCTFail("Should not run check when not granted"); return false }
        )
        let report = checker.run(accessibilityGranted: true, inputMonitoringGranted: false)
        XCTAssertEqual(report.eventTapPreflight, .skipped)
    }

    func testEventTapFailsWhenGrantedButCheckFails() {
        let checker = PermissionCapabilityChecker(
            checkAXFocusedElementRead: { true },
            checkEventTapPreflight: { false }
        )
        let report = checker.run(accessibilityGranted: true, inputMonitoringGranted: true)
        guard case .failed = report.eventTapPreflight else {
            XCTFail("Expected .failed, got \(report.eventTapPreflight)")
            return
        }
    }

    // MARK: - allPassed

    func testAllPassedTrueWhenBothSucceed() {
        let checker = PermissionCapabilityChecker(
            checkAXFocusedElementRead: { true },
            checkEventTapPreflight: { true }
        )
        let report = checker.run(accessibilityGranted: true, inputMonitoringGranted: true)
        XCTAssertTrue(report.allPassed)
    }

    func testAllPassedTrueWhenBothSkipped() {
        let checker = PermissionCapabilityChecker(
            checkAXFocusedElementRead: { true },
            checkEventTapPreflight: { true }
        )
        let report = checker.run(accessibilityGranted: false, inputMonitoringGranted: false)
        XCTAssertTrue(report.allPassed)
    }

    func testAllPassedFalseWhenAnyFails() {
        let checker = PermissionCapabilityChecker(
            checkAXFocusedElementRead: { false },
            checkEventTapPreflight: { true }
        )
        let report = checker.run(accessibilityGranted: true, inputMonitoringGranted: true)
        XCTAssertFalse(report.allPassed)
    }
}
