import SwiftUI
import AVFAudio
import DexDictateKit

@MainActor
final class SilverTongueCoordinator: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var voices: [SilverTongueVoice] = []
    @Published private(set) var isLoadingVoices = false
    @Published private(set) var isSynthesizing = false
    @Published private(set) var currentAudioURL: URL?
    @Published private(set) var isPlaying = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published private(set) var selectedVoiceID: String
    @Published private(set) var speechRate: Double

    private let settings: AppSettings
    private let serviceManager: SilverTongueServiceManager
    private let client: SilverTongueClient
    private var player: AVAudioPlayer?

    init(settings: AppSettings, serviceManager: SilverTongueServiceManager) {
        self.settings = settings
        self.serviceManager = serviceManager
        self.client = serviceManager.client
        self.selectedVoiceID = settings.silverTongueSelectedVoiceID
        self.speechRate = settings.silverTongueSpeed
        super.init()
    }

    func prepare() async {
        errorMessage = nil
        guard settings.silverTongueEnabled else {
            infoMessage = "SilverTongue is disabled. Enable it in Quick Settings."
            return
        }

        await serviceManager.startIfNeeded()
        guard serviceManager.isReady else {
            if case .error(let message) = serviceManager.state {
                errorMessage = message
            }
            return
        }

        await refreshVoices()
    }

    func refreshVoices() async {
        isLoadingVoices = true
        defer { isLoadingVoices = false }

        do {
            let loadedVoices = try await client.listVoices()
                .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
            voices = loadedVoices

            guard !loadedVoices.isEmpty else {
                infoMessage = "No local voices found. Install voices from Manage Voices."
                return
            }

            let existingSelectionStillValid = loadedVoices.contains(where: { $0.id == selectedVoiceID })
            if !existingSelectionStillValid {
                updateSelectedVoice(loadedVoices[0].id)
            } else {
                settings.silverTongueSelectedVoiceID = selectedVoiceID
            }
            infoMessage = nil
        } catch {
            errorMessage = "Failed to load voices: \(error.localizedDescription)"
        }
    }

    func updateSelectedVoice(_ voiceID: String) {
        selectedVoiceID = voiceID
        settings.silverTongueSelectedVoiceID = voiceID
    }

    func updateSpeechRate(_ value: Double) {
        speechRate = value
        settings.silverTongueSpeed = value
    }

    func readLastDictation(from history: TranscriptionHistory) async {
        guard let latest = history.items.first else {
            infoMessage = "No dictation is available yet."
            return
        }
        await readBack(text: latest.text)
    }

    func readBack(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            infoMessage = "Cannot synthesize empty text."
            return
        }
        guard settings.silverTongueEnabled else {
            infoMessage = "SilverTongue is disabled. Enable it in Quick Settings."
            return
        }

        await serviceManager.startIfNeeded()
        guard serviceManager.isReady else {
            if case .error(let message) = serviceManager.state {
                errorMessage = message
            }
            return
        }

        if voices.isEmpty {
            await refreshVoices()
        }
        guard !voices.isEmpty else {
            return
        }

        let selected = voices.contains(where: { $0.id == selectedVoiceID }) ? selectedVoiceID : voices[0].id
        updateSelectedVoice(selected)

        isSynthesizing = true
        defer { isSynthesizing = false }

        do {
            let audioURL = try await client.synthesize(
                text: trimmed,
                voiceID: selected,
                speed: speechRate
            )
            try playAudio(at: audioURL)
            infoMessage = "Read-back complete."
            errorMessage = nil
        } catch {
            errorMessage = "Read-back failed: \(error.localizedDescription)"
        }
    }

    func playCurrent() {
        guard let player else { return }
        player.play()
        isPlaying = true
    }

    func pausePlayback() {
        player?.pause()
        isPlaying = false
    }

    func stopPlayback() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
    }

    func launchManageVoices() {
        do {
            try serviceManager.launchManageVoices()
            infoMessage = "Opened SilverTongue voice manager."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func showSettingsHint() {
        infoMessage = "Use DexDictate Quick Settings to configure SilverTongue paths and enablement."
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
        }
    }

    private func playAudio(at url: URL) throws {
        stopPlayback()
        let nextPlayer = try AVAudioPlayer(contentsOf: url)
        nextPlayer.delegate = self
        nextPlayer.prepareToPlay()
        nextPlayer.play()
        player = nextPlayer
        currentAudioURL = url
        isPlaying = true
    }
}

struct SilverTongueView: View {
    @ObservedObject var coordinator: SilverTongueCoordinator
    @ObservedObject var serviceManager: SilverTongueServiceManager
    @ObservedObject var history: TranscriptionHistory
    @ObservedObject var settings: AppSettings
    var onOpenSettings: (() -> Void)?

