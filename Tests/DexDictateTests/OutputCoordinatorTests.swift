import XCTest
@testable import DexDictateKit

final class OutputCoordinatorTests: XCTestCase {
    func testDefaultPasteDeliveryProfileWaitsBrieflyForStandardApps() {
        let profile = PasteDeliveryProfile.resolve(for: nil)

        XCTAssertEqual(profile.initialDelay, 0.12)
        XCTAssertEqual(profile.activationTimeout, 0.20)
        XCTAssertEqual(profile.activationPollInterval, 0.02)
        XCTAssertTrue(profile.postsToTargetProcess)
    }

    func testZoomPasteDeliveryProfileAllowsExtraActivationTime() {
        let target = OutputTargetApplication(bundleIdentifier: "us.zoom.xos", processIdentifier: 99)

        let profile = PasteDeliveryProfile.resolve(for: target)

        XCTAssertEqual(profile.initialDelay, 0.22)
        XCTAssertEqual(profile.activationTimeout, 0.45)
        XCTAssertEqual(profile.activationPollInterval, 0.02)
        XCTAssertTrue(profile.postsToTargetProcess)
    }

    func testSavedOnlyWhenAutoPasteDisabled() {
        let writer = MockOutputWriter()
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard)
        )

        let decision = coordinator.deliver(text: "hello", autoPaste: false, protectSensitiveContexts: true)

        XCTAssertEqual(decision.delivery, .savedOnly)
        XCTAssertEqual(writer.copiedTexts, [])
        XCTAssertEqual(writer.pastedTexts, [])
    }

    func testSensitiveContextFallsBackToCopyOnly() {
        let writer = MockOutputWriter()
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .sensitive(reason: "Detected likely secure input context (password)."))
        )

        let decision = coordinator.deliver(text: "secret", autoPaste: true, protectSensitiveContexts: true)

        XCTAssertEqual(decision.delivery, .copiedOnly(reason: "Detected likely secure input context (password)."))
        XCTAssertEqual(writer.copiedTexts, ["secret"])
        XCTAssertEqual(writer.pastedTexts, [])
    }

    func testStandardContextStillPastes() {
        let writer = MockOutputWriter()
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard)
        )

        let decision = coordinator.deliver(text: "hello", autoPaste: true, protectSensitiveContexts: true)

        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertEqual(writer.copiedTexts, [])
        XCTAssertEqual(writer.pastedTexts, ["hello"])
    }

    func testSecureHeuristicFlagsLikelyPasswordFields() {
        let snapshot = FocusedElementSnapshot(
            role: "AXTextField",
            subrole: "AXSecureTextField",
            title: nil,
            placeholder: "Password",
            label: nil,
            identifier: nil
        )

        XCTAssertEqual(
            SensitiveContextHeuristic.classify(snapshot),
            .sensitive(reason: "Detected likely secure input context (secure).")
        )
    }

    func testClipboardOnlyModeCopiesWithoutPasting() {
        let writer = MockOutputWriter()
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard)
        )

        let decision = coordinator.deliver(
            text: "hello",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .clipboardOnly
        )

        XCTAssertEqual(decision.delivery, .copiedOnly(reason: "Per-app clipboard-only mode"))
        XCTAssertEqual(writer.copiedTexts, ["hello"])
        XCTAssertEqual(writer.pastedTexts, [])
    }

    func testTargetApplicationIsPassedToPasteWriter() {
        let writer = MockOutputWriter()
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard)
        )
        let target = OutputTargetApplication(bundleIdentifier: "com.example.chat", processIdentifier: 4242)

        let decision = coordinator.deliver(
            text: "hello",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .clipboardPaste,
            targetApplication: target
        )

        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertEqual(writer.lastPasteTargetApplication, target)
    }
}

private final class MockOutputWriter: OutputWriting {
    var copiedTexts: [String] = []
    var pastedTexts: [String] = []
    var lastPasteTargetApplication: OutputTargetApplication?

    func copy(_ text: String) {
        copiedTexts.append(text)
    }

    func copyAndPaste(_ text: String, targetApplication: OutputTargetApplication?) {
        pastedTexts.append(text)
        lastPasteTargetApplication = targetApplication
    }
}

private struct MockFocusedContextInspector: FocusedContextInspecting {
    let context: OutputTargetContext

    func inspectFocusedContext() -> OutputTargetContext {
        context
    }
}
