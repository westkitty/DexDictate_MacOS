import XCTest
@testable import DexDictateKit

final class OutputCoordinatorTests: XCTestCase {
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
}

private final class MockOutputWriter: OutputWriting {
    var copiedTexts: [String] = []
    var pastedTexts: [String] = []

    func copy(_ text: String) {
        copiedTexts.append(text)
    }

    func copyAndPaste(_ text: String) {
        pastedTexts.append(text)
    }
}

private struct MockFocusedContextInspector: FocusedContextInspecting {
    let context: OutputTargetContext

    func inspectFocusedContext() -> OutputTargetContext {
        context
    }
}
