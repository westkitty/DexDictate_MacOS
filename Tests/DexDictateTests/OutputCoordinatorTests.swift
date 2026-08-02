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

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
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

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
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

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
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

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertEqual(activator.activatedApplications, [target])
        XCTAssertEqual(writer.lastPasteTargetApplication, target)
    }

    func testAccessibilityInsertionSuccessUsesAccessibilityPathWithoutClipboardPaste() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: false,
            setValueResult: .success,
            setSelectedTextResult: .failure
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


    func testAccessibilityModeFallsBackToClipboardPasteWhenTargetIsNotFrontmost() {
        let writer = MockOutputWriter()
        let target = OutputTargetApplication(bundleIdentifier: "com.example.chat", processIdentifier: 4242)
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: false,
            setValueResult: .success,
            setSelectedTextResult: .failure
        )
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(frontmostProcessIdentifier: 9001),
            axOperator: axOperator
        )

        let decision = coordinator.deliver(
            text: "hello",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .accessibilityAPI,
            targetApplication: target
        )

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertEqual(writer.pastedTexts, ["hello"])
        XCTAssertEqual(writer.lastPasteTargetApplication, target)
        XCTAssertFalse(axOperator.didAttemptSetValue)
    }

    func testAccessibilityInsertionFailureFallsBackToClipboardPasteWhenAutoPasteEnabled() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: true,
            setValueResult: .failure,
            setSelectedTextResult: .failure
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

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertEqual(writer.pastedTexts, ["hello"])
    }

    func testAccessibilityModeWithAutoPasteDisabledRemainsSavedOnly() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: true,
            setValueResult: .failure,
            setSelectedTextResult: .failure
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

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertTrue(writer.copiedTexts.isEmpty)
        XCTAssertEqual(writer.pastedTexts, ["not-secret"])
    }

    func testReplaceFieldModeRoutesToSelectAllAndPaste() {
        let writer = MockOutputWriter()
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator()
        )

        let decision = coordinator.deliver(
            text: "hello",
            autoPaste: true,
            protectSensitiveContexts: false,
            insertionMode: .replaceFieldWithClipboardPaste
        )

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertEqual(writer.selectAllAndPastedTexts, ["hello"])
        XCTAssertTrue(writer.pastedTexts.isEmpty)
        XCTAssertTrue(writer.copiedTexts.isEmpty)
    }

    func testReplaceFieldModeRespectsSensitiveContextProtection() {
        let writer = MockOutputWriter()
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(
                context: .sensitive(reason: "Detected likely secure input context (password).")
            ),
            applicationActivator: MockApplicationActivator()
        )

        let decision = coordinator.deliver(
            text: "hello",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .replaceFieldWithClipboardPaste
        )

        XCTAssertEqual(decision.delivery, .copiedOnly(reason: "Detected likely secure input context (password)."))
        XCTAssertEqual(writer.copiedTexts, ["hello"])
        XCTAssertTrue(writer.selectAllAndPastedTexts.isEmpty)
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
                setSelectedTextResult: .failure
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
        let replaceField = coordinator.deliver(
            text: "five",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .replaceFieldWithClipboardPaste
        )

        XCTAssertEqual(saveOnly.delivery, .savedOnly)
        XCTAssertEqual(clipboardOnly.delivery, .copiedOnly(reason: "Per-app clipboard-only mode"))
        XCTAssertEqual(clipboardPaste.delivery, .requestedButUnverified)
        XCTAssertEqual(accessibility.delivery, .pastedToActiveApp)
        XCTAssertEqual(replaceField.delivery, .requestedButUnverified)
        XCTAssertEqual(writer.copiedTexts, ["two"])
        XCTAssertEqual(writer.pastedTexts, ["three"])
        XCTAssertEqual(writer.selectAllAndPastedTexts, ["five"])
    }

    // MARK: - Auto-space after sentence-ending punctuation

    func testAutoSpaceInsertedWhenCursorImmediatelyFollowsPeriod() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: false,
            setValueResult: .success,
            setSelectedTextResult: .failure,
            existingValue: "First sentence.",
            selectedRange: NSRange(location: 15, length: 0)
        )
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(),
            axOperator: axOperator
        )

        let decision = coordinator.deliver(
            text: "Second sentence.",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .clipboardPaste
        )

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertEqual(writer.pastedTexts, [" Second sentence."])
    }

    func testAutoSpaceNotInsertedWhenSpaceAlreadyPresent() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: false,
            setValueResult: .success,
            setSelectedTextResult: .failure,
            existingValue: "First sentence. ",
            selectedRange: NSRange(location: 16, length: 0)
        )
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(),
            axOperator: axOperator
        )

        let decision = coordinator.deliver(
            text: "Second sentence.",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .clipboardPaste
        )

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertEqual(writer.pastedTexts, ["Second sentence."])
    }

    func testAutoSpaceNotInsertedWhenPrecedingCharacterIsNotSentenceEnding() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: false,
            setValueResult: .success,
            setSelectedTextResult: .failure,
            existingValue: "hello",
            selectedRange: NSRange(location: 5, length: 0)
        )
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(),
            axOperator: axOperator
        )

        let decision = coordinator.deliver(
            text: "world",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .clipboardPaste
        )

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertEqual(writer.pastedTexts, ["world"])
    }

    func testAutoSpaceNotInsertedAtStartOfField() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: false,
            setValueResult: .success,
            setSelectedTextResult: .failure,
            existingValue: "",
            selectedRange: NSRange(location: 0, length: 0)
        )
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(),
            axOperator: axOperator
        )

        let decision = coordinator.deliver(
            text: "New sentence.",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .clipboardPaste
        )

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertEqual(writer.pastedTexts, ["New sentence."])
    }

    func testAutoSpaceNotAppliedWhenReplacingEntireField() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: false,
            setValueResult: .success,
            setSelectedTextResult: .failure,
            existingValue: "First sentence.",
            selectedRange: NSRange(location: 15, length: 0)
        )
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(),
            axOperator: axOperator
        )

        let decision = coordinator.deliver(
            text: "Replacement.",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .replaceFieldWithClipboardPaste
        )

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertEqual(writer.selectAllAndPastedTexts, ["Replacement."])
    }

    func testAutoSpaceAppliedForDirectAccessibilityInsertion() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: false,
            setValueResult: .success,
            setSelectedTextResult: .failure,
            existingValue: "First sentence.",
            selectedRange: NSRange(location: 15, length: 0)
        )
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(),
            axOperator: axOperator
        )

        let decision = coordinator.deliver(
            text: "Second sentence.",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .accessibilityAPI
        )

        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertEqual(axOperator.lastSetValue, "First sentence. Second sentence.")
        XCTAssertTrue(writer.pastedTexts.isEmpty)
    }

    // MARK: - Sensitive-context check waits for activation to actually complete

    func testSensitiveContextCheckWaitsForActivationBeforeInspecting() {
        let writer = MockOutputWriter()
        let target = OutputTargetApplication(bundleIdentifier: "com.example.chat", processIdentifier: 4242)
        let activator = DelayedActivationMockActivator(initialFrontmostProcessIdentifier: 9001, readsUntilFrontmost: 3)
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: ActivationAwareContextInspector(activator: activator, target: target),
            applicationActivator: activator
        )

        let decision = coordinator.deliver(
            text: "secret",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .clipboardPaste,
            targetApplication: target
        )

        // If the sensitivity check ran immediately after activate() (the pre-fix behavior),
        // it would have read the stale frontmost app and returned .standard, auto-pasting
        // "secret" straight into what is actually a secure field in the target app.
        XCTAssertEqual(decision.delivery, .copiedOnly(reason: "Detected likely secure input context (password)."))
        XCTAssertEqual(writer.copiedTexts, ["secret"])
        XCTAssertTrue(writer.pastedTexts.isEmpty)
    }

    func testAutoSpaceSkippedWhenNoFocusedElementIsReadable() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: false,
            setValueResult: .success,
            setSelectedTextResult: .failure,
            hasFocusedElement: false
        )
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(),
            axOperator: axOperator
        )

        let decision = coordinator.deliver(
            text: "Second sentence.",
            autoPaste: true,
            protectSensitiveContexts: true,
            insertionMode: .clipboardPaste
        )

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertEqual(writer.pastedTexts, ["Second sentence."])
    }

    // MARK: - Undo context capture

    func testAccessibilityInsertionPopulatesUndoContextForExactRestore() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: false,
            setValueResult: .success,
            setSelectedTextResult: .failure,
            existingValue: "First sentence.",
            selectedRange: NSRange(location: 15, length: 0)
        )
        let target = OutputTargetApplication(bundleIdentifier: "com.example.chat", processIdentifier: 4242)
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(frontmostProcessIdentifier: 4242),
            axOperator: axOperator
        )

        let decision = coordinator.deliver(
            text: "Second sentence.",
            autoPaste: true,
            protectSensitiveContexts: false,
            insertionMode: .accessibilityAPI,
            targetApplication: target
        )

        // The auto-space rule prepends a space here (cursor sits right after "..."), so the
        // text this delivery actually inserted — and what undo needs to reverse — is
        // " Second sentence.", not the raw dictated "Second sentence.".
        XCTAssertEqual(decision.undoContext?.insertedText, " Second sentence.")
        XCTAssertEqual(decision.undoContext?.previousFieldValue, "First sentence.")
        XCTAssertEqual(decision.undoContext?.replacementRange, NSRange(location: 15, length: 0))
        XCTAssertEqual(decision.undoContext?.targetApplication, target)
    }

    func testClipboardPasteIsUnverifiedAndDoesNotPopulateUndoContext() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: false,
            selectedTextIsSettable: false,
            setValueResult: .failure,
            setSelectedTextResult: .failure,
            existingValue: "before",
            selectedRange: NSRange(location: 6, length: 0)
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
            protectSensitiveContexts: false,
            insertionMode: .clipboardPaste
        )

        XCTAssertEqual(writer.pastedTexts, ["hello"])
        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertNil(decision.undoContext)
    }

    func testReplaceFieldModeIsUnverifiedAndDoesNotPopulateUndoContext() {
        let writer = MockOutputWriter()
        let axOperator = MockAccessibilityElementOperator(
            valueIsSettable: true,
            selectedTextIsSettable: false,
            setValueResult: .success,
            setSelectedTextResult: .failure,
            existingValue: "old content",
            selectedRange: NSRange(location: 3, length: 0)
        )
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator(),
            axOperator: axOperator
        )

        let decision = coordinator.deliver(
            text: "replacement",
            autoPaste: true,
            protectSensitiveContexts: false,
            insertionMode: .replaceFieldWithClipboardPaste
        )

        XCTAssertEqual(writer.selectAllAndPastedTexts, ["replacement"])
        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertNil(decision.undoContext)
    }

    func testSavedOnlyAndCopiedOnlyDeliveriesCarryNoUndoContext() {
        let writer = MockOutputWriter()
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .sensitive(reason: "Detected likely secure input context (password).")),
            applicationActivator: MockApplicationActivator()
        )

        let savedOnly = coordinator.deliver(text: "hello", autoPaste: false, protectSensitiveContexts: true)
        let copiedOnly = coordinator.deliver(text: "secret", autoPaste: true, protectSensitiveContexts: true)

        XCTAssertNil(savedOnly.undoContext)
        XCTAssertNil(copiedOnly.undoContext)
    }

    func testScheduledPasteCompletionCanReportBlockedWithoutClaimingInsertion() {
        let writer = MockOutputWriter()
        writer.pasteCompletion = .blocked(reason: "Focus invalidated")
        let coordinator = OutputCoordinator(
            writer: writer,
            contextInspector: MockFocusedContextInspector(context: .standard),
            applicationActivator: MockApplicationActivator()
        )
        var completionDecision: OutputDeliveryDecision?

        let initialDecision = coordinator.deliver(
            text: "hello",
            autoPaste: true,
            protectSensitiveContexts: false,
            insertionMode: .clipboardPaste,
            targetApplication: nil,
            completion: { completionDecision = $0 }
        )

        XCTAssertEqual(initialDecision.delivery, .requestedButUnverified)
        XCTAssertNil(initialDecision.undoContext)
        XCTAssertEqual(completionDecision?.delivery, .blocked(reason: "Focus invalidated"))
        XCTAssertNil(completionDecision?.undoContext)
    }

    func testClipboardWriteFailureReportsFailed() {
        let writer = MockOutputWriter()
        writer.copySucceeds = false
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

        XCTAssertEqual(decision.delivery, .failed(reason: "Could not copy text to the clipboard."))
        XCTAssertNil(decision.undoContext)
    }
}

