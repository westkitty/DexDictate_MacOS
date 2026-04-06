import XCTest
@testable import DexDictateKit

@MainActor
final class PermissionManagerTests: XCTestCase {
    func testOnboardingStopDoesNotDisableRuntimePolling() {
        let manager = PermissionManager()
        let engine = TranscriptionEngine()

        manager.startMonitoring()
        XCTAssertTrue(manager.hasActivePollingTimer)

        manager.startMonitoring(engine: engine)
        XCTAssertTrue(manager.hasActivePollingTimer)

        manager.stopMonitoring()
        XCTAssertTrue(manager.hasActivePollingTimer)

        manager.stopRuntimeMonitoring()
        XCTAssertFalse(manager.hasActivePollingTimer)
    }

    func testOnboardingOnlyStopCancelsPolling() {
        let manager = PermissionManager()

        manager.startMonitoring()
        XCTAssertTrue(manager.hasActivePollingTimer)

        manager.stopMonitoring()
        XCTAssertFalse(manager.hasActivePollingTimer)
    }
}
