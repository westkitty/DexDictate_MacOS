import ApplicationServices
import XCTest
@testable import DexDictateKit

/// Selection replacement through the real coordinator and undo manager, plus the Auto-paste
/// setting's effect on delivery.
///
/// `Ask ChatGPT` / `Ask Gemini` are fixtures only.
final class SelectionReplacementAndAutoPasteTests: XCTestCase {

    private let chatGPT = "Ask ChatGPT"
    private let gemini = "Ask Gemini"

    // MARK: - Auto-paste toggling

    func testAutoPasteOffInsertsNothingAndLeavesTheClipboardAlone() {
        let ax = VerifiableFieldOperator(rawValue: "The red fox")
        ax.numberOfCharacters = 11
        let writer = RecordingOutputWriter()

        let decision = OutputCoordinator(writer: writer, axOperator: ax).deliver(
            text: "blue", autoPaste: false, protectSensitiveContexts: false, insertionMode: .accessibilityAPI
        )

        XCTAssertEqual(decision.delivery, .savedOnly)
        XCTAssertEqual(ax.rawValue, "The red fox", "The field must not be touched")
        XCTAssertEqual(writer.copiedTexts, [], "The clipboard must be left exactly as the user had it")
        XCTAssertEqual(writer.pastedTexts, [])
        XCTAssertNil(decision.undoContext)
    }

