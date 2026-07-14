import AppKit
import ApplicationServices
import Foundation

public struct OutputTargetApplication: Equatable {
    public let bundleIdentifier: String
    public let processIdentifier: pid_t

    public init(bundleIdentifier: String, processIdentifier: pid_t) {
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
    }
}

public enum OutputTargetContext: Equatable {
    case standard
    case sensitive(reason: String)
}

public enum OutputDelivery: Equatable {
    case savedOnly
    case pastedToActiveApp
    case copiedOnly(reason: String)
}

public struct OutputDeliveryDecision: Equatable {
    public let delivery: OutputDelivery
    /// Populated only when `delivery == .pastedToActiveApp`; carries what's needed to
    /// reverse this specific insertion later via `DictationUndoManager`. `nil` when nothing
    /// was actually inserted, or `undoContext` fields are `nil` when Accessibility couldn't
    /// read the relevant state for this particular field.
    public let undoContext: DictationUndoContext?

    public init(delivery: OutputDelivery, undoContext: DictationUndoContext? = nil) {
        self.delivery = delivery
        self.undoContext = undoContext
    }
}

/// Everything needed to reverse a single successful insertion later. Captured at delivery
/// time because the target field's pre-insertion value and cursor position can't be
/// reconstructed after the fact — once anything else happens in that field, they're gone.
public struct DictationUndoContext: Equatable {
    /// The exact text this delivery actually inserted (after auto-spacing).
    public let insertedText: String
    /// Full field value immediately before insertion, when readable via Accessibility.
    /// `nil` when the field didn't expose a readable `kAXValueAttribute` at delivery time.
    public let previousFieldValue: String?
    /// Range inside `previousFieldValue` that `insertedText` replaced (usually zero-length,
    /// at the cursor; non-zero when replacing a selection or an entire field).
    public let replacementRange: NSRange?
    public let targetApplication: OutputTargetApplication?

    public init(
        insertedText: String,
        previousFieldValue: String?,
        replacementRange: NSRange?,
        targetApplication: OutputTargetApplication?
    ) {
        self.insertedText = insertedText
        self.previousFieldValue = previousFieldValue
        self.replacementRange = replacementRange
        self.targetApplication = targetApplication
    }
}

/// Wraps the raw Accessibility API calls used during text insertion so they can be
/// replaced with a mock in unit tests without requiring real on-screen UI elements.
public protocol AccessibilityElementOperating {
    func focusedElement() -> AXUIElement?
    func isSettable(_ attribute: CFString, element: AXUIElement) -> Bool
    func getString(_ attribute: CFString, element: AXUIElement) -> String?
    func getSelectedRange(element: AXUIElement) -> NSRange?
    func set(_ value: CFTypeRef, for attribute: CFString, element: AXUIElement) -> AXError
    func setCursor(location: Int, element: AXUIElement)
}

/// Production implementation that calls the real macOS Accessibility APIs.
public struct SystemAccessibilityElementOperator: AccessibilityElementOperating {
    public init() {}

    public func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedValue
        ) == .success,
        let focusedValue,
        CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(focusedValue, to: AXUIElement.self)
    }

    public func isSettable(_ attribute: CFString, element: AXUIElement) -> Bool {
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, attribute, &settable)
        return settable.boolValue
    }

    public func getString(_ attribute: CFString, element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    public func getSelectedRange(element: AXUIElement) -> NSRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &value
        ) == .success,
        let value,
        CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        return NSRange(location: max(0, range.location), length: max(0, range.length))
    }

    public func set(_ value: CFTypeRef, for attribute: CFString, element: AXUIElement) -> AXError {
        AXUIElementSetAttributeValue(element, attribute, value)
    }

    public func setCursor(location: Int, element: AXUIElement) {
        var cursor = CFRange(location: location, length: 0)
        if let cursorValue = AXValueCreate(.cfRange, &cursor) {
            _ = AXUIElementSetAttributeValue(
                element, kAXSelectedTextRangeAttribute as CFString, cursorValue
            )
        }
    }
}

public protocol OutputWriting {
    func copy(_ text: String)
    func copyAndPaste(_ text: String, targetApplication: OutputTargetApplication?)
    /// Selects all text in the focused field (Cmd+A) then pastes (Cmd+V).
    func selectAllAndPaste(_ text: String, targetApplication: OutputTargetApplication?)
}

public protocol FocusedContextInspecting {
    func inspectFocusedContext() -> OutputTargetContext
}

public protocol OutputCoordinating {
    func deliver(
        text: String,
        autoPaste: Bool,
        protectSensitiveContexts: Bool,
        insertionMode: InsertionModeOverride,
        targetApplication: OutputTargetApplication?
    ) -> OutputDeliveryDecision
}