private final class MockOutputWriter: OutputWriting {
    var copiedTexts: [String] = []
    var pastedTexts: [String] = []
    var selectAllAndPastedTexts: [String] = []
    var lastPasteTargetApplication: OutputTargetApplication?
    var copySucceeds = true
    var pasteCompletion: OutputDelivery?

    @discardableResult
    func copy(_ text: String) -> Bool {
        copiedTexts.append(text)
        return copySucceeds
    }

    @discardableResult
    func copyAndPaste(
        _ text: String,
        targetApplication: OutputTargetApplication?,
        completion: @escaping (OutputDelivery) -> Void
    ) -> Bool {
        pastedTexts.append(text)
        lastPasteTargetApplication = targetApplication
        if let pasteCompletion { completion(pasteCompletion) }
        return true
    }

    @discardableResult
    func selectAllAndPaste(
        _ text: String,
        targetApplication: OutputTargetApplication?,
        completion: @escaping (OutputDelivery) -> Void
    ) -> Bool {
        selectAllAndPastedTexts.append(text)
        lastPasteTargetApplication = targetApplication
        if let pasteCompletion { completion(pasteCompletion) }
        return true
    }
}

private struct MockFocusedContextInspector: FocusedContextInspecting {
    let context: OutputTargetContext

    func inspectFocusedContext() -> OutputTargetContext {
        context
    }
}

