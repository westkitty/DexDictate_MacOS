import XCTest
@testable import DexDictateKit

/// Coverage for `ModelSelectionActions.liveStreamingStatus` — the exact-vocabulary status
/// ("Ready — Nemotron", "Ready — Apple Speech", "Nemotron loading", "Final-only fallback —
/// Whisper" with a specific reason) the Settings UI surfaces for the live partial-caption
/// provider. Complements `TranscriptionProviderRegistryAutoLoadTests` (which covers the
/// underlying auto-load fix) and `LivePreviewInvariantTests` (which covers the preview
/// controller's honest-unavailable-reason behavior) — this file is about the vocabulary
/// mapping layer specifically.
@MainActor
final class LiveStreamingStatusVocabularyTests: XCTestCase {

    private func freshRegistry() -> TranscriptionProviderRegistry {
        TranscriptionProviderRegistry(whisperService: WhisperService())
    }

    func testLiveTranscriptionOffReportsOffRegardlessOfProviderHealth() {
        let registry = freshRegistry()
        let settings = AppSettings.shared
        let wasEnabled = settings.liveTranscriptionEnabled
        settings.liveTranscriptionEnabled = false
        defer { settings.liveTranscriptionEnabled = wasEnabled }

        let status = ModelSelectionActions.liveStreamingStatus(settings: settings, registry: registry)
        XCTAssertEqual(status, .liveTranscriptionOff)
        XCTAssertEqual(status.headline, "Live Transcription is off")
        XCTAssertNil(status.detail)
    }

    func testReadyNemotronWhenNemotronHealthy() throws {
        let registry = freshRegistry()
        let settings = AppSettings.shared
        let wasEnabled = settings.liveTranscriptionEnabled
        settings.liveTranscriptionEnabled = true
        defer { settings.liveTranscriptionEnabled = wasEnabled }

        try XCTSkipUnless(
            registry.nemotronProvider.modelInstallStatus == .installed,
            "No Nemotron model cached on this machine — cannot exercise the .readyNemotron branch."
        )
        await_loadNemotronIfPossible(registry: registry, settings: settings)
        try XCTSkipUnless(
            registry.nemotronProvider.healthCheck().isAvailable,
            "Nemotron model is on disk but did not become available in this environment."
        )

        let status = ModelSelectionActions.liveStreamingStatus(settings: settings, registry: registry)
        XCTAssertEqual(status, .readyNemotron)
        XCTAssertEqual(status.headline, "Ready — Nemotron")
        XCTAssertNil(status.detail)
    }

    func testReadyAppleSpeechWhenNemotronUnavailableButAppleSpeechAuthorized() throws {
        let registry = freshRegistry()
        let settings = AppSettings.shared
        let wasEnabled = settings.liveTranscriptionEnabled
        settings.liveTranscriptionEnabled = true
        defer { settings.liveTranscriptionEnabled = wasEnabled }

        try XCTSkipIf(
            registry.nemotronProvider.modelInstallStatus == .installed,
            "Nemotron is installed on this machine — cannot exercise the Apple-Speech-preferred branch without it."
        )
        _ = registry.refreshHealthReport()
        try XCTSkipUnless(
            registry.healthReport[.appleSpeech]?.isAvailable == true,
            "Apple Speech isn't authorized/available in this environment."
        )

        let status = ModelSelectionActions.liveStreamingStatus(settings: settings, registry: registry)
        XCTAssertEqual(status, .readyAppleSpeech)
        XCTAssertEqual(status.headline, "Ready — Apple Speech")
    }

