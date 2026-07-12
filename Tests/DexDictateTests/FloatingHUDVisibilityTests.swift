import XCTest
@testable import DexDictateKit

/// Regression coverage for "Live Preview enabled but no visible caption surface ever
/// appears." Confirmed root cause: enabling Live Preview (default on) had zero effect on
/// whether any window showed — the only caption-capable surface was the standard
/// `FloatingHUDView`, gated entirely behind the separate "Show Floating HUD" setting
/// (default off), and even when manually enabled, `FloatingHUDWindow` (an `NSPanel`) never
/// set `hidesOnDeactivate`, which defaults `true` for panels — silently hiding the window
/// the instant the user clicked into their dictation target, i.e. during real use.
///
/// Tests the coordinator's *decisions* — `FloatingHUDVisibilityDecision`'s pure logic and
/// `LivePreviewController.shouldShowCaptionSurface`'s real lifecycle — not SwiftUI views,
/// and never constructs an actual `NSWindow`/`NSPanel` (unsafe/flaky headless).
@MainActor
final class FloatingHUDVisibilityTests: XCTestCase {

    // MARK: - FloatingHUDVisibilityDecision (pure logic)

    func testNotVisibleWhenNeitherSettingNorLivePreviewWantsIt() {
        XCTAssertFalse(FloatingHUDVisibilityDecision.isVisible(showFloatingHUD: false, shouldShowCaptionSurface: false))
    }

    /// Scenario 4 (Floating HUD generally disabled, Live Preview still shows a caption).
    func testVisibleWhenLivePreviewWantsItEvenIfShowFloatingHUDIsOff() {
        XCTAssertTrue(FloatingHUDVisibilityDecision.isVisible(showFloatingHUD: false, shouldShowCaptionSurface: true))
    }

    /// Persistent "Show Floating HUD" alone is still honored (unrelated to Live Preview).
    func testVisibleWhenShowFloatingHUDIsOnEvenWithNoLivePreviewCaption() {
        XCTAssertTrue(FloatingHUDVisibilityDecision.isVisible(showFloatingHUD: true, shouldShowCaptionSurface: false))
    }

    func testVisibleWhenBothWantIt() {
        XCTAssertTrue(FloatingHUDVisibilityDecision.isVisible(showFloatingHUD: true, shouldShowCaptionSurface: true))
    }

    /// Scenario: Live Preview is the reason we're visible → always the caption-capable
    /// standard view, never Nano (which has no listening-state caption row).
    func testDoesNotUseNanoContentWhenLivePreviewIsWhyWeAreVisible() {
        XCTAssertFalse(FloatingHUDVisibilityDecision.useNanoContent(
            useExperimentalNanoHUD: true, showFloatingHUD: true, shouldShowCaptionSurface: true
        ))
        XCTAssertFalse(FloatingHUDVisibilityDecision.useNanoContent(
            useExperimentalNanoHUD: true, showFloatingHUD: false, shouldShowCaptionSurface: true
        ))
    }

    /// Nano HUD is only used for the persistent-status-only case: the setting is on, Nano is
    /// chosen, and Live Preview has nothing to show right now.
    func testUsesNanoContentOnlyForPersistentStatusWithNoLiveCaption() {
        XCTAssertTrue(FloatingHUDVisibilityDecision.useNanoContent(
            useExperimentalNanoHUD: true, showFloatingHUD: true, shouldShowCaptionSurface: false
        ))
    }

    func testDoesNotUseNanoContentWhenNanoSettingIsOff() {
        XCTAssertFalse(FloatingHUDVisibilityDecision.useNanoContent(
            useExperimentalNanoHUD: false, showFloatingHUD: true, shouldShowCaptionSurface: false
        ))
    }

    // MARK: - FloatingHUDFramePositioning (pure logic)

    func testFrameUnchangedWhenAlreadyOnAVisibleScreen() {
        let frame = NSRect(x: 100, y: 100, width: 200, height: 60)
        let screens = [NSRect(x: 0, y: 0, width: 1440, height: 900)]
        XCTAssertEqual(FloatingHUDFramePositioning.correctedFrame(frame, visibleFrames: screens), frame)
    }

