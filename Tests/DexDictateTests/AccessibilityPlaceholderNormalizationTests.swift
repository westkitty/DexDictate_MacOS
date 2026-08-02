import ApplicationServices
import XCTest
@testable import DexDictateKit

/// Regression coverage for the shipped defect where an empty browser composer's *placeholder*
/// — reported through `kAXValueAttribute` — was treated as committed content, so the dictation
/// was spliced into it and the placeholder became literal submitted text.
///
/// The observed direction varied with the cursor offset the host reported, which these tests
/// reproduce directly: offset 0 left the placeholder as a suffix, offset-at-end left it as a
/// prefix. Both are the same bug.
///
/// `Ask ChatGPT` / `Ask Gemini` appear here as fixtures only. `testProductionLogicHasNoHardcodedHostPlaceholders`
/// asserts they never appear in production placeholder logic.
final class AccessibilityPlaceholderNormalizationTests: XCTestCase {

    private let chatGPTPlaceholder = "Ask ChatGPT"
    private let geminiPlaceholder = "Ask Gemini"

    /// A host whose empty editor echoes `placeholder` through `AXValue` and reports the cursor
    /// at `cursor`. `committedCharacters` models `AXNumberOfCharacters`.
    private func emptyComposer(
        placeholder: String,
        cursor: Int,
        committedCharacters: Int? = 0
    ) -> MockAccessibilityOperator {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true, kAXSelectedTextAttribute as String: true]
        ax.stringMap = [
            kAXValueAttribute as String: placeholder,
            AccessibilityEditableTextSnapshot.placeholderAttribute: placeholder
        ]
        ax.numberOfCharacters = committedCharacters
        ax.selectedRangeResult = NSRange(location: cursor, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success, kAXSelectedTextAttribute as String: .success]
        return ax
    }

    private func deliver(_ text: String, into ax: MockAccessibilityOperator) -> OutputDeliveryDecision {
        OutputCoordinator(axOperator: ax).deliver(
            text: text,
            autoPaste: true,
            protectSensitiveContexts: false,
            insertionMode: .accessibilityAPI
        )
    }

    private func fieldValue(_ ax: MockAccessibilityOperator) -> String? {
        ax.stringMap[kAXValueAttribute as String]
    }

    // MARK: - 1-5: the reported defect

    func testEmptyEditorReportingPlaceholderReceivesOnlyTheDictation() {
        let ax = emptyComposer(placeholder: chatGPTPlaceholder, cursor: 0)

        _ = deliver("hello there", into: ax)

        XCTAssertEqual(fieldValue(ax), "hello there")
    }

    func testPlaceholderWithSelectionAtLocationZeroLeavesNoSuffix() {
        let ax = emptyComposer(placeholder: chatGPTPlaceholder, cursor: 0)

        _ = deliver("activated the trigger", into: ax)

        XCTAssertEqual(fieldValue(ax), "activated the trigger")
        XCTAssertFalse(fieldValue(ax)?.contains(chatGPTPlaceholder) ?? true)
    }

    func testPlaceholderWithMisleadingSelectionAtEndLeavesNoPrefix() {
        // The reported cursor indexes into the placeholder. Once the placeholder is discarded
        // that offset is meaningless and must not survive as an insertion point.
        let ax = emptyComposer(placeholder: geminiPlaceholder, cursor: (geminiPlaceholder as NSString).length)

        _ = deliver("I've activated the trigger.", into: ax)

        XCTAssertEqual(fieldValue(ax), "I've activated the trigger.")
    }

    func testChatGPTLikePlaceholderLeavesNoAskChatGPTSuffix() {
        let ax = emptyComposer(placeholder: chatGPTPlaceholder, cursor: 0)

        _ = deliver("activated the trigger now watch what happens as I put this down", into: ax)

        XCTAssertEqual(fieldValue(ax), "activated the trigger now watch what happens as I put this down")
    }

    func testGeminiLikePlaceholderLeavesNoAskGeminiPrefix() {
        let ax = emptyComposer(placeholder: geminiPlaceholder, cursor: (geminiPlaceholder as NSString).length)

        _ = deliver("now I'm speaking and now I'm gonna let go.", into: ax)

        XCTAssertEqual(fieldValue(ax), "now I'm speaking and now I'm gonna let go.")
    }

    // MARK: - 6: no host-specific knowledge in production

    func testProductionLogicHasNoHardcodedHostPlaceholders() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // DexDictateTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Sources")

        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        XCTAssertFalse(files.isEmpty, "Expected to find production Swift sources to scan")

        for file in files {
            let contents = try String(contentsOf: file, encoding: .utf8)
            for phrase in [chatGPTPlaceholder, geminiPlaceholder] {
                XCTAssertFalse(
                    contents.contains(phrase),
                    "Production source \(file.lastPathComponent) hardcodes the host placeholder \"\(phrase)\". "
                    + "Placeholder detection must rest on Accessibility attributes, not known strings."
                )
            }
        }
    }

    // MARK: - 7-9: real content is never mistaken for decoration

    func testTextIdenticalToPlaceholderIsPreservedWhenCharacterCountSaysItIsCommitted() {
        // The user genuinely typed the placeholder text. `AXNumberOfCharacters` agreeing with
        // the value's length is the host stating this is real content.
        let ax = emptyComposer(
            placeholder: chatGPTPlaceholder,
            cursor: (chatGPTPlaceholder as NSString).length,
            committedCharacters: (chatGPTPlaceholder as NSString).length
        )

        _ = deliver(" please", into: ax)

        XCTAssertEqual(fieldValue(ax), "Ask ChatGPT please")
    }

    func testNonEmptyFieldWithRealSelectionStillReplacesThatSelection() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "keep REPLACE keep"]
        ax.selectedRangeResult = NSRange(location: 5, length: 7)
        ax.setResults = [kAXValueAttribute as String: .success]

        _ = deliver("new", into: ax)

        XCTAssertEqual(fieldValue(ax), "keep new keep")
    }

    func testMissingPlaceholderAttributePreservesLegitimateValue() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "existing text"]
        ax.selectedRangeResult = NSRange(location: 13, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        _ = deliver(" more", into: ax)

        XCTAssertEqual(fieldValue(ax), "existing text more")
    }

    // MARK: - 10-11: ambiguity and contradictory readback fail safe

    func testAmbiguousPlaceholderEvidenceFallsBackWithoutDestructiveOverwrite() {
        // Value equals the placeholder, but the host also claims a committed character count
        // that contradicts that string's length. Contradictory evidence must never authorise
        // an overwrite.
        let ax = emptyComposer(placeholder: chatGPTPlaceholder, cursor: 0, committedCharacters: 4)

        let decision = deliver("hello", into: ax)

        XCTAssertEqual(fieldValue(ax), chatGPTPlaceholder, "Field must not be overwritten on ambiguous evidence")
        XCTAssertFalse(
            ax.setCallLog.contains(kAXValueAttribute as String),
            "No Accessibility mutation may be attempted while the editable state is ambiguous"
        )
        XCTAssertNil(decision.undoContext, "An unattempted insertion is not reversible")
        XCTAssertNotEqual(decision.delivery, .pastedToActiveApp, "Must fall back rather than claim a confirmed insertion")
    }

    func testReadbackContainingLeftoverPlaceholderIsNotConfirmed() {
        let ax = emptyComposer(placeholder: chatGPTPlaceholder, cursor: 0)
        // The host accepts the write but hands back the dictation still fused to its placeholder.
        ax.appliesSuccessfulMutations = false

        let decision = deliver("hello", into: ax)

        XCTAssertNotEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertNil(decision.undoContext, "A contradicted readback must not produce a reversible record")
    }

    // MARK: - 12-13: undo and undo context carry no placeholder

    func testUndoContextFromNormalizedEmptyFieldHoldsEmptyPreviousValue() throws {
        let ax = emptyComposer(placeholder: chatGPTPlaceholder, cursor: 0)

        let decision = deliver("hello there", into: ax)

        let context = try XCTUnwrap(decision.undoContext)
        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertEqual(context.previousFieldValue, "", "Previous value must be the logical empty string")
        XCTAssertEqual(context.replacementRange, NSRange(location: 0, length: 0))
        XCTAssertEqual(context.insertedText, "hello there")
        XCTAssertFalse(
            (context.previousFieldValue ?? "").contains(chatGPTPlaceholder),
            "The placeholder must never enter the undo context"
        )
        XCTAssertFalse(context.insertedText.contains(chatGPTPlaceholder))
    }

    func testUndoAfterNormalizedEmptyFieldInsertionRestoresEmptyStringDespitePlaceholderReadback() {
        let element = AXUIElementCreateSystemWide()
        let fake = UndoFakeOperator(focusedElement: element, currentValue: "hello there")
        fake.placeholderValue = chatGPTPlaceholder
        fake.selectedRange = NSRange(location: 11, length: 0)
        // The host re-renders its placeholder into AXValue the moment the field empties, which
        // is exactly what a raw readback comparison would misread as "the undo did not apply".
        fake.valueAfterClearing = chatGPTPlaceholder

        let manager = DictationUndoManager(axOperator: fake, focusProvider: { nil })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: nil,
                context: DictationUndoContext(
                    insertedText: "hello there",
                    previousFieldValue: "",
                    replacementRange: NSRange(location: 0, length: 0),
                    targetApplication: nil,
                    targetElement: element
                ),
                timestamp: Date(timeIntervalSince1970: 0)
            )
        )

        let outcome = manager.undoLastDictation(invocation: .popoverButton)

        XCTAssertEqual(outcome, .undone)
        XCTAssertEqual(fake.setValues.last, "", "Undo must write the logical empty string back")
    }

    // MARK: - 14-15: encoding and native behaviour

    func testEmojiRangesRemainCorrectWhenReplacingASelection() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        // "👍" is two UTF-16 units; the selection below is expressed in those units.
        ax.stringMap = [kAXValueAttribute as String: "👍 OLD 👍"]
        ax.selectedRangeResult = NSRange(location: 3, length: 3)
        ax.setResults = [kAXValueAttribute as String: .success]

        _ = deliver("NEW", into: ax)

        XCTAssertEqual(fieldValue(ax), "👍 NEW 👍")
    }

    func testEmojiDictationIntoNormalizedEmptyFieldSetsCursorByUTF16Length() {
        let ax = emptyComposer(placeholder: chatGPTPlaceholder, cursor: 0)

        _ = deliver("hi 👍", into: ax)

        XCTAssertEqual(fieldValue(ax), "hi 👍")
        XCTAssertEqual(ax.setCursorLocations.last, ("hi 👍" as NSString).length)
    }

    func testNativeFieldWithoutPlaceholderAttributeBehavesExactlyAsBefore() {
        // A native text view: no AXPlaceholderValue, no AXNumberOfCharacters. This is the
        // TextEdit shape, and it must take the untouched path.
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "Dear Bob,"]
        ax.selectedRangeResult = NSRange(location: 9, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let decision = deliver(" thanks for the note.", into: ax)

        XCTAssertEqual(fieldValue(ax), "Dear Bob, thanks for the note.")
        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertEqual(decision.undoContext?.previousFieldValue, "Dear Bob,")
        XCTAssertEqual(decision.undoContext?.replacementRange, NSRange(location: 9, length: 0))
    }

    func testEmptyNativeFieldWithNoPlaceholderIsStillTreatedAsEmpty() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: ""]
        ax.selectedRangeResult = NSRange(location: 0, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        _ = deliver("first words", into: ax)

        XCTAssertEqual(fieldValue(ax), "first words")
    }

    // MARK: - Snapshot semantics

    func testSnapshotEmptinessResolution() {
        func snapshot(
            value: String?, placeholder: String? = nil, count: Int? = nil
        ) -> AccessibilityEditableTextSnapshot {
            AccessibilityEditableTextSnapshot(
                rawValue: value, placeholderValue: placeholder, reportedCharacterCount: count,
                selectedRange: NSRange(location: 0, length: 0)
            )
        }

        XCTAssertEqual(snapshot(value: nil).emptiness, .ambiguous)
        XCTAssertEqual(snapshot(value: "").emptiness, .confirmedEmpty)
        XCTAssertEqual(snapshot(value: "Ask X", placeholder: "Ask X", count: 0).emptiness, .confirmedEmpty)
        XCTAssertEqual(snapshot(value: "Ask X", placeholder: "Ask X").emptiness, .confirmedEmpty)
        XCTAssertEqual(snapshot(value: "Ask X", placeholder: "Ask X", count: 5).emptiness, .confirmedContent)
        XCTAssertEqual(snapshot(value: "Ask X", placeholder: "Ask X", count: 2).emptiness, .ambiguous)
        XCTAssertEqual(snapshot(value: "real", placeholder: "Ask X").emptiness, .confirmedContent)
        XCTAssertEqual(snapshot(value: "real").emptiness, .confirmedContent)
    }

    func testSnapshotDiagnosticSummaryLeaksNoContent() {
        let summary = AccessibilityEditableTextSnapshot(
            rawValue: "secret account number",
            placeholderValue: "Ask ChatGPT",
            reportedCharacterCount: 21,
            selectedRange: NSRange(location: 3, length: 0),
            role: "AXTextArea"
        ).diagnosticSummary

        XCTAssertFalse(summary.contains("secret account number"))
        XCTAssertFalse(summary.contains("Ask ChatGPT"))
        XCTAssertTrue(summary.contains("rawLen=21"))
    }

    func testNormalizedEmptyFieldSuppressesPeriodAutoSpacing() {
        // Auto-spacing inspects the character before the cursor. Against a placeholder that
        // read from decoration; against the committed empty value there is nothing to read.
        let ax = emptyComposer(placeholder: "Reply to Bob.", cursor: (("Reply to Bob." as NSString).length))

        _ = deliver("Sure", into: ax)

        XCTAssertEqual(fieldValue(ax), "Sure", "No leading space may be derived from placeholder text")
    }
}
