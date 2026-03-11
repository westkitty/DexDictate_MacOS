import Foundation

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

    public init(delivery: OutputDelivery) {
        self.delivery = delivery
    }
}

public protocol OutputWriting {
    func copy(_ text: String)
    func copyAndPaste(_ text: String)
}

public protocol FocusedContextInspecting {
    func inspectFocusedContext() -> OutputTargetContext
}

public protocol OutputCoordinating {
    func deliver(text: String, autoPaste: Bool, protectSensitiveContexts: Bool) -> OutputDeliveryDecision
}

public struct ClipboardOutputWriter: OutputWriting {
    public init() {}

    public func copy(_ text: String) {
        ClipboardManager.copy(text)
    }

    public func copyAndPaste(_ text: String) {
        ClipboardManager.copyAndPaste(text)
    }
}

public struct OutputCoordinator: OutputCoordinating {
    private let writer: OutputWriting
    private let contextInspector: FocusedContextInspecting

    public init(
        writer: OutputWriting = ClipboardOutputWriter(),
        contextInspector: FocusedContextInspecting = AccessibilityFocusedContextInspector()
    ) {
        self.writer = writer
        self.contextInspector = contextInspector
    }

    public func deliver(text: String, autoPaste: Bool, protectSensitiveContexts: Bool) -> OutputDeliveryDecision {
        guard autoPaste else {
            return OutputDeliveryDecision(delivery: .savedOnly)
        }

        if protectSensitiveContexts {
            let context = contextInspector.inspectFocusedContext()
            if case .sensitive(let reason) = context {
                writer.copy(text)
                return OutputDeliveryDecision(delivery: .copiedOnly(reason: reason))
            }
        }

        writer.copyAndPaste(text)
        return OutputDeliveryDecision(delivery: .pastedToActiveApp)
    }
}