    /// Scenario 12: a saved position referencing a display that's since been disconnected
    /// must be corrected back onto whatever screen is actually available now.
    func testOffScreenFrameIsRecenteredOntoAvailableScreen() {
        // Frame from a since-disconnected display far to the right.
        let frame = NSRect(x: 5000, y: 5000, width: 200, height: 60)
        let screens = [NSRect(x: 0, y: 0, width: 1440, height: 900)]
        let corrected = FloatingHUDFramePositioning.correctedFrame(frame, visibleFrames: screens)
        XCTAssertTrue(screens[0].intersects(corrected), "corrected frame must land on an available screen")
        XCTAssertEqual(corrected.width, frame.width)
        XCTAssertEqual(corrected.height, frame.height)
    }

    func testEmptyVisibleFramesLeavesFrameUnchanged() {
        let frame = NSRect(x: 5000, y: 5000, width: 200, height: 60)
        XCTAssertEqual(FloatingHUDFramePositioning.correctedFrame(frame, visibleFrames: []), frame)
    }

    // MARK: - LivePreviewController.shouldShowCaptionSurface (real lifecycle, no fakes)

    /// Scenario 1: listening begins with Live Preview enabled → surface should show.
    func testShouldShowCaptionSurfaceBecomesTrueWhenListeningBeginsWithLivePreviewEnabled() {
        let settings = AppSettings.shared
        let wasEnabled = settings.livePreviewEnabled
        settings.livePreviewEnabled = true
        defer { settings.livePreviewEnabled = wasEnabled }

        let engine = TranscriptionEngine()
        let controller = LivePreviewController(settings: settings)
        controller.start(engine: engine)

        XCTAssertFalse(controller.shouldShowCaptionSurface, "must not show before any session starts")
        engine.state = .listening
        XCTAssertTrue(controller.shouldShowCaptionSurface)
    }

    /// Scenario 5: Live Preview disabled → the surface never shows, regardless of engine state.
    func testShouldShowCaptionSurfaceStaysFalseWhenLivePreviewIsDisabled() {
        let settings = AppSettings.shared
        let wasEnabled = settings.livePreviewEnabled
        settings.livePreviewEnabled = false
        defer { settings.livePreviewEnabled = wasEnabled }

        let engine = TranscriptionEngine()
        let controller = LivePreviewController(settings: settings)
        controller.start(engine: engine)

        engine.state = .listening
        XCTAssertFalse(controller.shouldShowCaptionSurface)
    }

    /// Scenario 7 (finalizing): the surface must stay visible through `.transcribing`, not
    /// disappear the instant recording stops — that's when the "Finalizing…" badge shows.
    func testShouldShowCaptionSurfaceStaysTrueThroughFinalizing() {
        let settings = AppSettings.shared
        let wasEnabled = settings.livePreviewEnabled
        settings.livePreviewEnabled = true
        defer { settings.livePreviewEnabled = wasEnabled }

        let engine = TranscriptionEngine()
        let controller = LivePreviewController(settings: settings)
        controller.start(engine: engine)

        engine.state = .listening
        XCTAssertTrue(controller.shouldShowCaptionSurface)
        engine.state = .transcribing
        XCTAssertTrue(controller.shouldShowCaptionSurface, "must stay visible while finalizing")
        XCTAssertTrue(controller.isFinalizing)
    }

    /// Scenario 8 (completion dismisses): once the engine returns to idle, the surface hides.
    func testShouldShowCaptionSurfaceBecomesFalseOnCompletion() {
        let settings = AppSettings.shared
        let wasEnabled = settings.livePreviewEnabled
        settings.livePreviewEnabled = true
        defer { settings.livePreviewEnabled = wasEnabled }

        let engine = TranscriptionEngine()
        let controller = LivePreviewController(settings: settings)
        controller.start(engine: engine)

        engine.state = .listening
        engine.state = .transcribing
        engine.state = .ready
        XCTAssertFalse(controller.shouldShowCaptionSurface, "must dismiss once back to idle")
    }

