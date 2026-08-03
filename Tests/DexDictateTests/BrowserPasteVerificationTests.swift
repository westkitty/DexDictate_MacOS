import ApplicationServices
import XCTest
@testable import DexDictateKit

/// A saved-element fake whose reported value can be changed between reads, so a paste landing
/// *after* dispatch can be modelled the way a browser actually behaves.
final class VerifiableFieldOperator: AccessibilityElementOperating {
    let savedElement = AXUIElementCreateSystemWide()
    /// A different element, used to prove undo never touches whatever is focused instead.
    let otherElement = AXUIElementCreateApplication(1)

    /// Raw `kAXValueAttribute` reading, mutable so a test can simulate the paste landing.
    var rawValue: String?
    var placeholderValue: String?
    var numberOfCharacters: Int?
    var selectedRange: NSRange? = NSRange(location: 0, length: 0)
    var valueIsSettable = true
    var isAlive = true
    /// What the field reports after being set to "" — a web composer paints its placeholder
    /// back into `AXValue`, which restoration verification has to tolerate for that case only.
    var valueAfterClearing: String?
    /// Returned by `focusedElement()`; deliberately *not* the saved element in the test that
    /// proves undo ignores current focus.
    var focused: AXUIElement?

    private(set) var setValues: [String] = []
    private(set) var mutatedElements: [AXUIElement] = []
    private(set) var activatedPIDs: [pid_t] = []

    init(rawValue: String?) {
        self.rawValue = rawValue
        self.focused = savedElement
    }

    func focusedElement() -> AXUIElement? { focused }
    func isSettable(_ attribute: CFString, element: AXUIElement) -> Bool {
        (attribute as String) == (kAXValueAttribute as String) ? valueIsSettable : false
    }
    func getString(_ attribute: CFString, element: AXUIElement) -> String? {
        switch attribute as String {
        case kAXValueAttribute as String: return rawValue
        case AccessibilityEditableTextSnapshot.placeholderAttribute: return placeholderValue
        case kAXRoleAttribute as String: return "AXTextArea"
        default: return nil
        }
    }
    func getNumberOfCharacters(element: AXUIElement) -> Int? { numberOfCharacters }
    func getSelectedRange(element: AXUIElement) -> NSRange? { selectedRange }
    func isElementAlive(_ element: AXUIElement) -> Bool { isAlive }
    func activateApplicationAccessibility(processIdentifier: pid_t) { activatedPIDs.append(processIdentifier) }

    func set(_ value: CFTypeRef, for attribute: CFString, element: AXUIElement) -> AXError {
        guard let string = value as? String else { return .failure }
        setValues.append(string)
        mutatedElements.append(element)
        rawValue = (string.isEmpty ? valueAfterClearing : nil) ?? string
        return .success
    }

    @discardableResult
    func setCursor(location: Int, element: AXUIElement) -> AXError {
        selectedRange = NSRange(location: location, length: 0)
        return .success
    }
}

/// Post-paste verification and the browser undo it enables.
///
/// `Ask ChatGPT` / `Ask Gemini` are fixtures only — production distinguishes editors by
/// Accessibility evidence, never by phrase.
final class BrowserPasteVerificationTests: XCTestCase {

    private let chatGPT = "Ask ChatGPT"
    private let gemini = "Ask Gemini"

    private func record(
        on ax: VerifiableFieldOperator,
        inserted: String,
        selection: NSRange = NSRange(location: 0, length: 0)
    ) -> PastePreDispatchRecord {
        let snapshot = ax.editableTextSnapshot(element: ax.savedElement)
        return PastePreDispatchRecord(
            element: ax.savedElement,
            targetApplication: OutputTargetApplication(bundleIdentifier: "com.example.browser", processIdentifier: 4242),
            role: snapshot.role,
            subrole: snapshot.subrole,
            rawValue: snapshot.rawValue,
            committedValue: snapshot.committedValue,
            emptiness: snapshot.emptiness,
            selectedRange: selection,
            insertedText: inserted
        )
    }

    // MARK: - Verification classification

