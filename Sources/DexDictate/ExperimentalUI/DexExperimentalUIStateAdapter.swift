import SwiftUI
import Combine
import DexDictateKit

/// Reads from production singletons and adapts them into `DexExperimentalUIState`.
/// Views in the experimental path observe this adapter instead of depending directly
/// on every production service.
@MainActor
final class DexExperimentalUIStateAdapter: ObservableObject {
    @Published private(set) var state: DexExperimentalUIState = .placeholder

    private let engine: TranscriptionEngine
    private let permissionManager: PermissionManager
    private let settings: AppSettings
    private let profileManager: ProfileManager

    private var cancellables = Set<AnyCancellable>()

    init(
        engine: TranscriptionEngine,
        permissionManager: PermissionManager,
        settings: AppSettings,
        profileManager: ProfileManager
    ) {
        self.engine = engine
        self.permissionManager = permissionManager
        self.settings = settings
        self.profileManager = profileManager
        rebuild()
        subscribe()
    }

    private func subscribe() {
        engine.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)

        permissionManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)

        profileManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)
    }

    private func rebuild() {
        let engineDisplay: EngineDisplayState
        switch engine.state {
        case .stopped:      engineDisplay = .stopped
        case .initializing: engineDisplay = .initializing
        case .ready:        engineDisplay = .ready
        case .listening:    engineDisplay = .listening
        case .transcribing: engineDisplay = .transcribing
        case .error:        engineDisplay = .error(engine.statusText)
        }

        let feedback = engine.resultFeedback
        let isClipboard: Bool
        if case .copiedOnlySensitiveContext = feedback { isClipboard = true } else { isClipboard = false }
        let isFailure: Bool
        if case .noSpeechDetected = feedback { isFailure = true } else { isFailure = false }

        state = DexExperimentalUIState(
            engine: engineDisplay,
            permissions: PermissionDisplayState(
                micGranted: permissionManager.microphoneGranted,
                accessibilityGranted: permissionManager.accessibilityGranted,
                inputMonitoringGranted: permissionManager.inputMonitoringGranted
            ),
            output: OutputDisplayState(
                autoPaste: settings.autoPaste,
                safeMode: settings.safeModeEnabled,
                lastFeedbackTitle: feedback.title,
                lastFeedbackIcon: feedback.symbolName,
                isFailure: isFailure,
                isClipboardFallback: isClipboard
            ),
            transcript: TranscriptDisplayState(
                liveText: engine.liveTranscript,
                recentText: engine.history.items.first?.text,
                inputLevel: engine.inputLevel,
                silenceCountdown: engine.silenceCountdown
            ),
            dexterLine: DexterLineDisplayState(
                text: profileManager.currentFlavorLine?.text ?? ""
            ),
            triggerDisplayString: settings.userShortcut.displayString,
            modelSummary: settings.activeWhisperModelID
        )
    }
}
