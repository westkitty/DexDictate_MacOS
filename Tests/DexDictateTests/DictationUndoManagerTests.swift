import ApplicationServices
import XCTest
@testable import DexDictateKit

/// Tests `DictationUndoManager`'s verification-first undo strategies. Exact target, range,
/// content, and mutation readback are required; a mismatch always aborts instead of guessing.
final class DictationUndoManagerTests: XCTestCase {

    private func makeTarget(bundleID: String = "com.example.chat", pid: pid_t = 4242) -> OutputTargetApplication {
        OutputTargetApplication(bundleIdentifier: bundleID, processIdentifier: pid)
    }

    private func makeFocusSnapshot(bundleID: String = "com.example.chat", pid: pid_t = 4242) -> FocusedElementSnapshot {
        FocusedElementSnapshot(
            role: "AXTextField",
            processIdentifier: pid,
            bundleIdentifier: bundleID
        )
    }

    private func makeContext(
        _ ax: MockAccessibilityOperator,
        insertedText: String,
        previousFieldValue: String?,
        replacementRange: NSRange?,
        targetApplication: OutputTargetApplication? = nil
    ) -> DictationUndoContext {
        DictationUndoContext(
            insertedText: insertedText,
            previousFieldValue: previousFieldValue,
            replacementRange: replacementRange,
            targetApplication: targetApplication ?? makeTarget(),
            targetElement: ax.focused
        )
    }

    // MARK: - No record

    func testNothingToUndoWhenNoRecordExists() {
        let manager = DictationUndoManager(axOperator: MockAccessibilityOperator())
        XCTAssertFalse(manager.canUndoLastDictation)
        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .nothingToUndo)
    }

    // MARK: - Exact restore

    func testExactRestoreSetsFieldBackToPreviousValueAndCursor() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "First sentence. Second sentence."]
        ax.selectedRangeResult = NSRange(location: 33, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let focus = makeFocusSnapshot()
        let manager = DictationUndoManager(axOperator: ax, focusProvider: { focus })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: focus,
                context: makeContext(
                    ax,
                    insertedText: " Second sentence.",
                    previousFieldValue: "First sentence.",
                    replacementRange: NSRange(location: 15, length: 0),
                    targetApplication: makeTarget()
                ),
                timestamp: Date()
            )
        )

        XCTAssertTrue(manager.canUndoLastDictation)
        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .undone)
        XCTAssertEqual(ax.lastSetValue, "First sentence.")
        XCTAssertEqual(ax.setCursorLocations.last, 15)
        XCTAssertFalse(manager.canUndoLastDictation, "Record should be consumed after undo")
    }

    // MARK: - Verified trim

    func testVerifiedTrimRemovesExactZeroLengthInsertionAtSavedRange() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "hello world!"]
        ax.selectedRangeResult = NSRange(location: 11, length: 0) // cursor at end
        ax.setResults = [kAXValueAttribute as String: .success]

        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: nil,
                context: makeContext(
                    ax,
                    insertedText: " world",
                    previousFieldValue: "hello",
                    replacementRange: NSRange(location: 5, length: 0),
                    targetApplication: makeTarget()
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .undone)
        XCTAssertEqual(ax.lastSetValue, "hello!")
        XCTAssertEqual(ax.setCursorLocations.last, 5)
    }

    // MARK: - Content changed since insertion

    func testContentChangedRefusesShiftedDuplicateText() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "hello world world"]
        ax.selectedRangeResult = NSRange(location: 17, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: nil,
                context: makeContext(
                    ax,
                    insertedText: " world",
                    previousFieldValue: "hello",
                    replacementRange: NSRange(location: 5, length: 0),
                    targetApplication: makeTarget()
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .contentChanged)
        XCTAssertTrue(ax.setCallLog.isEmpty, "Should not mutate the field when content no longer matches")
    }

    // MARK: - Focus changed

    func testFocusChangedRefusesToActWhenDifferentAppIsFocused() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "hello world"]
        ax.selectedRangeResult = NSRange(location: 11, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let triggerFocus = makeFocusSnapshot(bundleID: "com.example.chat", pid: 4242)
        let currentFocus = makeFocusSnapshot(bundleID: "com.other.app", pid: 9001)
        let manager = DictationUndoManager(axOperator: ax, focusProvider: { currentFocus })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: triggerFocus,
                context: makeContext(
                    ax,
                    insertedText: " world",
                    previousFieldValue: "hello",
                    replacementRange: NSRange(location: 5, length: 0),
                    targetApplication: makeTarget()
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .focusChanged)
        XCTAssertTrue(ax.setCallLog.isEmpty)
    }

    // MARK: - Cannot verify

    func testCannotVerifyWhenNoFocusedElementExists() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = false

        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: nil,
                context: makeContext(
                    ax,
                    insertedText: "hello",
                    previousFieldValue: nil,
                    replacementRange: nil,
                    targetApplication: makeTarget()
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .cannotVerify)
    }

    // MARK: - Unreadable field

    func testUnreadableFieldRefusesUndoWithoutBackspace() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        // stringMap intentionally empty: getString(kAXValueAttribute) returns nil.

        let focus = makeFocusSnapshot()
        let manager = DictationUndoManager(axOperator: ax, focusProvider: { focus })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: focus,
                context: makeContext(
                    ax,
                    insertedText: "hello",
                    previousFieldValue: nil,
                    replacementRange: nil,
                    targetApplication: makeTarget(pid: 4242)
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .cannotVerify)
        XCTAssertTrue(ax.setCallLog.isEmpty)
    }
}

