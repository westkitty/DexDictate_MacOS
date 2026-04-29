import XCTest
@testable import DexDictateKit

final class OutputCoordinatorTests: XCTestCase {
    func testSavedOnlyWhenAutoPasteDisabled() {
        let writer = MockOutputWriter()
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator()
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
            contextInspector: MockFocusedContextInspector(context: .sensitive(reason: "Detected likely secure input context (password).")),
            applicationActivator: MockApplicationActivator()
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
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator()
        )

        let decision = coordinator.deliver(text: "hello", autoPaste: true, protectSensitiveContexts: true)

        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertEqual(writer.copiedTexts, [])
        XCTAssertEqual(writer.pastedTexts, ["hello"])
    }

    func testAccessibilityModeStillRespectsSensitiveContextProtection() {
        let writer = MockOutputWriter()
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .sensitive(reason: "Detected likely secure input context (password).")),
            applicationActivator: MockApplicationActivator()
        )

        let decision = coordinator.deliver(
            text: "secret",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .accessibilityAPI
        )

        XCTAssertEqual(decision.delivery, .copiedOnly(reason: "Detected likely secure input context (password)."))
        XCTAssertEqual(writer.copiedTexts, ["secret"])
        XCTAssertEqual(writer.pastedTexts, [])
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
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator()
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
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator()
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

    func testAlreadyFrontmostTargetDoesNotActivateAgain() {
        let writer = MockOutputWriter()
        let activator = MockApplicationActivator(frontmostProcessIdentifier: 4242)
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: activator
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
        XCTAssertTrue(activator.activatedApplications.isEmpty)
    }

    func testBackgroundTargetActivatesOnceBeforePaste() {
        let writer = MockOutputWriter()
        let activator = MockApplicationActivator(frontmostProcessIdentifier: 9001)
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: activator
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
        XCTAssertEqual(activator.activatedApplications, [target])
        XCTAssertEqual(writer.lastPasteTargetApplication, target)
    }

    func testAccessibilityInsertionSuccessUsesAccessibilityPathWithoutClipboardPaste() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: false,
            setValueResult: .success,
            setSelectedTextResult: .failure,
            appendResult: .failure
        )
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(),
            axOperator: axOperator
        )

        let decision = coordinator.deliver(
            text: "hello",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .accessibilityAPI
        )

        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertTrue(writer.copiedTexts.isEmpty)
        XCTAssertTrue(writer.pastedTexts.isEmpty)
        XCTAssertTrue(axOperator.didAttemptSetValue)
    }

    func testAccessibilityInsertionFailureFallsBackToClipboardPasteWhenAutoPasteEnabled() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: true,
            setValueResult: .failure,
            setSelectedTextResult: .failure,
            appendResult: .failure
        )
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(),
            axOperator: axOperator
        )

        let decision = coordinator.deliver(
            text: "hello",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .accessibilityAPI
        )

        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertEqual(writer.pastedTexts, ["hello"])
    }

    func testAccessibilityModeWithAutoPasteDisabledRemainsSavedOnly() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: true,
            setValueResult: .failure,
            setSelectedTextResult: .failure,
            appendResult: .failure
        )
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(),
            axOperator: axOperator
        )

        let decision = coordinator.deliver(
            text: "hello",
            autoPaste: false,
            protectSensitiveContexts: true,
            insertionMode: .accessibilityAPI
        )

        XCTAssertEqual(decision.delivery, .savedOnly)
        XCTAssertTrue(writer.copiedTexts.isEmpty)
        XCTAssertTrue(writer.pastedTexts.isEmpty)
        XCTAssertFalse(axOperator.didAttemptSetValue)
    }

    func testSensitiveContextDoesNotForceCopyOnlyWhenProtectionDisabled() {
        let writer = MockOutputWriter()
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .sensitive(reason: "Detected likely secure input context (password).")),
            applicationActivator: MockApplicationActivator()
        )

        let decision = coordinator.deliver(
            text: "not-secret",
            autoPaste: true,
            protectSensitiveContexts: false
        )

        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertTrue(writer.copiedTexts.isEmpty)
        XCTAssertEqual(writer.pastedTexts, ["not-secret"])
    }

    func testInsertionModesStayBehaviorallyDistinct() {
        let writer = MockOutputWriter()
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(),
            axOperator: MockAccessibilityElementOperator(
                valueIsSettable: true,
                selectedTextIsSettable: false,
                setValueResult: .success,
                setSelectedTextResult: .failure,
                appendResult: .failure
            )
        )

        let saveOnly = coordinator.deliver(
            text: "one",
            autoPaste: false,
            protectSensitiveContexts: true,
            insertionMode: .clipboardPaste
        )
        let clipboardOnly = coordinator.deliver(
            text: "two",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .clipboardOnly
        )
        let clipboardPaste = coordinator.deliver(
            text: "three",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .clipboardPaste
        )
        let accessibility = coordinator.deliver(
            text: "four",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .accessibilityAPI
        )

        XCTAssertEqual(saveOnly.delivery, .savedOnly)
        XCTAssertEqual(clipboardOnly.delivery, .copiedOnly(reason: "Per-app clipboard-only mode"))
        XCTAssertEqual(clipboardPaste.delivery, .pastedToActiveApp)
        XCTAssertEqual(accessibility.delivery, .pastedToActiveApp)
        XCTAssertEqual(writer.copiedTexts, ["two"])
        XCTAssertEqual(writer.pastedTexts, ["three"])
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

