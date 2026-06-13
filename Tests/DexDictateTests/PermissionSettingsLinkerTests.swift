import XCTest
@testable import DexDictateKit

final class PermissionSettingsLinkerTests: XCTestCase {

    // MARK: - URL construction

    func testMicrophoneURL() throws {
        let url = try XCTUnwrap(PermissionSettingsLinker.url(for: .microphone))
        XCTAssertEqual(url.scheme, "x-apple.systempreferences")
        XCTAssertTrue(url.absoluteString.contains("Privacy_Microphone"),
                      "Expected Privacy_Microphone fragment, got: \(url.absoluteString)")
    }

    func testAccessibilityURL() throws {
        let url = try XCTUnwrap(PermissionSettingsLinker.url(for: .accessibility))
        XCTAssertEqual(url.scheme, "x-apple.systempreferences")
        XCTAssertTrue(url.absoluteString.contains("Privacy_Accessibility"),
                      "Expected Privacy_Accessibility fragment, got: \(url.absoluteString)")
    }

    func testInputMonitoringURL() throws {
        let url = try XCTUnwrap(PermissionSettingsLinker.url(for: .inputMonitoring))
        XCTAssertEqual(url.scheme, "x-apple.systempreferences")
        XCTAssertTrue(url.absoluteString.contains("Privacy_ListenEvent"),
                      "Expected Privacy_ListenEvent fragment, got: \(url.absoluteString)")
    }

    func testFallbackURL() throws {
        let url = try XCTUnwrap(PermissionSettingsLinker.fallbackURL)
        XCTAssertEqual(url.scheme, "x-apple.systempreferences")
        XCTAssertEqual(url.absoluteString,
                       "x-apple.systempreferences:com.apple.preference.security")
    }

    // MARK: - URL uniqueness

    func testAllURLsAreDifferent() {
        let mic  = PermissionSettingsLinker.url(for: .microphone)
        let acc  = PermissionSettingsLinker.url(for: .accessibility)
        let inm  = PermissionSettingsLinker.url(for: .inputMonitoring)
        let fall = PermissionSettingsLinker.fallbackURL

        XCTAssertNotEqual(mic,  acc)
        XCTAssertNotEqual(mic,  inm)
        XCTAssertNotEqual(mic,  fall)
        XCTAssertNotEqual(acc,  inm)
        XCTAssertNotEqual(acc,  fall)
        XCTAssertNotEqual(inm,  fall)
    }

    // MARK: - PermissionManager delegation

    @MainActor
    func testPermissionManagerMicrophoneURLMatchesLinker() {
        let manager = PermissionManager()
        XCTAssertEqual(manager.microphoneSettingsURL,
                       PermissionSettingsLinker.url(for: .microphone))
    }

    @MainActor
    func testPermissionManagerAccessibilityURLMatchesLinker() {
        let manager = PermissionManager()
        XCTAssertEqual(manager.accessibilitySettingsURL,
                       PermissionSettingsLinker.url(for: .accessibility))
    }

    @MainActor
    func testPermissionManagerInputMonitoringURLMatchesLinker() {
        let manager = PermissionManager()
        XCTAssertEqual(manager.inputMonitoringSettingsURL,
                       PermissionSettingsLinker.url(for: .inputMonitoring))
    }
}
