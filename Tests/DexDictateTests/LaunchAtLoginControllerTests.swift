import XCTest
@testable import DexDictateKit

@MainActor
final class LaunchAtLoginControllerTests: XCTestCase {
    func testRegisterSuccessUpdatesStatusAndClearsErrors() {
        let service = MockLaunchAtLoginService(status: .disabled)
        let controller = LaunchAtLoginController(service: service)

        controller.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(controller.status, .enabled)
        XCTAssertNil(controller.lastError)
        XCTAssertTrue(controller.isEnabled)
    }

    func testRegisterFailurePreservesErrorMessage() {
        let service = MockLaunchAtLoginService(status: .disabled, registerError: MockError.failed)
        let controller = LaunchAtLoginController(service: service)

        controller.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(controller.status, .disabled)
        XCTAssertEqual(controller.lastError, MockError.failed.localizedDescription)
    }

    func testRequiresApprovalStatusRemainsActionable() {
        let service = MockLaunchAtLoginService(status: .requiresApproval)
        let controller = LaunchAtLoginController(service: service)

        XCTAssertTrue(controller.isEnabled)
        XCTAssertTrue(controller.needsSystemApproval)
        XCTAssertTrue(controller.canAttemptRegistration)
        XCTAssertEqual(
            controller.statusMessage,
            "macOS still needs approval in Login Items before launch at login becomes active."
        )
    }

    func testUnavailableStatusStillAllowsRegistrationAttempt() {
        let service = MockLaunchAtLoginService(status: .unavailable)
        let controller = LaunchAtLoginController(service: service)

        XCTAssertTrue(controller.canAttemptRegistration)
        XCTAssertFalse(controller.isEnabled)

        controller.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(controller.status, .enabled)
        XCTAssertNil(controller.lastError)
    }
}

private final class MockLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus
    var registerError: Error?
    var unregisterError: Error?
    var registerCallCount = 0
    var unregisterCallCount = 0

    init(
        status: LaunchAtLoginStatus,
        registerError: Error? = nil,
        unregisterError: Error? = nil
    ) {
        self.status = status
        self.registerError = registerError
        self.unregisterError = unregisterError
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
        status = .disabled
    }

    func openSystemSettings() {}
}

private enum MockError: LocalizedError {
    case failed

    var errorDescription: String? {
        "mock launch-at-login failure"
    }
}