    func testExactExpectedValueAfterPasteIsVerified() {
        let ax = VerifiableFieldOperator(rawValue: "Dear Bob, regards")
        ax.numberOfCharacters = 17
        let pre = record(on: ax, inserted: "thanks. ", selection: NSRange(location: 10, length: 0))

        ax.rawValue = "Dear Bob, thanks. regards"   // the paste lands
        let outcome = PastedInsertionVerifier(axOperator: ax).evaluate(pre)

        XCTAssertEqual(outcome, .verifiedKnownContent(
            postValue: "Dear Bob, thanks. regards", previousValue: "Dear Bob, regards",
            range: NSRange(location: 10, length: 0)
        ))
        XCTAssertTrue(outcome.isVerified)
    }

    /// A zero-length paste at offset 0 or at the very end yields `inserted + old` / `old +
    /// inserted` — exactly the shape a surviving placeholder produces. The two are
    /// indistinguishable, so neither is verified and undo is simply not offered.
    func testBoundaryInsertionsIntoRealContentStayUnverified() {
        for (selection, post) in [
            (NSRange(location: 0, length: 0), "new Dear Bob,"),
            (NSRange(location: 9, length: 0), "Dear Bob, new")
        ] {
            let ax = VerifiableFieldOperator(rawValue: "Dear Bob,")
            ax.numberOfCharacters = 9
            let pre = record(on: ax, inserted: selection.location == 0 ? "new " : " new", selection: selection)
            ax.rawValue = post

            XCTAssertEqual(
                PastedInsertionVerifier(axOperator: ax).evaluate(pre), .unexplainedChange,
                "Boundary insertion at \(selection) must not be verified"
            )
        }
    }

    func testUnchangedFieldIsNeverVerified() {
        let ax = VerifiableFieldOperator(rawValue: chatGPT)
        ax.numberOfCharacters = 11
        let pre = record(on: ax, inserted: "ChatGPT browser undo test.")

        XCTAssertEqual(PastedInsertionVerifier(axOperator: ax).evaluate(pre), .noChange)
    }

    func testPartialOrUnexplainedChangeIsNotVerified() {
        let ax = VerifiableFieldOperator(rawValue: "Dear Bob, regards")
        ax.numberOfCharacters = 17
        let pre = record(on: ax, inserted: "thanks. ", selection: NSRange(location: 10, length: 0))

        ax.rawValue = "Dear Bob, thanks. regards and something else"
        XCTAssertEqual(PastedInsertionVerifier(axOperator: ax).evaluate(pre), .unexplainedChange)
    }

    func testDeadElementIsReportedUnavailable() {
        let ax = VerifiableFieldOperator(rawValue: "x")
        let pre = record(on: ax, inserted: "y")
        ax.isAlive = false

        XCTAssertEqual(PastedInsertionVerifier(axOperator: ax).evaluate(pre), .targetUnavailable)
    }

    // MARK: - Placeholder-backed empty editors

    /// The ambiguity that cannot be resolved *before* a paste is resolved *after* it: the field
    /// now holds exactly the transcription, with no surviving prefix or suffix.
    func testAmbiguousEmptyComposerBecomesVerifiedLogicallyEmpty() {
        for selection in [NSRange(location: 0, length: 0),
                          NSRange(location: (chatGPT as NSString).length, length: 0)] {
            let ax = VerifiableFieldOperator(rawValue: chatGPT)
            ax.numberOfCharacters = 11
            let pre = record(on: ax, inserted: "ChatGPT browser undo test.", selection: selection)

            ax.rawValue = "ChatGPT browser undo test."
            let outcome = PastedInsertionVerifier(axOperator: ax).evaluate(pre)

            XCTAssertEqual(outcome, .verifiedLogicallyEmpty(
                postValue: "ChatGPT browser undo test.", presentationValue: chatGPT
            ), "Reported selection \(selection) must not change the verdict")
        }
    }

    func testPlaceholderSurvivingAsPrefixIsNotVerified() {
        let ax = VerifiableFieldOperator(rawValue: gemini)
        ax.numberOfCharacters = 10
        let pre = record(on: ax, inserted: "Gemini browser undo test.")

        ax.rawValue = gemini + "Gemini browser undo test."
        XCTAssertEqual(PastedInsertionVerifier(axOperator: ax).evaluate(pre), .unexplainedChange)
    }

    func testPlaceholderSurvivingAsSuffixIsNotVerified() {
        let ax = VerifiableFieldOperator(rawValue: chatGPT)
        ax.numberOfCharacters = 11
        let pre = record(on: ax, inserted: "ChatGPT browser undo test.")

        ax.rawValue = "ChatGPT browser undo test." + chatGPT
        XCTAssertEqual(PastedInsertionVerifier(axOperator: ax).evaluate(pre), .unexplainedChange)
    }