private final class MockApplicationActivator: OutputApplicationActivating {
    // Deliberately does NOT update frontmostProcessIdentifier when activate() is called —
    // several tests rely on "activation was attempted but the target still isn't frontmost"
    // (e.g. testAccessibilityModeFallsBackToClipboardPasteWhenTargetIsNotFrontmost). This also
    // means those tests now pay OutputCoordinator's real bounded wait-for-activation timeout
    // (~150ms) when protectSensitiveContexts is on — correct behavior, just slower.
    let frontmostProcessIdentifier: pid_t?
    private(set) var activatedApplications: [OutputTargetApplication] = []

    init(frontmostProcessIdentifier: pid_t? = nil) {
        self.frontmostProcessIdentifier = frontmostProcessIdentifier
    }

    func activate(_ targetApplication: OutputTargetApplication) {
        activatedApplications.append(targetApplication)
    }
}

/// Simulates `NSRunningApplication.activate()` being genuinely asynchronous:
/// `frontmostProcessIdentifier` keeps reporting the pre-activation app for
/// `readsUntilFrontmost` reads after `activate()` is called, then reports the real target —
/// deterministically exercising `OutputCoordinator`'s wait-for-activation loop without
/// depending on wall-clock timing.
private final class DelayedActivationMockActivator: OutputApplicationActivating {
    private let initialFrontmostProcessIdentifier: pid_t?
    private var readsRemainingBeforeFrontmost: Int
    private var activatedTargetPID: pid_t?
    private(set) var activatedApplications: [OutputTargetApplication] = []

