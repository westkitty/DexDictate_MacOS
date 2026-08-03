import ApplicationServices
import XCTest
@testable import DexDictateKit

/// Models the host shape measured from Brave in production logs across 11 consecutive real
/// deliveries into an empty ChatGPT/Gemini composer:
///
///   role=AXTextArea  rawLen=11  placeholderLen=nil  reportedCount=11  selection={0,0}
///
/// That is: the placeholder is rendered through `kAXValueAttribute`, `AXPlaceholderValue` is
/// **not exposed at all**, and `AXNumberOfCharacters` reports the placeholder's own length. An
/// empty composer is therefore indistinguishable from a field genuinely holding that many
/// characters — no classifier can tell them apart, which is why the previous "detect the
/// placeholder" repair could not work in production.
///
/// The host itself knows better: a selected-text write is spliced into its *real* (empty)
/// content, not into the placeholder string it reports. This fake reproduces exactly that
/// asymmetry, so a delivery that writes only the transcription comes out clean while one that
/// writes a value reconstructed from `AXValue` reproduces the reported corruption.
final class PlaceholderComposerOperator: AccessibilityElementOperating {
    private let element = AXUIElementCreateSystemWide()

    /// The editor's genuine content. Empty means the user has typed nothing.
    private(set) var realContent: String
    /// Presentation-only text the host paints when `realContent` is empty.
    let placeholder: String
    var reportedSelection: NSRange
    var valueIsSettable: Bool
    var selectedTextIsSettable: Bool
    /// Set false to model a host that exposes `AXNumberOfCharacters` at all.
    var reportsCharacterCount = true

    private(set) var setCallLog: [String] = []
    private(set) var lastSetValue: String?
    private(set) var lastSetSelectedText: String?

    init(
        placeholder: String,
        realContent: String = "",
        reportedSelection: NSRange = NSRange(location: 0, length: 0),
        valueIsSettable: Bool = true,
        selectedTextIsSettable: Bool = true
    ) {
        self.placeholder = placeholder
        self.realContent = realContent
        self.reportedSelection = reportedSelection
        self.valueIsSettable = valueIsSettable
        self.selectedTextIsSettable = selectedTextIsSettable
    }

    /// What `kAXValueAttribute` hands out — the placeholder while the editor is empty.
    private var reportedValue: String { realContent.isEmpty ? placeholder : realContent }

    func focusedElement() -> AXUIElement? { element }

    func isSettable(_ attribute: CFString, element: AXUIElement) -> Bool {
        switch attribute as String {
        case kAXValueAttribute as String: return valueIsSettable
        case kAXSelectedTextAttribute as String: return selectedTextIsSettable
        default: return false
        }
    }

    func getString(_ attribute: CFString, element: AXUIElement) -> String? {
        switch attribute as String {
        case kAXValueAttribute as String: return reportedValue
        // Chromium does not publish this for its web editors — measured, not assumed.
        case AccessibilityEditableTextSnapshot.placeholderAttribute: return nil
        case kAXRoleAttribute as String: return "AXTextArea"
        default: return nil
        }
    }

    func getNumberOfCharacters(element: AXUIElement) -> Int? {
        reportsCharacterCount ? (reportedValue as NSString).length : nil
    }

    func getSelectedRange(element: AXUIElement) -> NSRange? { reportedSelection }

    func set(_ value: CFTypeRef, for attribute: CFString, element: AXUIElement) -> AXError {
        guard let string = value as? String else { return .failure }
        switch attribute as String {
        case kAXValueAttribute as String:
            guard valueIsSettable else { return .attributeUnsupported }
            setCallLog.append(kAXValueAttribute as String)
            lastSetValue = string
            realContent = string
            return .success
        case kAXSelectedTextAttribute as String:
            guard selectedTextIsSettable else { return .attributeUnsupported }
            setCallLog.append(kAXSelectedTextAttribute as String)
            lastSetSelectedText = string
            // Spliced into the REAL content. The reported selection is an offset into whatever
            // the host was painting, so it is clamped to what actually exists.
            let current = realContent as NSString
            let location = min(max(reportedSelection.location, 0), current.length)
            let length = min(reportedSelection.length, current.length - location)
            realContent = current.replacingCharacters(in: NSRange(location: location, length: length), with: string)
            return .success
        default:
            return .failure
        }
    }

    @discardableResult
    func setCursor(location: Int, element: AXUIElement) -> AXError {
        // Chromium did not report the caret back where it was put in any of the 11 measured
        // insertions, so this fake deliberately does not honour the write either.
        .success
    }
}

