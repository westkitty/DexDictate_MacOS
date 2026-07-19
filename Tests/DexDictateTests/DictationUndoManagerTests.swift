import ApplicationServices
import XCTest
@testable import DexDictateKit

/// Tests `DictationUndoManager`'s verification-first undo strategies: exact restore,
/// verified trim, and the last-resort Backspace fallback — each gated so a mismatch always
/// aborts instead of guessing.
final class DictationUndoManagerTests: XCTestCase {

    // Captured in `+setUp()`, which XCTest guarantees runs once before any test method in this
    // class — capturing it lazily (e.g. in a `static let`) would risk snapshotting a test's
    // override instead of the production default, depending on which test happens to run first.
    private static var defaultBackspaceSimulator: (Int, pid_t?) -> Void = { _, _ in }

    override static func setUp() {
        super.setUp()
        defaultBackspaceSimulator = DictationUndoManager.backspaceSimulator
    }

    override func tearDown() {
        DictationUndoManager.backspaceSimulator = Self.defaultBackspaceSimulator
        super.tearDown()
    }

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

    // MARK: - No record

    func testNothingToUndoWhenNoRecordExists() {
        let manager = DictationUndoManager(axOperator: MockAccessibilityOperator())
        XCTAssertFalse(manager.canUndoLastDictation)
        XCTAssertEqual(manager.undoLastDictation(), .nothingToUndo)
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
                context: DictationUndoContext(
                    insertedText: " Second sentence.",
                    previousFieldValue: "First sentence.",
                    replacementRange: NSRange(location: 15, length: 0),
                    targetApplication: makeTarget()
                ),
                timestamp: Date()
            )
        )

        XCTAssertTrue(manager.canUndoLastDictation)
        XCTAssertEqual(manager.undoLastDictation(), .undone)
        XCTAssertEqual(ax.lastSetValue, "First sentence.")
        XCTAssertEqual(ax.setCursorLocations.last, 15)
        XCTAssertFalse(manager.canUndoLastDictation, "Record should be consumed after undo")
    }

    // MARK: - Verified trim (no previous-value snapshot available)

    func testVerifiedTrimRemovesTrailingInsertionWhenNoPreviousValueWasCaptured() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        ax.stringMap = [kAXValueAttribute as String: "hello world"]
        ax.selectedRangeResult = NSRange(location: 11, length: 0) // cursor at end
        ax.setResults = [kAXValueAttribute as String: .success]

        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: nil,
                context: DictationUndoContext(
                    insertedText: " world",
                    previousFieldValue: nil,
                    replacementRange: nil,
                    targetApplication: makeTarget()
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(), .undone)
        XCTAssertEqual(ax.lastSetValue, "hello")
        XCTAssertEqual(ax.setCursorLocations.last, 5)
    }

    // MARK: - Content changed since insertion

    func testContentChangedRefusesToDeleteWhenTrailingTextNoLongerMatches() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        ax.settableMap = [kAXValueAttribute as String: true]
        // User kept typing after the dictation landed — the tail no longer matches.
        ax.stringMap = [kAXValueAttribute as String: "hello world, more text"]
        ax.selectedRangeResult = NSRange(location: 22, length: 0)
        ax.setResults = [kAXValueAttribute as String: .success]

        let manager = DictationUndoManager(axOperator: ax, focusProvider: { nil })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: nil,
                context: DictationUndoContext(
                    insertedText: " world",
                    previousFieldValue: "hello",
                    replacementRange: NSRange(location: 5, length: 0),
                    targetApplication: makeTarget()
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(), .contentChanged)
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
                context: DictationUndoContext(
                    insertedText: " world",
                    previousFieldValue: "hello",
                    replacementRange: NSRange(location: 5, length: 0),
                    targetApplication: makeTarget()
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(), .focusChanged)
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
                context: DictationUndoContext(
                    insertedText: "hello",
                    previousFieldValue: nil,
                    replacementRange: nil,
                    targetApplication: makeTarget()
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(), .cannotVerify)
    }

    // MARK: - Backspace fallback (unreadable field value)

    func testBackspaceFallbackWhenFieldValueCannotBeRead() {
        let ax = MockAccessibilityOperator()
        ax.hasFocusedElement = true
        // stringMap intentionally empty: getString(kAXValueAttribute) returns nil.

        var simulatedCount: Int?
        var simulatedPID: pid_t?
        DictationUndoManager.backspaceSimulator = { count, pid in
            simulatedCount = count
            simulatedPID = pid
        }

        let focus = makeFocusSnapshot()
        let manager = DictationUndoManager(axOperator: ax, focusProvider: { focus })
        manager.record(
            DictationUndoRecord(
                focusSnapshot: focus,
                context: DictationUndoContext(
                    insertedText: "hello",
                    previousFieldValue: nil,
                    replacementRange: nil,
                    targetApplication: makeTarget(pid: 4242)
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(), .undone)
        XCTAssertEqual(simulatedCount, 5)
        XCTAssertEqual(simulatedPID, 4242)
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
                context: DictationUndoContext(
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
                context: DictationUndoContext(
                    insertedText: "second",
                    previousFieldValue: "",
                    replacementRange: NSRange(location: 0, length: 0),
                    targetApplication: makeTarget()
                ),
                timestamp: Date()
            )
        )

        XCTAssertEqual(manager.undoLastDictation(), .undone)
        XCTAssertEqual(ax.lastSetValue, "", "Only the most recent insertion should be reversible")
        XCTAssertEqual(manager.undoLastDictation(), .nothingToUndo)
    }
}
