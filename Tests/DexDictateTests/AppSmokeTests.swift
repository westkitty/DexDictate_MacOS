// AppSmokeTests.swift
//
// WHY NOT XCUITest:
// DexDictate is built with Swift Package Manager (Package.swift), which does not
// support XCUITest bundles — those require an Xcode .xcodeproj target of type
// UI Testing Bundle with the XCTest host-app infrastructure. SPM only exposes a
// plain XCTestCase target that can import library modules (DexDictateKit), so
// end-to-end UI automation is not feasible in this build configuration.
//
// These tests are the closest feasible alternative: they exercise the library
// layer that backs the UI — confirming that core services initialize without
// crashing and that their default state matches UI expectations. This gives
// meaningful launch-viability coverage without requiring Xcode project changes.

import XCTest
@testable import DexDictateKit

// MARK: - Core service initialization

@MainActor
final class AppSmokeTests: XCTestCase {

    // MARK: PermissionManager

    func testPermissionManagerInitializesWithoutCrashing() {
        // Should not trap; verifies initializer + first checkPermissions() call succeed.
        let manager = PermissionManager()
        // permissionsSummary is set synchronously in checkPermissions() during init.
        XCTAssertFalse(manager.permissionsSummary.isEmpty,
            "permissionsSummary must be non-empty immediately after init")
    }

    func testPermissionManagerURLHelpersReturnNonNil() {
        let manager = PermissionManager()
        XCTAssertNotNil(manager.microphoneSettingsURL,
            "microphoneSettingsURL should return a URL")
        XCTAssertNotNil(manager.accessibilitySettingsURL,
            "accessibilitySettingsURL should return a URL")
        XCTAssertNotNil(manager.inputMonitoringSettingsURL,
            "inputMonitoringSettingsURL should return a URL")
    }

    // MARK: TranscriptionEngine

    func testTranscriptionEngineInitializesWithoutCrashing() {
        // Uses default OutputCoordinator and BrowserMediaPauseService parameters.
        // Reaching this line without a trap is the assertion — engine is non-optional.
        _ = TranscriptionEngine()
    }

    func testEngineDefaultStateIsStoppedNotError() {
        let engine = TranscriptionEngine()
        // The engine must not start in the .error state — that would prevent it
        // from ever transitioning to .ready, blocking dictation entirely.
        XCTAssertNotEqual(engine.state, .error,
            "Engine must not initialize in .error state")
        XCTAssertTrue(engine.state == .stopped || engine.state == .initializing,
            "Engine initial state should be .stopped or .initializing, got \(engine.state)")
    }

    func testEngineStatusTextIsNonEmptyOnInit() {
        let engine = TranscriptionEngine()
        XCTAssertFalse(engine.statusText.isEmpty,
            "statusText must be non-empty on init")
    }

    func testEngineStatusIconIsNonEmptyOnInit() {
        let engine = TranscriptionEngine()
        XCTAssertFalse(engine.statusIcon.isEmpty,
            "statusIcon must be non-empty on init")
    }

    // MARK: CommandProcessor

    func testCommandProcessorInitializesWithoutCrashing() {
        // Reaching this line without a trap is the assertion — processor is non-optional.
        _ = CommandProcessor()
    }

    func testCommandProcessorHandlesEmptyInputSafely() {
        let processor = CommandProcessor()
        let (text, command) = processor.process("")
        XCTAssertEqual(text, "",
            "Empty input should return empty string, not crash")
        XCTAssertEqual(command, .none,
            "Empty input should return .none command")
    }

    func testCommandProcessorHandlesWhitespaceOnlyInputSafely() {
        let processor = CommandProcessor()
        let (text, command) = processor.process("   \t\n  ")
        XCTAssertEqual(command, .none,
            "Whitespace-only input should return .none command without crashing")
        // text may be the original whitespace string — just verify no crash
        _ = text
    }

    // MARK: ExperimentFlags

    func testPreTriggerBufferDefaultIsFalse() {
        XCTAssertFalse(ExperimentFlags.enablePreTriggerBuffer,
            "Pre-trigger buffer must default to false for safe rollout")
    }

    func testSilenceTrimDefaultIsFalse() {
        XCTAssertFalse(ExperimentFlags.enableSilenceTrim,
            "Silence trim must default to false (known adaptive noise-floor issue)")
    }

    // MARK: ToastState

    func testToastStateInitializesWithCurrentNil() {
        let toast = ToastState()
        XCTAssertNil(toast.current,
            "ToastState.current must be nil on init — no toast should appear at launch")
    }
}
