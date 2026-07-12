import XCTest
@testable import DexDictateKit

/// Regression coverage for `TranscriptionProviderRegistry.loadAlreadyDownloadedModelsIfNeeded`:
/// the fix for "Nemotron appears inaccessible" even after a model was fully downloaded in a
/// prior app launch. `isModelLoaded`/`manager != nil` is in-memory state that resets every
/// launch while the downloaded files persist on disk — without this method, the provider
/// reported "downloaded but not loaded yet" forever unless the user manually re-clicked the
/// exact same download row every single session.
///
/// These tests exercise the *real* provider objects (no mocks — the registry hardwires
/// concrete provider properties, not an injectable protocol seam) against whatever model
/// cache genuinely exists on the machine running the suite. They perform zero network
/// activity: loading an already-downloaded model is purely local, and `XCTSkipUnless` keeps
/// this meaningful without depending on any file ever being freshly downloaded here.
@MainActor
final class TranscriptionProviderRegistryAutoLoadTests: XCTestCase {

    private func freshRegistry() -> TranscriptionProviderRegistry {
        TranscriptionProviderRegistry(whisperService: WhisperService())
    }

    /// The core fix: if Nemotron's model files are already on disk (from any prior download,
    /// in this process or a previous one) but not yet loaded into *this* registry instance,
    /// `loadAlreadyDownloadedModelsIfNeeded` must bring it to `.available()` — matching
    /// exactly what a manual re-click of the download row already does, just without
    /// requiring the user to do that every launch.
    func testAlreadyDownloadedNemotronBecomesAvailableWithoutManualRedownload() async throws {
        let registry = freshRegistry()
        let settings = AppSettings.shared
        let wasEnabled = settings.liveTranscriptionEnabled
        settings.liveTranscriptionEnabled = true
        defer { settings.liveTranscriptionEnabled = wasEnabled }

        let before = registry.nemotronProvider.healthCheck()
        try XCTSkipUnless(
            registry.nemotronProvider.modelInstallStatus == .installed,
            "No Nemotron model cached on this machine — nothing to auto-load."
        )
        XCTAssertFalse(before.isAvailable, "sanity check — a freshly constructed provider must not report available before this method runs")

        await registry.loadAlreadyDownloadedModelsIfNeeded(settings: settings)

        XCTAssertTrue(
            registry.nemotronProvider.healthCheck().isAvailable,
            "an already-downloaded Nemotron model must become available after this call, with no download and no restart"
        )
        XCTAssertEqual(
            registry.lastResolution?.selectedProviderID, .nemotron35ASRStreaming06B,
            "lastResolution must be recomputed immediately so Settings/LivePreview reflect readiness without waiting for the next dictation"
        )
    }

    /// The settings gate must actually gate — Nemotron must NOT be auto-loaded when Live
    /// Transcription is off, even if its files are sitting right there on disk. Auto-loading
    /// a feature the user has turned off would spend CPU/ANE time for nothing and violate
    /// "don't do things automatically that the user didn't ask for."
    func testNemotronIsNotAutoLoadedWhenLiveTranscriptionIsDisabled() async throws {
        let registry = freshRegistry()
        let settings = AppSettings.shared
        let wasEnabled = settings.liveTranscriptionEnabled
        settings.liveTranscriptionEnabled = false
        defer { settings.liveTranscriptionEnabled = wasEnabled }

        try XCTSkipUnless(
            registry.nemotronProvider.modelInstallStatus == .installed,
            "No Nemotron model cached on this machine — nothing to observe being skipped."
        )

        await registry.loadAlreadyDownloadedModelsIfNeeded(settings: settings)

        XCTAssertFalse(
            registry.nemotronProvider.healthCheck().isAvailable,
            "Nemotron must stay unloaded when Live Transcription is off, regardless of what's on disk"
        )
    }

    /// Parakeet is a primary-engine candidate, independent of the Live Transcription /
    /// Command Mode settings that gate Nemotron/Moonshine — it must auto-load whenever its
    /// files are present, with no other setting required.
    func testAlreadyDownloadedParakeetBecomesAvailableIndependentOfLiveTranscriptionSetting() async throws {
        let registry = freshRegistry()
        let settings = AppSettings.shared
        let wasEnabled = settings.liveTranscriptionEnabled
        settings.liveTranscriptionEnabled = false
        defer { settings.liveTranscriptionEnabled = wasEnabled }

        try XCTSkipUnless(
            registry.parakeetProvider.modelInstallStatus == .installed,
            "No Parakeet model cached on this machine — nothing to auto-load."
        )

        await registry.loadAlreadyDownloadedModelsIfNeeded(settings: settings)

        XCTAssertTrue(
            registry.parakeetProvider.healthCheck().isAvailable,
            "Parakeet must auto-load regardless of the Live Transcription toggle"
        )
    }

    /// No cached model anywhere for a given provider must not crash or hang — a plain no-op,
    /// leaving the provider exactly as unavailable as it started.
    func testNoOpWhenNothingIsInstalled() async {
        let registry = freshRegistry()
        await registry.loadAlreadyDownloadedModelsIfNeeded(settings: AppSettings.shared)
        // Reaching this line at all is the assertion — no crash, no hang.
        XCTAssertNotNil(registry.lastResolution, "resolveActiveProvider must always run and publish a result")
    }
}