public struct ClipboardOutputWriter: OutputWriting {
    public init() {}

    public func copy(_ text: String) {
        ClipboardManager.copy(text)
    }

    public func copyAndPaste(_ text: String, targetApplication: OutputTargetApplication?) {
        ClipboardManager.copyAndPaste(text, targetApplication: targetApplication)
    }

    public func selectAllAndPaste(_ text: String, targetApplication: OutputTargetApplication?) {
        ClipboardManager.copySelectAllAndPaste(text, targetApplication: targetApplication)
    }
}

protocol OutputApplicationActivating {
    var frontmostProcessIdentifier: pid_t? { get }
    func activate(_ targetApplication: OutputTargetApplication)
}

struct AppKitOutputApplicationActivator: OutputApplicationActivating {
    var frontmostProcessIdentifier: pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    func activate(_ targetApplication: OutputTargetApplication) {
        guard let app = NSRunningApplication(processIdentifier: targetApplication.processIdentifier) else {
            return
        }
        _ = app.activate(options: [])
    }
}

public struct OutputCoordinator: OutputCoordinating {
    private let writer: OutputWriting
    private let contextInspector: FocusedContextInspecting
    private let applicationActivator: OutputApplicationActivating
    private let axOperator: AccessibilityElementOperating

    public init(
        writer: OutputWriting = ClipboardOutputWriter(),
        contextInspector: FocusedContextInspecting = AccessibilityFocusedContextInspector(),
        axOperator: AccessibilityElementOperating = SystemAccessibilityElementOperator()
    ) {
        self.init(
            writer: writer,
            contextInspector: contextInspector,
            applicationActivator: AppKitOutputApplicationActivator(),
            axOperator: axOperator
        )
    }

    init(
        writer: OutputWriting,
        contextInspector: FocusedContextInspecting,
        applicationActivator: OutputApplicationActivating = AppKitOutputApplicationActivator(),
        axOperator: AccessibilityElementOperating = SystemAccessibilityElementOperator()
    ) {
        self.writer = writer
        self.contextInspector = contextInspector
        self.applicationActivator = applicationActivator
        self.axOperator = axOperator
    }

    public func deliver(
        text: String,
        autoPaste: Bool,
        protectSensitiveContexts: Bool,
        insertionMode: InsertionModeOverride = .clipboardPaste,
        targetApplication: OutputTargetApplication? = nil
    ) -> OutputDeliveryDecision {
        guard autoPaste else {
            return OutputDeliveryDecision(delivery: .savedOnly)
        }

        if insertionMode == .clipboardOnly {
            writer.copy(text)
            return OutputDeliveryDecision(delivery: .copiedOnly(reason: "Per-app clipboard-only mode"))
        }

        let didTriggerActivation = activateTargetApplicationIfNeeded(targetApplication)

        if protectSensitiveContexts {
            // NSRunningApplication.activate() is asynchronous with no completion callback.
            // Without waiting here, inspectFocusedContext() below can read the *previous*
            // frontmost app's focused element — a real secure field in the target app would
            // then be misclassified as .standard and auto-pasted into. Bounded so a target
            // that never actually activates (e.g. it quit mid-flight) can't hang delivery.
            if let targetApplication, didTriggerActivation {
                waitForTargetActivation(targetApplication)
            }
            let context = contextInspector.inspectFocusedContext()
            if case .sensitive(let reason) = context {
                writer.copy(text)
                return OutputDeliveryDecision(delivery: .copiedOnly(reason: reason))
            }
        }

        if insertionMode == .replaceFieldWithClipboardPaste {
            let fieldSnapshot = bestEffortFieldSnapshot()
            writer.selectAllAndPaste(text, targetApplication: targetApplication)
            let replacementRange = fieldSnapshot.value.map { NSRange(location: 0, length: ($0 as NSString).length) }
            return OutputDeliveryDecision(
                delivery: .pastedToActiveApp,
                undoContext: DictationUndoContext(
                    insertedText: text,
                    previousFieldValue: fieldSnapshot.value,
                    replacementRange: replacementRange,
                    targetApplication: targetApplication
                )
            )
        }

        let outputText = textWithAutoSpacing(text)

        if insertionMode == .accessibilityAPI,
           canAttemptDirectAccessibilityInsertion(for: targetApplication) {
            let attempt = insertViaAccessibility(outputText)
            if attempt.succeeded {
                return OutputDeliveryDecision(
                    delivery: .pastedToActiveApp,
                    undoContext: DictationUndoContext(
                        insertedText: outputText,
                        previousFieldValue: attempt.previousValue,
                        replacementRange: attempt.replacementRange,
                        targetApplication: targetApplication
                    )
                )
            }
        }

        let fieldSnapshot = bestEffortFieldSnapshot()
        writer.copyAndPaste(outputText, targetApplication: targetApplication)
        return OutputDeliveryDecision(
            delivery: .pastedToActiveApp,
            undoContext: DictationUndoContext(
                insertedText: outputText,
                previousFieldValue: fieldSnapshot.value,
                replacementRange: fieldSnapshot.selectedRange,
                targetApplication: targetApplication
            )
        )
    }