    /// Real user text that merely resembles a placeholder must be treated as content, because
    /// the post-paste evidence shows the original text still surrounding the insertion.
    func testGenuineContentResemblingAPlaceholderIsNotReclassified() {
        let ax = VerifiableFieldOperator(rawValue: chatGPT)
        ax.numberOfCharacters = 11
        let pre = record(on: ax, inserted: " really", selection: NSRange(location: 3, length: 0))

        ax.rawValue = "Ask really ChatGPT"
        let outcome = PastedInsertionVerifier(axOperator: ax).evaluate(pre)

        XCTAssertEqual(outcome, .verifiedKnownContent(
            postValue: "Ask really ChatGPT", previousValue: chatGPT, range: NSRange(location: 3, length: 0)
        ), "Real content around the insertion proves the old value was committed, not decoration")
    }

    // MARK: - Bounded retry

    func testVerificationRetriesAreBoundedAndStopOnceObserved() {
        let ax = VerifiableFieldOperator(rawValue: chatGPT)
        ax.numberOfCharacters = 11
        let pre = record(on: ax, inserted: "landed")

        var scheduled = 0
        var outcome: PasteVerificationOutcome?
        PastedInsertionVerifier(axOperator: ax).verify(
            pre,
            attempts: 5,
            interval: 0,
            schedule: { _, work in
                scheduled += 1
                if scheduled == 2 { ax.rawValue = "landed" }   // paste lands on the 3rd read
                work()
            },
            isStillCurrent: { true },
            completion: { outcome = $0 }
        )

        XCTAssertEqual(outcome, .verifiedLogicallyEmpty(postValue: "landed", presentationValue: chatGPT))
        XCTAssertEqual(scheduled, 2, "Stops as soon as the paste is observable")
    }

    func testVerificationGivesUpAfterTheBoundedNumberOfAttempts() {
        let ax = VerifiableFieldOperator(rawValue: chatGPT)
        let pre = record(on: ax, inserted: "never lands")

        var scheduled = 0
        var outcome: PasteVerificationOutcome?
        PastedInsertionVerifier(axOperator: ax).verify(
            pre, attempts: 4, interval: 0,
            schedule: { _, work in scheduled += 1; work() },
            isStillCurrent: { true },
            completion: { outcome = $0 }
        )

        XCTAssertEqual(outcome, .noChange)
        XCTAssertEqual(scheduled, 3, "4 attempts means 3 reschedules, then it stops")
    }

    func testSupersededVerificationNeverReportsAndCannotArmUndo() {
        let ax = VerifiableFieldOperator(rawValue: chatGPT)
        let pre = record(on: ax, inserted: "stale")
        ax.rawValue = "stale"

        var completions = 0
        PastedInsertionVerifier(axOperator: ax).verify(
            pre, attempts: 3, interval: 0,
            schedule: { _, work in work() },
            isStillCurrent: { false },
            completion: { _ in completions += 1 }
        )

        XCTAssertEqual(completions, 0, "A superseded delivery must not produce an undo-arming decision")
    }

    // MARK: - Decisions built from outcomes

    func testVerifiedLogicallyEmptyProducesAnEmptyRestorationUndoContext() {
        let ax = VerifiableFieldOperator(rawValue: chatGPT)
        let pre = record(on: ax, inserted: "ChatGPT browser undo test.")
        let decision = OutputCoordinator.decision(
            for: .verifiedLogicallyEmpty(postValue: "ChatGPT browser undo test.", presentationValue: chatGPT),
            record: pre
        )

        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertEqual(decision.undoContext?.previousFieldValue, "")
        XCTAssertEqual(decision.undoContext?.restoration, .logicallyEmptyEditor(presentationValue: chatGPT))
        XCTAssertEqual(decision.undoContext?.verifiedPostDeliveryValue, "ChatGPT browser undo test.")
    }

    func testUnverifiedOutcomesNeverProduceAnUndoContext() {
        let ax = VerifiableFieldOperator(rawValue: chatGPT)
        let pre = record(on: ax, inserted: "x")
        for outcome in [PasteVerificationOutcome.unexplainedChange, .targetUnavailable] {
            XCTAssertNil(OutputCoordinator.decision(for: outcome, record: pre).undoContext)
        }
        let noChange = OutputCoordinator.decision(for: .noChange, record: pre)
        XCTAssertNil(noChange.undoContext)
        XCTAssertNotEqual(noChange.delivery, .pastedToActiveApp, "A paste that never landed is not an insertion")
    }