    init(initialFrontmostProcessIdentifier: pid_t?, readsUntilFrontmost: Int) {
        self.initialFrontmostProcessIdentifier = initialFrontmostProcessIdentifier
        self.readsRemainingBeforeFrontmost = readsUntilFrontmost
    }

    var frontmostProcessIdentifier: pid_t? {
        guard let activatedTargetPID else { return initialFrontmostProcessIdentifier }
        if readsRemainingBeforeFrontmost > 0 {
            readsRemainingBeforeFrontmost -= 1
            return initialFrontmostProcessIdentifier
        }
        return activatedTargetPID
    }

    func activate(_ targetApplication: OutputTargetApplication) {
        activatedApplications.append(targetApplication)
        activatedTargetPID = targetApplication.processIdentifier
    }
}

/// Reports `.sensitive` only once `activator` actually reports the target as frontmost —
/// i.e. only once activation has genuinely caught up — standing in for a real AX read of
/// the target application's focused element.
private final class ActivationAwareContextInspector: FocusedContextInspecting {
    private let activator: DelayedActivationMockActivator
    private let target: OutputTargetApplication

    init(activator: DelayedActivationMockActivator, target: OutputTargetApplication) {
        self.activator = activator
        self.target = target
    }

    func inspectFocusedContext() -> OutputTargetContext {
        activator.frontmostProcessIdentifier == target.processIdentifier
            ? .sensitive(reason: "Detected likely secure input context (password).")
            : .standard
    }
}