/// Records what the clipboard fallback was asked to carry, so the payload invariant
/// `clipboardPayload == finalTranscription` can be asserted directly.
final class RecordingOutputWriter: OutputWriting {
    var copiedTexts: [String] = []
    var pastedTexts: [String] = []
    var selectAllAndPastedTexts: [String] = []

    @discardableResult
    func copy(_ text: String) -> Bool {
        copiedTexts.append(text)
        return true
    }

    @discardableResult
    func copyAndPaste(
        _ text: String,
        targetApplication: OutputTargetApplication?,
        completion: @escaping (OutputDelivery) -> Void
    ) -> Bool {
        pastedTexts.append(text)
        return true
    }

    @discardableResult
    func selectAllAndPaste(
        _ text: String,
        targetApplication: OutputTargetApplication?,
        completion: @escaping (OutputDelivery) -> Void
    ) -> Bool {
        selectAllAndPastedTexts.append(text)
        return true
    }
}

/// End-to-end coverage of the delivery sequence through the production `OutputCoordinator`,
/// not just the semantic-snapshot helper.
///
/// `Ask ChatGPT` / `Ask Gemini` appear here as fixtures only.
final class PlaceholderDeliverySequenceTests: XCTestCase {

    private let chatGPT = "Ask ChatGPT"
    private let gemini = "Ask Gemini"

    private func deliver(
        _ text: String,
        into ax: AccessibilityElementOperating,
        writer: RecordingOutputWriter = RecordingOutputWriter()
    ) -> (decision: OutputDeliveryDecision, writer: RecordingOutputWriter) {
        let decision = OutputCoordinator(writer: writer, axOperator: ax).deliver(
            text: text,
            autoPaste: true,
            protectSensitiveContexts: false,
            insertionMode: .accessibilityAPI
        )
        return (decision, writer)
    }

    // MARK: - 1-4: the measured host shape, at every cursor position

    func testEmptyComposerReceivesOnlyTheTranscription() {
        let ax = PlaceholderComposerOperator(placeholder: chatGPT)

        _ = deliver("ChatGPT empty-field test.", into: ax)

        XCTAssertEqual(ax.realContent, "ChatGPT empty-field test.")
    }

    func testPlaceholderCannotSurviveAsASuffix() {
        let ax = PlaceholderComposerOperator(placeholder: chatGPT, reportedSelection: NSRange(location: 0, length: 0))

        _ = deliver("Does it still work? Today.", into: ax)

        XCTAssertEqual(ax.realContent, "Does it still work? Today.")
        XCTAssertFalse(ax.realContent.contains(chatGPT), "The reported suffix corruption must not recur")
    }

    func testPlaceholderCannotSurviveAsAPrefix() {
        let ax = PlaceholderComposerOperator(
            placeholder: gemini,
            reportedSelection: NSRange(location: (gemini as NSString).length, length: 0)
        )

        _ = deliver("Does it work now?", into: ax)

        XCTAssertEqual(ax.realContent, "Does it work now?")
        XCTAssertFalse(ax.realContent.contains(gemini), "The reported prefix corruption must not recur")
    }

    func testCursorAnywhereInsideThePlaceholderStillYieldsOnlyTheTranscription() {
        for location in 0...(chatGPT as NSString).length {
            let ax = PlaceholderComposerOperator(
                placeholder: chatGPT,
                reportedSelection: NSRange(location: location, length: 0)
            )

            _ = deliver("clean.", into: ax)

            XCTAssertEqual(ax.realContent, "clean.", "Reported cursor \(location) must not change the outcome")
        }
    }

    func testNoWriteEverCarriesThePlaceholder() {
        let ax = PlaceholderComposerOperator(placeholder: chatGPT)

        _ = deliver("only this", into: ax)

        for written in [ax.lastSetValue, ax.lastSetSelectedText].compactMap({ $0 }) {
            XCTAssertFalse(written.contains(chatGPT), "No AX setter may ever receive the placeholder")
            XCTAssertEqual(written, "only this", "Only the transcription may be written")
        }
    }

    // MARK: - 6: genuine content matching a placeholder phrase survives

    func testGenuineTextIdenticalToThePlaceholderIsPreserved() {
        let ax = PlaceholderComposerOperator(
            placeholder: chatGPT,
            realContent: chatGPT,
            reportedSelection: NSRange(location: (chatGPT as NSString).length, length: 0)
        )

        _ = deliver(" please", into: ax)

        XCTAssertEqual(ax.realContent, "Ask ChatGPT please", "Real user text must never be stripped")
    }