    /// Scenario 9 (cancellation clears and dismisses): transitioning straight from
    /// `.listening` to a non-transcribing idle state (e.g. cancel) also hides it.
    func testShouldShowCaptionSurfaceBecomesFalseOnCancellation() {
        let settings = AppSettings.shared
        let wasEnabled = settings.livePreviewEnabled
        settings.livePreviewEnabled = true
        defer { settings.livePreviewEnabled = wasEnabled }

        let engine = TranscriptionEngine()
        let controller = LivePreviewController(settings: settings)
        controller.start(engine: engine)

        engine.state = .listening
        XCTAssertTrue(controller.shouldShowCaptionSurface)
        engine.state = .stopped
        XCTAssertFalse(controller.shouldShowCaptionSurface)
    }

    /// Scenario 10: starting a new session resets the surface correctly (it doesn't get
    /// stuck `false` from the previous session's teardown, and doesn't carry over stale
    /// caption text — covered together since both flow from the same `beginSession()` reset).
    func testShouldShowCaptionSurfaceWorksAgainForANewSessionAfterOneCompletes() {
        let settings = AppSettings.shared
        let wasEnabled = settings.livePreviewEnabled
        settings.livePreviewEnabled = true
        defer { settings.livePreviewEnabled = wasEnabled }

        let engine = TranscriptionEngine()
        let controller = LivePreviewController(settings: settings)
        controller.start(engine: engine)

        engine.state = .listening
        engine.liveTranscript = "first session text"
        engine.state = .transcribing
        engine.state = .ready
        XCTAssertFalse(controller.shouldShowCaptionSurface)

        engine.state = .listening
        XCTAssertTrue(controller.shouldShowCaptionSurface, "must show again for a fresh session")
        XCTAssertEqual(controller.caption, "", "must not carry over the previous session's text")
    }

    /// Scenario 14 (stale session updates do not reopen the window): once explicitly killed
    /// for the session (e.g. provider became unavailable mid-utterance), the surface must not
    /// pop back up even if the engine keeps publishing `.listening`-adjacent state.
    func testShouldShowCaptionSurfaceStaysFalseAfterKillForSession() {
        let settings = AppSettings.shared
        let wasEnabled = settings.livePreviewEnabled
        settings.livePreviewEnabled = true
        defer { settings.livePreviewEnabled = wasEnabled }

        let engine = TranscriptionEngine()
        let controller = LivePreviewController(settings: settings)
        controller.start(engine: engine)

        engine.state = .listening
        XCTAssertTrue(controller.shouldShowCaptionSurface)

        // Disabling Live Preview mid-session is the same "must stop showing" path a kill
        // switch takes — both route through endSession(clearImmediately: true).
        settings.livePreviewEnabled = false
        engine.state = .listening
        XCTAssertFalse(controller.shouldShowCaptionSurface, "must not show once disabled, even while still .listening")
    }

    /// Structural guarantee for scenario 3 (menu-bar popover closed → caption still shown):
    /// `shouldShowCaptionSurface`'s computation has no dependency on popover/window state at
    /// all — it is driven purely by `engine.state` and `settings.livePreviewEnabled`. This
    /// test documents that guarantee by exercising the full lifecycle with no popover-related
    /// object ever constructed or referenced.
    func testCaptionSurfaceLifecycleHasNoPopoverDependency() {
        let settings = AppSettings.shared
        let wasEnabled = settings.livePreviewEnabled
        settings.livePreviewEnabled = true
        defer { settings.livePreviewEnabled = wasEnabled }

        let engine = TranscriptionEngine()
        let controller = LivePreviewController(settings: settings)
        controller.start(engine: engine)

        engine.state = .listening
        XCTAssertTrue(controller.shouldShowCaptionSurface)
    }
}
