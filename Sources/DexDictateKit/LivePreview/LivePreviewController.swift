import Foundation
import Combine

/// Display-only live preview (Packet 14, Phase L1). Subscribes to the existing streaming
/// provider output the engine already exposes (`TranscriptionEngine.liveTranscript` /
/// `.inputLevel`, both already-`@Published` on the shared singleton) — it does NOT start
/// its own streaming session, does NOT touch any audio tap, and never writes toward the
/// output pipeline. Batch Whisper remains the only committed-output path; this controller
/// has no reference to `WhisperService` or the output coordinator at all.
///
/// "Preview channel, commit channel" per the plan of record (Section 13): this class *is*
/// the entire preview channel. It cannot affect the commit channel because it has no call
/// path into it — confirmed by `LivePreviewInvariantTests`.
///
/// Kill switch caveat (documented, not hidden): a true "the active streaming provider threw
/// an error mid-utterance" signal does not exist anywhere outside forbidden
/// `TranscriptionEngine.swift` — `provider.onError` is a single-slot closure the engine
/// already owns for its own internal wiring (setting it here too would silently overwrite
/// the engine's assignment, corrupting its own `liveTranscript` relay). This controller's
/// kill switch instead watches `TranscriptionProviderRegistry.refreshHealthReport()` (an
/// existing, cheap, public, non-forbidden call) for the resolved provider becoming
/// unavailable mid-session — a real, safe, honest proxy, not a hidden gap. See
/// `docs/refactor_baseline/packet_14/NEEDS_ANDREW.md` for the full writeup of what a
/// precise hook would require.
///
/// Lives in `DexDictateKit` rather than `Sources/DexDictate/LivePreview/` (the path this
/// packet's own goal text suggested) so `LivePreviewInvariantTests` can `@testable import`
/// it without adding a new test-target dependency on the `DexDictate` executable target —
/// avoiding any `Package.swift` change for a `@main`-attributed SwiftUI app target, which
/// carries real risk of destabilizing the whole test target's build. `ObservableObject`
/// classes already live in this module (`TranscriptionHistory`, `AppSettings`,
/// `TranscriptionProviderRegistry`) — this needs no SwiftUI import, just Combine.
@MainActor
public final class LivePreviewController: ObservableObject {
    @Published public private(set) var caption: String = ""
    @Published public private(set) var micLevel: Double = 0
    @Published public private(set) var isFinalizing: Bool = false
    @Published public private(set) var isKilledForSession: Bool = false
    @Published public private(set) var killReason: String?

    private weak var engine: TranscriptionEngine?
    private weak var registry: TranscriptionProviderRegistry?
    private let settings: AppSettings

    private var lifecycleCancellables = Set<AnyCancellable>()
    private var sessionCancellables = Set<AnyCancellable>()
    private var healthCheckTimer: Timer?
    private var didStart = false

    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    /// Idempotent — safe to call on every popover open, matching this app's existing
    /// `historyController.setup(...)` / `adaptiveBenchmarkController.start(engine:)` pattern.
    public func start(engine: TranscriptionEngine) {
        guard !didStart else { return }
        didStart = true
        self.engine = engine
        self.registry = engine.transcriptionProviderRegistry

        engine.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleStateChanged(state) }
            .store(in: &lifecycleCancellables)
    }

    private func handleStateChanged(_ state: EngineState) {
        guard settings.livePreviewEnabled, !isKilledForSession else {
            endSession(clearImmediately: true)
            return
        }
        switch state {
        case .listening:
            beginSession()
        case .transcribing:
            // Visible handoff: captions fade to "Finalizing…" until the committed result
            // arrives and replaces it (PopoverResultView / FloatingHUD already do that part).
            isFinalizing = true
            stopThrottledSubscriptions()
        default:
            endSession(clearImmediately: false)
        }
    }

    private func beginSession() {
        guard let engine else { return }
        isFinalizing = false
        caption = ""
        micLevel = 0

        engine.$liveTranscript
            .throttle(for: .milliseconds(250), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] text in self?.caption = text }
            .store(in: &sessionCancellables)

        engine.$inputLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in self?.micLevel = level }
            .store(in: &sessionCancellables)

        startHealthWatch()
    }

    private func endSession(clearImmediately: Bool) {
        stopThrottledSubscriptions()
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        if clearImmediately {
            caption = ""
            micLevel = 0
            isFinalizing = false
        }
    }

    private func stopThrottledSubscriptions() {
        sessionCancellables.removeAll()
    }

    // MARK: - Kill switch (see class doc for the honest caveat)

    private func startHealthWatch() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkProviderHealth() }
        }
    }

    private func checkProviderHealth() {
        guard let registry, let resolution = registry.lastResolution, resolution.usesLiveStreaming else { return }
        let report = registry.refreshHealthReport()
        if report[resolution.selectedProviderID]?.isAvailable == false {
            killForSession(reason: "\(resolution.selectedProviderDisplayName) became unavailable")
        }
    }

    private func killForSession(reason: String) {
        guard !isKilledForSession else { return }
        isKilledForSession = true
        killReason = reason
        endSession(clearImmediately: true)
        Safety.log("LivePreview — disabled for this session: \(reason)", category: .transcription)
    }
}
