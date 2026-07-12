import Foundation

// MARK: - Engine Display State

public enum EngineDisplayState: Equatable {
    case stopped
    case initializing
    case ready
    case listening
    case transcribing
    case error(String)

    public var label: String {
        switch self {
        case .stopped:          return "Off"
        case .initializing:     return "Starting…"
        case .ready:            return "Ready"
        case .listening:        return "Listening"
        case .transcribing:     return "Transcribing"
        case .error(let msg):   return msg.isEmpty ? "Error" : msg
        }
    }

    public var systemImage: String {
        switch self {
        case .stopped:          return "mic.slash"
        case .initializing:     return "ellipsis.circle"
        case .ready:            return "mic.badge.plus"
        case .listening:        return "waveform"
        case .transcribing:     return "brain"
        case .error:            return "exclamationmark.triangle"
        }
    }

    public var isActive: Bool {
        switch self {
        case .listening, .transcribing: return true
        default:                        return false
        }
    }
}

// MARK: - Permission Display State

public struct PermissionDisplayState: Equatable {
    public let micGranted: Bool
    public let accessibilityGranted: Bool
    public let inputMonitoringGranted: Bool

    public init(micGranted: Bool, accessibilityGranted: Bool, inputMonitoringGranted: Bool) {
        self.micGranted = micGranted
        self.accessibilityGranted = accessibilityGranted
        self.inputMonitoringGranted = inputMonitoringGranted
    }

    public var allGranted: Bool {
        micGranted && accessibilityGranted && inputMonitoringGranted
    }

    public var missingLabels: [String] {
        var missing: [String] = []
        if !micGranted              { missing.append("Microphone") }
        if !accessibilityGranted    { missing.append("Accessibility") }
        if !inputMonitoringGranted  { missing.append("Input Monitoring") }
        return missing
    }
}

// MARK: - Output Display State

public struct OutputDisplayState: Equatable {
    public let autoPaste: Bool
    public let safeMode: Bool
    public let lastFeedbackTitle: String
    public let lastFeedbackIcon: String
    public let isFailure: Bool
    public let isClipboardFallback: Bool

    public init(autoPaste: Bool, safeMode: Bool, lastFeedbackTitle: String,
                lastFeedbackIcon: String, isFailure: Bool, isClipboardFallback: Bool) {
        self.autoPaste = autoPaste
        self.safeMode = safeMode
        self.lastFeedbackTitle = lastFeedbackTitle
        self.lastFeedbackIcon = lastFeedbackIcon
        self.isFailure = isFailure
        self.isClipboardFallback = isClipboardFallback
    }
}

// MARK: - Transcript Display State

public struct TranscriptDisplayState: Equatable {
    public let liveText: String
    public let recentText: String?
    public let inputLevel: Double
    public let silenceCountdown: Double?
    /// Non-nil while listening whenever Live Transcription is enabled but the resolved
    /// provider for this session can't produce partial results (no streaming-capable engine
    /// installed/authorized). Lets the card distinguish "listening, no words yet" from "this
    /// session will never show live words" instead of silently showing nothing either way.
    public let unavailableReason: String?

    public init(
        liveText: String,
        recentText: String?,
        inputLevel: Double,
        silenceCountdown: Double?,
        unavailableReason: String? = nil
    ) {
        self.liveText = liveText
        self.recentText = recentText
        self.inputLevel = inputLevel
        self.silenceCountdown = silenceCountdown
        self.unavailableReason = unavailableReason
    }
}

// MARK: - Dexter Line

public struct DexterLineDisplayState: Equatable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

// MARK: - Aggregate

public struct DexExperimentalUIState: Equatable {
    public var engine: EngineDisplayState
    public var permissions: PermissionDisplayState
    public var output: OutputDisplayState
    public var transcript: TranscriptDisplayState
    public var dexterLine: DexterLineDisplayState
    public var triggerDisplayString: String
    public var modelSummary: String

    public init(engine: EngineDisplayState, permissions: PermissionDisplayState,
                output: OutputDisplayState, transcript: TranscriptDisplayState,
                dexterLine: DexterLineDisplayState, triggerDisplayString: String,
                modelSummary: String) {
        self.engine = engine
        self.permissions = permissions
        self.output = output
        self.transcript = transcript
        self.dexterLine = dexterLine
        self.triggerDisplayString = triggerDisplayString
        self.modelSummary = modelSummary
    }
}

public extension DexExperimentalUIState {
    static let placeholder = DexExperimentalUIState(
        engine: .stopped,
        permissions: PermissionDisplayState(
            micGranted: false,
            accessibilityGranted: false,
            inputMonitoringGranted: false
        ),
        output: OutputDisplayState(
            autoPaste: true,
            safeMode: false,
            lastFeedbackTitle: "",
            lastFeedbackIcon: "circle",
            isFailure: false,
            isClipboardFallback: false
        ),
        transcript: TranscriptDisplayState(
            liveText: "",
            recentText: nil,
            inputLevel: 0,
            silenceCountdown: nil
        ),
        dexterLine: DexterLineDisplayState(text: ""),
        triggerDisplayString: "Middle Mouse",
        modelSummary: "tiny.en"
    )
}