    /// Best-effort, read-only Accessibility snapshot of the focused field's value and
    /// selection, taken immediately before a clipboard-based insertion. Never affects
    /// delivery behavior — only feeds `DictationUndoContext` for later undo. Returns `nil`
    /// values (not an error) when no focused element exists or its value isn't readable.
    private func bestEffortFieldSnapshot() -> (value: String?, selectedRange: NSRange?) {
        guard let element = axOperator.focusedElement() else { return (nil, nil) }
        return (
            axOperator.getString(kAXValueAttribute as CFString, element: element),
            axOperator.getSelectedRange(element: element)
        )
    }

    /// Prepends a space to `text` when it's about to be inserted immediately after a
    /// sentence-ending period with no space in between (e.g. cursor right after "...done."),
    /// which otherwise produces "done.Nexttext" when dictation lands mid-flow between fields.
    /// Reads the focused element's value and cursor position via the Accessibility API;
    /// returns `text` unchanged whenever that isn't available (no AX element, cursor at the
    /// very start of the field, `text` already starts with whitespace, or the preceding
    /// character isn't a period).
    private func textWithAutoSpacing(_ text: String) -> String {
        guard let firstScalar = text.unicodeScalars.first,
              !CharacterSet.whitespacesAndNewlines.contains(firstScalar) else {
            return text
        }
        guard let element = axOperator.focusedElement(),
              let selectedRange = axOperator.getSelectedRange(element: element),
              selectedRange.location > 0,
              let currentValue = axOperator.getString(kAXValueAttribute as CFString, element: element) else {
            return text
        }

        let currentNSString = currentValue as NSString
        guard selectedRange.location <= currentNSString.length else { return text }
        let precedingCharacter = currentNSString.substring(
            with: NSRange(location: selectedRange.location - 1, length: 1)
        )
        guard precedingCharacter == "." else { return text }

        return " " + text
    }

    /// Outcome of `insertViaAccessibility`, including the pre-insertion state needed to
    /// reverse it later. `previousValue`/`replacementRange` are best-effort reads taken up
    /// front and may be populated even when `succeeded` is `false`; callers should ignore
    /// them in that case.
    private struct AccessibilityInsertionAttempt {
        let succeeded: Bool
        let previousValue: String?
        let replacementRange: NSRange?
    }

    /// Attempts to insert text at the current cursor position via the Accessibility API.
    /// Preflights each attribute with `AXUIElementIsAttributeSettable` before attempting
    /// a set, and logs each failed strategy with the returned `AXError`.
    private func insertViaAccessibility(_ text: String) -> AccessibilityInsertionAttempt {
        guard let element = axOperator.focusedElement() else {
            Safety.log("insertViaAccessibility() — no focused AX element", category: .output)
            return AccessibilityInsertionAttempt(succeeded: false, previousValue: nil, replacementRange: nil)
        }

        // Read up front — read-only, and needed for undo bookkeeping regardless of which
        // strategy (if any) below actually succeeds.
        let currentValue = axOperator.getString(kAXValueAttribute as CFString, element: element)
        let selectedRange = axOperator.getSelectedRange(element: element)

        let valueSettable = axOperator.isSettable(kAXValueAttribute as CFString, element: element)

        // Strategy 1: replace the selected range inside the full value
        if valueSettable {
            if let currentValue, let selectedRange {
                let updatedValue = replacingText(in: currentValue, selectedRange: selectedRange, with: text)
                let result = axOperator.set(updatedValue as CFTypeRef, for: kAXValueAttribute as CFString, element: element)
                if result == .success {
                    axOperator.setCursor(
                        location: selectedRange.location + accessibilityCharacterCount(text),
                        element: element
                    )
                    return AccessibilityInsertionAttempt(succeeded: true, previousValue: currentValue, replacementRange: selectedRange)
                }
                Safety.log("insertViaAccessibility() — strategy 1 (value+range) failed: AXError \(result.rawValue)", category: .output)
            } else {
                // kAXValueAttribute is settable, but reading the current value and/or the
                // selected range failed — previously this fell through to strategy 2 with no
                // log line at all, contradicting this method's own doc comment promising every
                // failed strategy is logged.
                Safety.log("insertViaAccessibility() — strategy 1 skipped: could not read current value and/or selected range", category: .output)
            }
        } else {
            Safety.log("insertViaAccessibility() — strategy 1 skipped: kAXValueAttribute not settable", category: .output)
        }

        // Strategy 2: replace the selected text directly
        let selectedTextSettable = axOperator.isSettable(kAXSelectedTextAttribute as CFString, element: element)
        if selectedTextSettable {
            let result = axOperator.set(text as CFTypeRef, for: kAXSelectedTextAttribute as CFString, element: element)
            if result == .success {
                return AccessibilityInsertionAttempt(succeeded: true, previousValue: currentValue, replacementRange: selectedRange)
            }
            Safety.log("insertViaAccessibility() — strategy 2 (selectedText) failed: AXError \(result.rawValue)", category: .output)
        } else {
            Safety.log("insertViaAccessibility() — strategy 2 (selectedText) skipped: attribute not settable", category: .output)
        }

        Safety.log("insertViaAccessibility() — both strategies failed; falling back to clipboard paste", category: .output)
        return AccessibilityInsertionAttempt(succeeded: false, previousValue: nil, replacementRange: nil)
    }