extension DictationUndoManagerTests {
    func testInvalidSavedRangeRefusesUndo() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.stringMap = [kAXValueAttribute as String: "hello world"]

        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: nil,
                context: makeContext(
                    ax,
                    insertedText: " world",
                    previousFieldValue: "hello",
                    replacementRange: NSRange(location: 99, length: 0)
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .cannotVerify)
        XCTAssertTrue(ax.setCallLog.isEmpty)
    }

    func testNonEmptySelectionReplacementCannotUseTrimFallback() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "hello new!"]
        ax.selectedRangeResult = NSRange(location: 9, length: 0)

        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: nil,
                context: makeContext(
                    ax,
                    insertedText: "new",
                    previousFieldValue: "hello old",
                    replacementRange: NSRange(location: 6, length: 3)
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .contentChanged)
        XCTAssertTrue(ax.setCallLog.isEmpty)
    }

    func testSameSemanticFocusButDifferentAccessibilityElementRefusesUndo() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        let focus = makeFocusSnapshot()
        let manager = DictationUndoManager(axOperator: ax, focusProvider: { focus })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: focus,
                context: DictationUndoContext(
                    insertedText: " world",
                    previousFieldValue: "hello",
                    replacementRange: NSRange(location: 5, length: 0),
                    targetApplication: makeTarget(),
                    targetElement: AXUIElementCreateApplication(4242)
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .focusChanged)
        XCTAssertTrue(ax.setCallLog.isEmpty)
    }

    func testSuccessfulSetterWithContradictoryReadbackIsNotReportedUndone() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "hello world"]
        ax.selectedRangeResult = NSRange(location: 11, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]
        ax.appliesSuccessfulMutations = false

        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: nil,
                context: makeContext(
                    ax,
                    insertedText: " world",
                    previousFieldValue: "hello",
                    replacementRange: NSRange(location: 5, length: 0)
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .cannotVerify)
        XCTAssertEqual(ax.setCallLog, [kAXValueAttribute as String])
    }

    // MARK: - Single-slot record replacement

    func testRecordingANewInsertionReplacesThePendingOne() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "second"]
        ax.selectedRangeResult = NSRange(location: 6, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: nil,
                context: makeContext(
                    ax,
                    insertedText: "first",
                    previousFieldValue: "",
                    replacementRange: NSRange(location: 0, length: 0),
                    targetApplication: makeTarget()
                ),
                timestamp: Date()
            )
        )
        manager.record(
            DictationUndoRecord(
                focusSnapshot: nil,
                context: makeContext(
                    ax,
                    insertedText: "second",
                    previousFieldValue: "",
                    replacementRange: NSRange(location: 0, length: 0),
                    targetApplication: makeTarget()
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .undone)
        XCTAssertEqual(ax.lastSetValue, "", "Only the most recent insertion should be reversible")
        XCTAssertEqual(manager.undoLastDictation(invocation: .globalShortcut), .nothingToUndo)
    }
}
