import XCTest
@testable import DexDictateKit

final class InstanceGuardTests: XCTestCase {
    func testSoleInstanceContinuesLaunching() {
        // Only the current process is running -> nothing to defer to.
        let result = InstanceGuard.existingInstancePID(allInstancePIDs: [42], currentPID: 42)
        XCTAssertNil(result)
    }

    func testEmptyListContinuesLaunching() {
        let result = InstanceGuard.existingInstancePID(allInstancePIDs: [], currentPID: 42)
        XCTAssertNil(result)
    }

    func testDetectsExistingOtherInstance() {
        // Another instance (pid 10) is already running; current is 42 -> defer to 10.
        let result = InstanceGuard.existingInstancePID(allInstancePIDs: [10, 42], currentPID: 42)
        XCTAssertEqual(result, 10)
    }

    func testChoosesLowestPIDDeterministicallyAmongMultiple() {
        let result = InstanceGuard.existingInstancePID(allInstancePIDs: [99, 7, 55, 42], currentPID: 42)
        XCTAssertEqual(result, 7)
    }

    func testIgnoresOnlyTheCurrentPIDNotDuplicatesOfOtherValues() {
        // Defensive: current pid filtered out even if it appears; the other remains.
        let result = InstanceGuard.existingInstancePID(allInstancePIDs: [42, 42, 13], currentPID: 42)
        XCTAssertEqual(result, 13)
    }
}