    /// Returns `true` when it actually called `activate()` — i.e. the target existed, wasn't
    /// us, and wasn't already frontmost — which is exactly when the caller needs to worry
    /// about activation still being in flight.
    @discardableResult
    private func activateTargetApplicationIfNeeded(_ targetApplication: OutputTargetApplication?) -> Bool {
        guard let targetApplication else { return false }
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        guard targetApplication.processIdentifier != currentProcessIdentifier else {
            return false
        }
        guard targetApplication.processIdentifier != applicationActivator.frontmostProcessIdentifier else {
            return false
        }

        applicationActivator.activate(targetApplication)
        return true
    }

    /// Spins the run loop (not a hard `Thread.sleep`) until `targetApplication` actually
    /// becomes frontmost, or `timeout` elapses. Bounded so a target that never activates
    /// (e.g. it quit between capture and delivery) can't hang dictation delivery.
    private func waitForTargetActivation(
        _ targetApplication: OutputTargetApplication,
        timeout: TimeInterval = 0.15
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while applicationActivator.frontmostProcessIdentifier != targetApplication.processIdentifier,
              Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }

    private func canAttemptDirectAccessibilityInsertion(for targetApplication: OutputTargetApplication?) -> Bool {
        guard let targetApplication else { return true }
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        guard targetApplication.processIdentifier != currentProcessIdentifier else {
            return false
        }
        guard targetApplication.processIdentifier == applicationActivator.frontmostProcessIdentifier else {
            Safety.log(
                "OutputCoordinator — skipping direct Accessibility insertion because target application is not frontmost; falling back to clipboard paste.",
                category: .output
            )
            return false
        }
        return true
    }

    /// Returns the character count AX text-range APIs use for cursor advancement.
    /// AX positions are Unicode scalar offsets, not UTF-16 code units.
    /// The two diverge for characters outside the BMP (e.g. emoji).
    ///
    /// This is deliberately `unicodeScalars.count`, not `utf16.count` — see
    /// `AccessibilityInsertionTests.testCursorOffsetEmojiUsesUnicodeScalarsNotUTF16` and its
    /// sibling cursor-offset tests, which lock in this exact choice against real emoji/CJK
    /// cases. (A prior review pass considered switching this to `utf16.count` on the theory
    /// that AX ranges are NSString/UTF-16-based; that would fail all four of those tests and
    /// was not applied.)
    private func accessibilityCharacterCount(_ text: String) -> Int {
        text.unicodeScalars.count
    }

    private func replacingText(in currentValue: String, selectedRange: NSRange, with replacement: String) -> String {
        accessibilityReplacingText(in: currentValue, range: selectedRange, with: replacement)
    }
}

/// Splices `replacement` into `currentValue` at `range`, clamping the range to the string's
/// bounds. Shared by `OutputCoordinator.insertViaAccessibility` (performing an insertion) and
/// `DictationUndoManager` (verifying/reversing one), so both sides of an insert/undo pair
/// agree on exactly the same substitution semantics.
func accessibilityReplacingText(in currentValue: String, range: NSRange, with replacement: String) -> String {
    let currentNSString = currentValue as NSString
    let maxLocation = currentNSString.length
    let clampedLocation = min(max(0, range.location), maxLocation)
    let clampedLength = min(max(0, range.length), maxLocation - clampedLocation)
    let clampedRange = NSRange(location: clampedLocation, length: clampedLength)
    return currentNSString.replacingCharacters(in: clampedRange, with: replacement)
}