    /// Flipping the setting back on must make the very next delivery insert normally — the
    /// coordinator reads the flag per call, so there is no stale state to clear.
    func testTurningAutoPasteBackOnRestoresInsertionOnTheNextDelivery() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXSelectedTextAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "The red fox"]
        ax.selectedRangeResult = NSRange(location: 4, length: 3)
        ax.setResults = [kAXSelectedTextAttribute as String: .success]
        let writer = RecordingOutputWriter()
        let coordinator = OutputCoordinator(writer: writer, axOperator: ax)

        let off = coordinator.deliver(text: "blue", autoPaste: false, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)
        XCTAssertEqual(off.delivery, .savedOnly)
        XCTAssertEqual(ax.stringMap[kAXValueAttribute as String], "The red fox", "Nothing inserted while off")
        XCTAssertTrue(ax.setCallLog.isEmpty)
        XCTAssertTrue(writer.copiedTexts.isEmpty)

        let on = coordinator.deliver(text: "blue", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI)

        XCTAssertEqual(ax.stringMap[kAXValueAttribute as String], "The blue fox", "The next dictation inserts normally")
        XCTAssertEqual(on.delivery, .pastedToActiveApp)
    }

    func testAutoPasteSettingIsTheAuthoritativeValueTheCoordinatorReads() {
        // The chip writes `AppSettings.autoPaste`; delivery reads the same property. This pins
        // the round-trip so a toggle cannot silently fail to persist.
        let settings = AppSettings.shared
        let original = settings.autoPaste
        defer { settings.autoPaste = original }

        settings.autoPaste = false
        XCTAssertFalse(AppSettings.shared.autoPaste)
        settings.autoPaste = true
        XCTAssertTrue(AppSettings.shared.autoPaste)
    }

    // MARK: - Selection replacement: native / direct Accessibility

    func testSelectedTextIsReplacedInANativeField() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXSelectedTextAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "The red fox"]
        ax.selectedRangeResult = NSRange(location: 4, length: 3)
        ax.setResults = [kAXSelectedTextAttribute as String: .success]

        let decision = OutputCoordinator(axOperator: ax).deliver(
            text: "blue", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI
        )

        XCTAssertEqual(ax.stringMap[kAXValueAttribute as String], "The blue fox")
        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertEqual(decision.undoContext?.previousFieldValue, "The red fox")
        XCTAssertEqual(decision.undoContext?.replacementRange, NSRange(location: 4, length: 3))
        XCTAssertEqual(decision.undoContext?.insertedText, "blue")
    }

    func testUndoRestoresTheReplacedSelectionInANativeField() {
        let ax = VerifiableFieldOperator(rawValue: "The blue fox")
        let context = DictationUndoContext(
            insertedText: "blue",
            previousFieldValue: "The red fox",
            replacementRange: NSRange(location: 4, length: 3),
            targetApplication: nil,
            targetElement: ax.savedElement
        )
        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(DictationUndoRecord(focusSnapshot: nil, context: context, timestamp: Date(timeIntervalSince1970: 0)))

        XCTAssertEqual(manager.undoLastDictation(invocation: .popoverButton), .undone)
        XCTAssertEqual(ax.rawValue, "The red fox")
    }

    func testSelectionReplacementPreservesUTF16Ranges() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXSelectedTextAttribute as String: true]
        // "👍" is two UTF-16 units, so "red" sits at {3, 3} in UTF-16 coordinates.
        ax.stringMap = [kAXValueAttribute as String: "👍 red fox"]
        ax.selectedRangeResult = NSRange(location: 3, length: 3)
        ax.setResults = [kAXSelectedTextAttribute as String: .success]

        let decision = OutputCoordinator(axOperator: ax).deliver(
            text: "blue", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI
        )

        XCTAssertEqual(ax.stringMap[kAXValueAttribute as String], "👍 blue fox")
        XCTAssertEqual(decision.undoContext?.replacementRange, NSRange(location: 3, length: 3))
    }

    // MARK: - Selection replacement: browser clipboard paste

    /// The regression this fixes. Chromium accepts the selected-text write, reports success and
    /// changes nothing; moving the caret afterwards *collapsed the user's selection*, so the
    /// clipboard fallback's Cmd-V inserted at a caret instead of replacing what was selected.
    /// Measured in production as `outcome=noOp` followed by `unexplainedChange` on every
    /// selection paste.
    func testNoOpAccessibilityWriteLeavesTheSelectionIntactForTheFallback() {
        let ax = PlaceholderComposerOperator(
            placeholder: chatGPT,
            realContent: "The red fox",
            reportedSelection: NSRange(location: 4, length: 3)
        )
        ax.noOpsSelectedTextWrites = true
        let writer = RecordingOutputWriter()

        _ = OutputCoordinator(writer: writer, axOperator: ax).deliver(
            text: "blue", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI
        )

        XCTAssertTrue(
            ax.cursorWrites.isEmpty,
            "A write that changed nothing must not move the caret — that is what destroyed the selection"
        )
        XCTAssertEqual(writer.pastedTexts, ["blue"], "The fallback carries only the transcription")
    }

    func testBrowserSelectionReplacementVerifiesAndArmsUndo() {
        let ax = VerifiableFieldOperator(rawValue: "The red fox")
        ax.numberOfCharacters = 11
        ax.selectedRange = NSRange(location: 4, length: 3)
        let pre = PastePreDispatchRecord(
            element: ax.savedElement,
            targetApplication: OutputTargetApplication(bundleIdentifier: "com.example.browser", processIdentifier: 42),
            role: "AXTextArea",
            subrole: nil,
            rawValue: "The red fox",
            committedValue: "The red fox",
            emptiness: .confirmedContent,
            selectedRange: NSRange(location: 4, length: 3),
            insertedText: "blue"
        )

        ax.rawValue = "The blue fox"   // Cmd-V replaced the selection natively
        let outcome = PastedInsertionVerifier(axOperator: ax).evaluate(pre)

        XCTAssertEqual(outcome, .verifiedKnownContent(
            postValue: "The blue fox", previousValue: "The red fox", range: NSRange(location: 4, length: 3)
        ))

        let decision = OutputCoordinator.decision(for: outcome, record: pre)
        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertEqual(decision.undoContext?.previousFieldValue, "The red fox")
        XCTAssertEqual(decision.undoContext?.verifiedPostDeliveryValue, "The blue fox")
    }

    func testUndoRestoresAReplacedSelectionAfterABrowserPaste() {
        let ax = VerifiableFieldOperator(rawValue: "The blue fox")
        let context = DictationUndoContext(
            insertedText: "blue",
            previousFieldValue: "The red fox",
            replacementRange: NSRange(location: 4, length: 3),
            targetApplication: nil,
            targetElement: ax.savedElement,
            restoration: .knownPreviousValue,
            verifiedPostDeliveryValue: "The blue fox"
        )
        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(DictationUndoRecord(focusSnapshot: nil, context: context, timestamp: Date(timeIntervalSince1970: 0)))

        XCTAssertEqual(manager.undoLastDictation(invocation: .popoverButton), .undone)
        XCTAssertEqual(ax.rawValue, "The red fox")
        XCTAssertFalse(ax.setValues.contains("The blue fox"))
    }

    func testManualEditAfterASelectionReplacementIsRefusedWithoutMutating() {
        let ax = VerifiableFieldOperator(rawValue: "The blue fox jumped")   // user kept typing
        let context = DictationUndoContext(
            insertedText: "blue",
            previousFieldValue: "The red fox",
            replacementRange: NSRange(location: 4, length: 3),
            targetApplication: nil,
            targetElement: ax.savedElement,
            restoration: .knownPreviousValue,
            verifiedPostDeliveryValue: "The blue fox"
        )
        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(DictationUndoRecord(focusSnapshot: nil, context: context, timestamp: Date(timeIntervalSince1970: 0)))

        XCTAssertEqual(manager.undoLastDictation(invocation: .popoverButton), .contentChanged)
        XCTAssertTrue(ax.setValues.isEmpty, "Nothing may be written once the user has edited the field")
        XCTAssertEqual(ax.rawValue, "The blue fox jumped")
    }

    // MARK: - Existing empty-composer behaviour must survive

    func testEmptyComposerStillReceivesOnlyTheTranscription() {
        for placeholder in [chatGPT, gemini] {
            let ax = PlaceholderComposerOperator(placeholder: placeholder)
            ax.noOpsSelectedTextWrites = true
            let writer = RecordingOutputWriter()

            _ = OutputCoordinator(writer: writer, axOperator: ax).deliver(
                text: "delivery test.", autoPaste: true, protectSensitiveContexts: false, insertionMode: .accessibilityAPI
            )

            XCTAssertEqual(writer.pastedTexts, ["delivery test."])
            for payload in writer.pastedTexts {
                XCTAssertFalse(payload.contains(placeholder), "The placeholder must never reach the clipboard")
            }
        }
    }

    func testEmptyComposerInsertionStillVerifiesAndUndoesToEmpty() {
        let ax = VerifiableFieldOperator(rawValue: chatGPT)
        ax.numberOfCharacters = 11
        let pre = PastePreDispatchRecord(
            element: ax.savedElement,
            targetApplication: nil,
            role: "AXTextArea",
            subrole: nil,
            rawValue: chatGPT,
            committedValue: chatGPT,
            emptiness: .confirmedContent,
            selectedRange: NSRange(location: 0, length: 0),
            insertedText: "ChatGPT delivery test."
        )

        ax.rawValue = "ChatGPT delivery test."
        let outcome = PastedInsertionVerifier(axOperator: ax).evaluate(pre)
        XCTAssertEqual(outcome, .verifiedLogicallyEmpty(
            postValue: "ChatGPT delivery test.", presentationValue: chatGPT
        ))

        let decision = OutputCoordinator.decision(for: outcome, record: pre)
        ax.valueAfterClearing = chatGPT
        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(DictationUndoRecord(
            focusSnapshot: nil, context: decision.undoContext!, timestamp: Date(timeIntervalSince1970: 0)
        ))

        XCTAssertEqual(manager.undoLastDictation(invocation: .popoverButton), .undone)
        XCTAssertEqual(ax.setValues, [""], "Undo writes emptiness, never the placeholder")
    }
}