private final class MockAccessibilityElementOperator: AccessibilityElementOperating {
    private let valueIsSettable: Bool
    private let selectedTextIsSettable: Bool
    private let setValueResult: AXError
    private let setSelectedTextResult: AXError
    private let focused = AXUIElementCreateSystemWide()
    private var currentValue: String
    private var currentSelectedRange: NSRange
    /// When false, `focusedElement()` returns nil (simulates no readable AX element).
    private let hasFocusedElement: Bool

    private(set) var didAttemptSetValue = false
    private(set) var setCursorLocations: [Int] = []
    private(set) var lastSetValue: String?

    init(
        valueIsSettable: Bool,
        selectedTextIsSettable: Bool,
        setValueResult: AXError,
        setSelectedTextResult: AXError,
        existingValue: String = "existing",
        selectedRange: NSRange = NSRange(location: 0, length: 0),
        hasFocusedElement: Bool = true
    ) {
        self.valueIsSettable = valueIsSettable
        self.selectedTextIsSettable = selectedTextIsSettable
        self.setValueResult = setValueResult
        self.setSelectedTextResult = setSelectedTextResult
        currentValue = existingValue
        currentSelectedRange = selectedRange
        self.hasFocusedElement = hasFocusedElement
    }

    func focusedElement() -> AXUIElement? {
        hasFocusedElement ? focused : nil
    }

    func isSettable(_ attribute: CFString, element: AXUIElement) -> Bool {
        let key = attribute as String
        if key == kAXValueAttribute as String { return valueIsSettable }
        if key == kAXSelectedTextAttribute as String { return selectedTextIsSettable }
        return false
    }

    /// Answers only for `kAXValueAttribute`. Answering `currentValue` for every attribute made
    /// this fake report its own content as its `AXPlaceholderValue` — i.e. claim to be an empty
    /// field rendering a placeholder, which is a distinct state the output path now handles.
    /// A real element only reports a matching placeholder when it genuinely is one.
    func getString(_ attribute: CFString, element: AXUIElement) -> String? {
        (attribute as String) == (kAXValueAttribute as String) ? currentValue : nil
    }

    func getSelectedRange(element: AXUIElement) -> NSRange? {
        currentSelectedRange
    }

    func set(_ value: CFTypeRef, for attribute: CFString, element: AXUIElement) -> AXError {
        let key = attribute as String
        if key == kAXValueAttribute as String {
            didAttemptSetValue = true
            lastSetValue = value as? String
            if setValueResult == .success, let value = value as? String {
                currentValue = value
            }
            return setValueResult
        }
        if key == kAXSelectedTextAttribute as String {
            if setSelectedTextResult == .success,
               let text = value as? String,
               let updated = accessibilityReplacingText(
                   in: currentValue,
                   range: currentSelectedRange,
                   with: text
               ) {
                currentValue = updated
            }
            return setSelectedTextResult
        }
        return .failure
    }

    @discardableResult
    func setCursor(location: Int, element: AXUIElement) -> AXError {
        setCursorLocations.append(location)
        currentSelectedRange = NSRange(location: location, length: 0)
        return .success
    }
}