    @State private var hasPrepared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SilverTongue")
                    .font(.headline)
                Spacer()
                serviceStateBadge
            }

            if settings.silverTongueEnabled {
                controlPanel
            } else {
                Text("SilverTongue is disabled. Enable it from DexDictate Quick Settings.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            messagePanel

            if !history.items.isEmpty {
                recentDictations
            }

            footerActions
        }
        .padding(14)
        .frame(minWidth: 420, minHeight: 480)
        .background(Color.black.opacity(0.86))
        .onAppear {
            guard !hasPrepared else { return }
            hasPrepared = true
            Task { await coordinator.prepare() }
        }
    }

    @ViewBuilder
    private var controlPanel: some View {
        Button("Read Last Dictation") {
            Task { await coordinator.readLastDictation(from: history) }
        }
        .buttonStyle(.borderedProminent)
        .disabled(history.items.isEmpty || coordinator.isSynthesizing || serviceManager.state == .starting)

        VStack(alignment: .leading, spacing: 6) {
            Text("Voice")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
            if coordinator.voices.isEmpty {
                Text(coordinator.isLoadingVoices ? "Loading voices..." : "No voices loaded.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                Picker(
                    "Voice",
                    selection: Binding(
                        get: { coordinator.selectedVoiceID },
                        set: { coordinator.updateSelectedVoice($0) }
                    )
                ) {
                    ForEach(coordinator.voices) { voice in
                        Text("\(voice.id) (\(voice.language))").tag(voice.id)
                    }
                }
                .labelsHidden()
            }
        }

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Speed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(String(format: "%.2fx", coordinator.speechRate))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.65))
            }
            Slider(
                value: Binding(
                    get: { coordinator.speechRate },
                    set: { coordinator.updateSpeechRate($0) }
                ),
                in: 0.6...1.6,
                step: 0.05
            )
            .tint(.cyan)
        }

        HStack(spacing: 10) {
            Button(coordinator.isPlaying ? "Pause" : "Play") {
                coordinator.isPlaying ? coordinator.pausePlayback() : coordinator.playCurrent()
            }
            .buttonStyle(.bordered)
            .disabled(coordinator.currentAudioURL == nil)

            Button("Stop") {
                coordinator.stopPlayback()
            }
            .buttonStyle(.bordered)
            .disabled(coordinator.currentAudioURL == nil)

            Button("Refresh Voices") {
                Task { await coordinator.refreshVoices() }
            }
            .buttonStyle(.bordered)
            .disabled(coordinator.isLoadingVoices || serviceManager.state == .starting)
        }

        if let audioURL = coordinator.currentAudioURL {
            Text(audioURL.lastPathComponent)
                .font(.caption2.monospaced())
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    @ViewBuilder
    private var messagePanel: some View {
        if coordinator.isSynthesizing || coordinator.isLoadingVoices || serviceManager.state == .starting {
            HStack(spacing: 8) {
                ProgressView()
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }

        if let error = coordinator.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }

        if let info = coordinator.infoMessage {
            Text(info)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recentDictations: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Dictations")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(history.items.prefix(10))) { item in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.text)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(2)
                                Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Button("Replay") {
                                Task { await coordinator.readBack(text: item.text) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(coordinator.isSynthesizing || serviceManager.state == .starting)
                        }
                        .padding(6)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxHeight: 220)
        }
    }

    private var footerActions: some View {
        HStack {
            Button("Manage Voices") {
                coordinator.launchManageVoices()
            }
            .buttonStyle(.bordered)

            Button("Settings") {
                onOpenSettings?()
                coordinator.showSettingsHint()
            }
            .buttonStyle(.bordered)

            Spacer()
            Text("Local-only • 127.0.0.1")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var serviceStateBadge: some View {
        Text(serviceStateLabel)
            .font(.caption2.monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(serviceStateColor.opacity(0.18))
            .foregroundStyle(serviceStateColor)
            .clipShape(Capsule())
    }

    private var serviceStateLabel: String {
        switch serviceManager.state {
        case .dormant:
            return "dormant"
        case .starting:
            return "starting"
        case .ready:
            return "ready"
        case .error:
            return "error"
        }
    }

    private var serviceStateColor: Color {
        switch serviceManager.state {
        case .dormant:
            return .white.opacity(0.8)
        case .starting:
            return .yellow
        case .ready:
            return .green
        case .error:
            return .red
        }
    }

    private var statusLine: String {
        if serviceManager.state == .starting {
            return "Starting SilverTongue service..."
        }
        if coordinator.isLoadingVoices {
            return "Loading voices..."
        }
        return "Synthesizing..."
    }
}