    func testFinalOnlyFallbackReportsNemotronNotInstalledWhenNeitherStreamingProviderIsReady() throws {
        let registry = freshRegistry()
        let settings = AppSettings.shared
        let wasEnabled = settings.liveTranscriptionEnabled
        settings.liveTranscriptionEnabled = true
        defer { settings.liveTranscriptionEnabled = wasEnabled }

        try XCTSkipIf(
            registry.nemotronProvider.modelInstallStatus == .installed,
            "Nemotron is installed on this machine — cannot exercise the not-installed branch."
        )
        _ = registry.refreshHealthReport()
        try XCTSkipIf(
            registry.healthReport[.appleSpeech]?.isAvailable == true,
            "Apple Speech is available in this environment — cannot exercise the fallback branch."
        )

        let status = ModelSelectionActions.liveStreamingStatus(settings: settings, registry: registry)
        XCTAssertEqual(status, .finalOnlyFallback(reason: .nemotronNotInstalled))
        XCTAssertEqual(status.headline, "Final-only fallback — Whisper")
        XCTAssertEqual(status.detail, "Nemotron model not installed")
    }

    func testFinalOnlyFallbackReportsSpeechPermissionRequiredWhenNemotronInstalledButNeitherHealthy() throws {
        let registry = freshRegistry()
        let settings = AppSettings.shared
        let wasEnabled = settings.liveTranscriptionEnabled
        settings.liveTranscriptionEnabled = true
        defer { settings.liveTranscriptionEnabled = wasEnabled }

        try XCTSkipUnless(
            registry.nemotronProvider.modelInstallStatus == .installed,
            "No Nemotron model cached on this machine — cannot exercise the installed-but-unhealthy branch."
        )
        _ = registry.refreshHealthReport()
        try XCTSkipIf(
            registry.nemotronProvider.healthCheck().isAvailable,
            "Nemotron became available (auto-loaded) — cannot exercise the not-yet-loaded branch here."
        )
        try XCTSkipIf(
            registry.healthReport[.appleSpeech]?.isAvailable == true,
            "Apple Speech is available in this environment — cannot exercise the fallback branch."
        )

        let status = ModelSelectionActions.liveStreamingStatus(settings: settings, registry: registry)
        XCTAssertEqual(status, .finalOnlyFallback(reason: .speechPermissionRequired))
        XCTAssertEqual(status.detail, "Speech Recognition permission required")
    }

    private func await_loadNemotronIfPossible(registry: TranscriptionProviderRegistry, settings: AppSettings) {
        let expectation = expectation(description: "load")
        Task {
            await registry.loadAlreadyDownloadedModelsIfNeeded(settings: settings)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 60)
    }
}

// MARK: - AppleSpeechTranscriptionProvider.AuthorizationState

@MainActor
final class AppleSpeechAuthorizationStateTests: XCTestCase {

    /// Pure mapping sanity — `authorizationState` must always resolve to one of the four
    /// cases and never crash, regardless of the TCC decision in whatever environment the
    /// suite runs in (dev machine, CI sandbox, etc.).
    func testAuthorizationStateIsAlwaysOneOfTheFourKnownCases() {
        let state = AppleSpeechTranscriptionProvider.authorizationState
        XCTAssertTrue([.notDetermined, .authorized, .denied, .restricted].contains(state))
    }
}

// MARK: - NemotronTranscriptionProvider basic invariants (no network required)

@MainActor
final class NemotronTranscriptionProviderBasicInvariantTests: XCTestCase {

    func testFreshProviderIsNotSessionActive() {
        let provider = NemotronTranscriptionProvider()
        XCTAssertFalse(provider.isSessionActive)
        XCTAssertFalse(provider.isDownloading)
    }

    func testStopTranscriptionWithoutStartingIsASafeNoOp() {
        let provider = NemotronTranscriptionProvider()
        provider.stopTranscription()
        XCTAssertFalse(provider.isSessionActive)
    }

    func testHealthCheckReasonMentionsNotDownloadedWhenModelsAreAbsent() throws {
        let provider = NemotronTranscriptionProvider()
        try XCTSkipIf(
            provider.modelInstallStatus == .installed,
            "Nemotron model is cached on this machine — cannot exercise the not-downloaded reason text."
        )
        let health = provider.healthCheck()
        XCTAssertFalse(health.isAvailable)
        XCTAssertTrue((health.reason ?? "").localizedCaseInsensitiveContains("download"))
    }
}