    // MARK: - Browser undo execution

    private func armedManager(
        ax: VerifiableFieldOperator,
        context: DictationUndoContext
    ) -> DictationUndoManager {
        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(DictationUndoRecord(focusSnapshot: nil, context: context, timestamp: Date(timeIntervalSince1970: 0)))
        return manager
    }

    private func emptyEditorContext(
        ax: VerifiableFieldOperator, inserted: String, presentation: String?
    ) -> DictationUndoContext {
        DictationUndoContext(
            insertedText: inserted,
            previousFieldValue: "",
            replacementRange: NSRange(location: 0, length: 0),
            targetApplication: nil,
            targetElement: ax.savedElement,
            restoration: .logicallyEmptyEditor(presentationValue: presentation),
            verifiedPostDeliveryValue: inserted
        )
    }

    func testBrowserUndoRestoresAVerifiedEmptyEditorToEmpty() {
        let ax = VerifiableFieldOperator(rawValue: "ChatGPT browser undo test.")
        ax.valueAfterClearing = chatGPT   // the host paints its placeholder back
        let manager = armedManager(
            ax: ax,
            context: emptyEditorContext(ax: ax, inserted: "ChatGPT browser undo test.", presentation: chatGPT)
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .popoverButton), .undone)
        XCTAssertEqual(ax.setValues, [""], "Undo writes emptiness, never the placeholder string")
        XCTAssertFalse(ax.setValues.contains(chatGPT))
    }

    func testBrowserUndoRestoresKnownPreviousContent() {
        let ax = VerifiableFieldOperator(rawValue: "Dear Bob, thanks.")
        let context = DictationUndoContext(
            insertedText: " thanks.",
            previousFieldValue: "Dear Bob,",
            replacementRange: NSRange(location: 9, length: 0),
            targetApplication: nil,
            targetElement: ax.savedElement,
            restoration: .knownPreviousValue,
            verifiedPostDeliveryValue: "Dear Bob, thanks."
        )
        let manager = armedManager(ax: ax, context: context)

        XCTAssertEqual(manager.undoLastDictation(invocation: .popoverButton), .undone)
        XCTAssertEqual(ax.setValues.last, "Dear Bob,")
    }

    func testEditedBrowserContentIsRefusedWithoutMutation() {
        let ax = VerifiableFieldOperator(rawValue: "ChatGPT browser undo test. plus my own edit")
        let manager = armedManager(
            ax: ax,
            context: emptyEditorContext(ax: ax, inserted: "ChatGPT browser undo test.", presentation: chatGPT)
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .popoverButton), .contentChanged)
        XCTAssertTrue(ax.setValues.isEmpty, "Nothing may be written once the user has edited the field")
        XCTAssertEqual(ax.rawValue, "ChatGPT browser undo test. plus my own edit")
    }

    func testUndoOperatesOnTheSavedElementNotCurrentFocus() {
        let ax = VerifiableFieldOperator(rawValue: "ChatGPT browser undo test.")
        ax.valueAfterClearing = chatGPT
        ax.focused = ax.otherElement    // an unrelated field is focused now
        let manager = armedManager(
            ax: ax,
            context: emptyEditorContext(ax: ax, inserted: "ChatGPT browser undo test.", presentation: chatGPT)
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .popoverButton), .undone)
        for mutated in ax.mutatedElements {
            XCTAssertTrue(CFEqual(mutated, ax.savedElement), "Only the saved element may be mutated")
        }
    }

    func testDeadTargetIsRefusedSafely() {
        let ax = VerifiableFieldOperator(rawValue: "ChatGPT browser undo test.")
        let manager = armedManager(
            ax: ax,
            context: emptyEditorContext(ax: ax, inserted: "ChatGPT browser undo test.", presentation: chatGPT)
        )
        ax.isAlive = false

        XCTAssertEqual(manager.undoLastDictation(invocation: .popoverButton), .targetUnavailable)
        XCTAssertTrue(ax.setValues.isEmpty)
    }

    func testSuccessfulBrowserUndoConsumesTheRecordOnce() {
        let ax = VerifiableFieldOperator(rawValue: "ChatGPT browser undo test.")
        ax.valueAfterClearing = chatGPT
        let manager = armedManager(
            ax: ax,
            context: emptyEditorContext(ax: ax, inserted: "ChatGPT browser undo test.", presentation: chatGPT)
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .popoverButton), .undone)
        XCTAssertEqual(manager.undoLastDictation(invocation: .popoverButton), .nothingToUndo)
        XCTAssertFalse(manager.availability.canUndo)
    }

    func testBothInvocationsUseTheSameBrowserUndoLifecycle() {
        for invocation in [DictationUndoInvocation.popoverButton, .globalShortcut] {
            let ax = VerifiableFieldOperator(rawValue: "ChatGPT browser undo test.")
            ax.valueAfterClearing = chatGPT
            let manager = armedManager(
                ax: ax,
                context: emptyEditorContext(ax: ax, inserted: "ChatGPT browser undo test.", presentation: chatGPT)
            )
            // `.globalShortcut` additionally requires the saved element to still hold focus,
            // which it does here — both routes then run the identical restoration.
            XCTAssertEqual(manager.undoLastDictation(invocation: invocation), .undone, "\(invocation)")
            XCTAssertEqual(ax.setValues, [""])
        }
    }

    func testEmptyRestorationAcceptanceDoesNotApplyToOrdinaryFields() {
        // Same host behaviour (value reads back as the old string) but a known-previous-value
        // record: restoration must be judged by exact equality, not the placeholder allowance.
        let ax = VerifiableFieldOperator(rawValue: "Dear Bob, thanks.")
        ax.valueAfterClearing = "something else"
        let context = DictationUndoContext(
            insertedText: " thanks.",
            previousFieldValue: "Dear Bob,",
            replacementRange: NSRange(location: 9, length: 0),
            targetApplication: nil,
            targetElement: ax.savedElement,
            restoration: .knownPreviousValue,
            verifiedPostDeliveryValue: "Dear Bob, thanks."
        )
        let manager = armedManager(ax: ax, context: context)

        XCTAssertEqual(manager.undoLastDictation(invocation: .popoverButton), .undone)
        XCTAssertEqual(ax.rawValue, "Dear Bob,", "Exact restoration, verified exactly")
    }

    // MARK: - Chromium accessibility activation

    func testDeliveryAsksTheTargetApplicationToEnableAccessibility() {
        let ax = VerifiableFieldOperator(rawValue: "content")
        ax.numberOfCharacters = 7
        let writer = RecordingOutputWriter()
        let target = OutputTargetApplication(bundleIdentifier: "com.example.browser", processIdentifier: 4242)

        _ = OutputCoordinator(writer: writer, axOperator: ax).deliver(
            text: "hello",
            autoPaste: true,
            protectSensitiveContexts: false,
            insertionMode: .accessibilityAPI,
            targetApplication: target
        )

        XCTAssertTrue(
            ax.activatedPIDs.contains(4242),
            "Chromium keeps its AX tree off until asked; without this there is no element to verify against"
        )
    }

    // MARK: - Auto-paste off

    func testAutoPasteOffTouchesNothingAtAll() {
        let ax = VerifiableFieldOperator(rawValue: "user content")
        let writer = RecordingOutputWriter()

        let decision = OutputCoordinator(writer: writer, axOperator: ax).deliver(
            text: "not delivered",
            autoPaste: false,
            protectSensitiveContexts: false,
            insertionMode: .accessibilityAPI
        )

        XCTAssertEqual(decision.delivery, .savedOnly)
        XCTAssertEqual(writer.copiedTexts, [], "The clipboard must be left exactly as the user had it")
        XCTAssertEqual(writer.pastedTexts, [])
        XCTAssertTrue(ax.setValues.isEmpty, "No Accessibility write")
        XCTAssertEqual(ax.rawValue, "user content")
        XCTAssertNil(decision.undoContext, "Nothing was delivered, so nothing is reversible")
    }

    func testPendingVerificationReasonIsTransientAndReadable() {
        let model = UndoControlModel(availability: .unavailable(.verificationPending))
        XCTAssertTrue(model.isVisible)
        XCTAssertFalse(model.isEnabled)
        XCTAssertEqual(model.title, "Undo Last Dictation")
        XCTAssertTrue(model.statusLine.contains("checking whether the paste"))
        XCTAssertFalse(model.helpText.isEmpty)
    }
}