    // MARK: - 7-10: ambiguity and clipboard payload

    func testAmbiguousSnapshotMakesNoSetterCallBeforeFallingBack() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true, kAXSelectedTextAttribute as String: true]
        ax.stringMap = [
            kAXValueAttribute as String: chatGPT,
            AccessibilityEditableTextSnapshot.placeholderAttribute: chatGPT
        ]
        // Contradictory: value matches the placeholder yet a different committed count is claimed.
        ax.numberOfCharacters = 4
        ax.selectedRangeResult = NSRange(location: 0, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success, kAXSelectedTextAttribute as String: .success]

        let (decision, writer) = deliver("hello", into: ax)

        XCTAssertTrue(ax.setCallLog.isEmpty, "Ambiguous state must produce no AX setter call at all")
        XCTAssertEqual(ax.stringMap[kAXValueAttribute as String], chatGPT, "Field must be left untouched")
        XCTAssertEqual(writer.pastedTexts, ["hello"], "Fallback payload is the transcription alone")
        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertNil(decision.undoContext, "An unverified paste is not reversible")
    }

    func testClipboardFallbackPayloadIsExactlyTheTranscription() {
        let ax = PlaceholderComposerOperator(
            placeholder: chatGPT,
            valueIsSettable: false,
            selectedTextIsSettable: false
        )

        let (_, writer) = deliver("Gemini empty-field test.", into: ax)

        XCTAssertEqual(writer.pastedTexts, ["Gemini empty-field test."])
        XCTAssertEqual(ax.realContent, "", "No AX write may occur when no safe strategy exists")
    }

    func testClipboardFallbackPayloadNeverIncludesRawValueOrPlaceholder() {
        let ax = PlaceholderComposerOperator(
            placeholder: chatGPT,
            realContent: "existing user text",
            valueIsSettable: false,
            selectedTextIsSettable: false
        )

        let (_, writer) = deliver("appended", into: ax)

        XCTAssertEqual(writer.pastedTexts, ["appended"])
        for payload in writer.pastedTexts {
            XCTAssertFalse(payload.contains(chatGPT))
            XCTAssertFalse(payload.contains("existing user text"))
        }
    }

    // MARK: - 11-14: no delivery leaves both a mutation and a paste

    func testUnverifiedAccessibilityMutationIsNeverFollowedByAClipboardPaste() {
        // The composer accepts the selected-text write, so the transcription lands — but the
        // reconstructed expectation cannot match, so the delivery stays unverified.
        let ax = PlaceholderComposerOperator(placeholder: chatGPT)

        let (decision, writer) = deliver("landed once", into: ax)

        XCTAssertEqual(ax.realContent, "landed once")
        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertTrue(
            writer.pastedTexts.isEmpty,
            "A delivery that already mutated the field must not also paste — that is how text gets duplicated"
        )
        XCTAssertNil(decision.undoContext)
    }

    func testFailedSetterLeavesFieldUntouchedAndThenFallsBackExactlyOnce() {
        let ax = PlaceholderComposerOperator(
            placeholder: chatGPT,
            realContent: "user text",
            reportedSelection: NSRange(location: 9, length: 0),
            valueIsSettable: false,
            selectedTextIsSettable: false
        )

        let (decision, writer) = deliver(" more", into: ax)

        XCTAssertEqual(ax.realContent, "user text", "A refused strategy must not mutate anything")
        XCTAssertEqual(writer.pastedTexts, [" more"])
        XCTAssertEqual(decision.delivery, .requestedButUnverified)
    }

    func testRequestedButUnverifiedNeverCarriesAnUndoContext() {
        let ax = PlaceholderComposerOperator(placeholder: chatGPT)

        let (decision, _) = deliver("unconfirmed", into: ax)

        XCTAssertEqual(decision.delivery, .requestedButUnverified)
        XCTAssertNil(decision.undoContext)
    }

    // MARK: - 16-18: undo context and reversibility

    func testUndoContextNeverContainsThePlaceholder() {
        let ax = PlaceholderComposerOperator(placeholder: chatGPT)

        let (decision, _) = deliver("clean text", into: ax)

        let previous = decision.undoContext?.previousFieldValue ?? ""
        XCTAssertFalse(previous.contains(chatGPT))
        XCTAssertFalse((decision.undoContext?.insertedText ?? "").contains(chatGPT))
    }

    func testBrowserUnverifiedPasteRemainsNonReversible() {
        let ax = PlaceholderComposerOperator(placeholder: gemini)

        let (decision, _) = deliver("not reversible", into: ax)

        XCTAssertNil(decision.undoContext, "Browser paste must not be made reversible to light up the control")
        XCTAssertFalse(decision.delivery == .pastedToActiveApp)
    }

    /// The native shape: a real editor whose reported value *is* its content and which honours
    /// a selected-text write, so the reconstruction matches on readback and undo is armed.
    func testConfirmedNativeInsertionRemainsReversible() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXSelectedTextAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "Dear Bob,"]
        ax.selectedRangeResult = NSRange(location: 9, length: 0)
        ax.setResults = [kAXSelectedTextAttribute as String: .success]

        let (decision, writer) = deliver(" thanks.", into: ax)

        XCTAssertEqual(ax.stringMap[kAXValueAttribute as String], "Dear Bob, thanks.")
        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertEqual(decision.undoContext?.previousFieldValue, "Dear Bob,")
        XCTAssertEqual(decision.undoContext?.replacementRange, NSRange(location: 9, length: 0))
        XCTAssertEqual(decision.undoContext?.insertedText, " thanks.")
        XCTAssertTrue(writer.pastedTexts.isEmpty)
    }

    /// A host that reports the caret somewhere other than where it was placed must still be
    /// able to produce a confirmed insertion — requiring both the value *and* the caret to
    /// agree made zero of 11 measured real insertions confirmable and left undo permanently
    /// disabled, which is what the user experienced.
    func testCaretDisagreementAloneDoesNotBlockConfirmation() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXSelectedTextAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "abc"]
        ax.selectedRangeResult = NSRange(location: 3, length: 0)
        ax.setResults = [kAXSelectedTextAttribute as String: .success]
        ax.ignoresCursorWrites = true

        let (decision, _) = deliver("def", into: ax)

        XCTAssertEqual(ax.stringMap[kAXValueAttribute as String], "abcdef")
        XCTAssertEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertEqual(decision.undoContext?.previousFieldValue, "abc")
    }

    func testValueDisagreementStillBlocksConfirmation() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXSelectedTextAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "abc"]
        ax.selectedRangeResult = NSRange(location: 3, length: 0)
        ax.setResults = [kAXSelectedTextAttribute as String: .success]
        ax.appliesSuccessfulMutations = false

        let (decision, _) = deliver("def", into: ax)

        XCTAssertNotEqual(decision.delivery, .pastedToActiveApp)
        XCTAssertNil(decision.undoContext, "An exact value mismatch must still refuse confirmation")
    }

    // MARK: - 19-21: undo control presentation

    func testUndoControlIsMountedAndReadableInEveryState() {
        let disabled = UndoControlModel(availability: .unavailable(.deliveryNotReversible(
            OutputDelivery.requestedButUnverified.undoIneligibilityDetail
        )))
        XCTAssertTrue(disabled.isVisible)
        XCTAssertFalse(disabled.isEnabled)
        XCTAssertEqual(disabled.title, "Undo Last Dictation")
        XCTAssertTrue(disabled.statusLine.hasPrefix("Unavailable — "))
        XCTAssertFalse(disabled.statusLine.isEmpty)

        let enabled = UndoControlModel(availability: .available)
        XCTAssertTrue(enabled.isVisible)
        XCTAssertTrue(enabled.isEnabled)
        XCTAssertEqual(enabled.title, disabled.title, "One control, two states")
        XCTAssertTrue(enabled.statusLine.hasPrefix("Ready"))
    }

    func testEveryUnavailableReasonHasAShortOnScreenExplanation() {
        let reasons: [DictationUndoUnavailableReason] = [
            .noDictationYet,
            .deliveryNotReversible("the delivery could not be confirmed"),
            .consumedBySuccessfulUndo,
            .invalidatedByContentChange,
            .targetNoLongerExists,
            .supersededByNewerDictation,
            .engineStopped
        ]
        for reason in reasons {
            let model = UndoControlModel(availability: .unavailable(reason))
            XCTAssertFalse(reason.shortMessage.isEmpty, "\(reason) needs a readable on-screen reason")
            XCTAssertTrue(
                model.statusLine.contains(reason.shortMessage),
                "The status line must state the actual reason without hovering"
            )
            XCTAssertLessThanOrEqual(
                model.statusLine.count, 90,
                "The reason must fit the 320pt popover without truncation"
            )
        }
    }
}
