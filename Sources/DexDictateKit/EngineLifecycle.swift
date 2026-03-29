import Foundation

public enum EngineState: String, CaseIterable {
    case stopped
    case initializing
    case ready
    case listening
    case transcribing
    case error
}

enum EngineLifecycleEvent: String, CaseIterable {
    case startSystemRequested
    case inputMonitorActivated
    case inputMonitorFailed
    case listeningStarted
    case audioCaptureFailed
    case transcriptionStarted
    case transcriptionCompleted
    case systemStopped
}

struct EngineLifecycleTransition: Equatable {
    let from: EngineState
    let event: EngineLifecycleEvent
    let to: EngineState
}

struct EngineLifecycleStateMachine {
    private(set) var state: EngineState = .stopped

    init(state: EngineState = .stopped) {
        self.state = state
    }

    mutating func apply(_ event: EngineLifecycleEvent) -> EngineLifecycleTransition? {
        guard let next = nextState(for: event) else {
            return nil
        }

        let transition = EngineLifecycleTransition(from: state, event: event, to: next)
        state = next
        return transition
    }

    func nextState(for event: EngineLifecycleEvent) -> EngineState? {
        switch (state, event) {
        case (.stopped, .startSystemRequested):
            return .initializing
        case (.initializing, .inputMonitorActivated),
             (.error, .inputMonitorActivated):
            return .ready
        case (.initializing, .inputMonitorFailed),
             (.ready, .inputMonitorFailed):
            return .error
        case (.ready, .listeningStarted):
            return .listening
        case (.listening, .audioCaptureFailed):
            return .ready
        case (.ready, .transcriptionStarted),
             (.listening, .transcriptionStarted):
            return .transcribing
        case (.transcribing, .transcriptionCompleted):
            return .ready
        case (_, .systemStopped):
            return .stopped
        default:
            return nil
        }
    }
}