private final class MockApplicationActivator: OutputApplicationActivating {
    let frontmostProcessIdentifier: pid_t?
    private(set) var activatedApplications: [OutputTargetApplication] = []

    init(frontmostProcessIdentifier: pid_t? = nil) {
        self.frontmostProcessIdentifier = frontmostProcessIdentifier
    }

    func activate(_ targetApplication: OutputTargetApplication) {
        activatedApplications.append(targetApplication)
    }
}

private final class MockAccessibilityElementOperator: AccessibilityElementOperating {
    private let valueIsSettable: Bool
    private let selectedTextIsSettable: Bool
    private let setValueResult: AXError
    private let setSelectedTextResult: AXError
    private let appendResult: AXError
    private let focused = AXUIElementCreateSystemWide()
    private let selectedRange = NSRange(location: 0, length: 0)

    private(set) var didAttemptSetValue = false

    init(
        valueIsSettable: Bool,
        selectedTextIsSettable: Bool,
        setValueResult: AXError,
        setSelectedTextResult: AXError,
        appendResult: AXError
    ) {
        self.valueIsSettable = valueIsSettable
        self.selectedTextIsSettable = selectedTextIsSettable
        self.setValueResult = setValueResult
        self.setSelectedTextResult = setSelectedTextResult
        self.appendResult = appendResult
    }

    func focusedElement() -> AXUIElement? {
        focused
    }

    func isSettable(_ attribute: CFString, element: AXUIElement) -> Bool {
        let key = attribute as String
        if key == kAXValueAttribute as String {
            return valueIsSettable
        }
        if key == kAXSelectedTextAttribute as String {
            return selectedTextIsSettable
        }
        return false
    }

    func getString(_ attribute: CFString, element: AXUIElement) -> String? {
        "existing"
    }

    func getSelectedRange(element: AXUIElement) -> NSRange? {
        selectedRange
    }

    func set(_ value: CFTypeRef, for attribute: CFString, element: AXUIElement) -> AXError {
        let key = attribute as String
        if key == kAXValueAttribute as String {
            didAttemptSetValue = true
            if let string = value as? String, string.hasPrefix("existing") {
                return appendResult
            }
            return setValueResult
        }
        if key == kAXSelectedTextAttribute as String {
            return setSelectedTextResult
        }
        return .failure
    }

    func setCursor(location: Int, element: AXUIElement) {}
}
