import AppKit

/// Pure, dependency-free visibility rules for `FloatingHUDController` (in the `DexDictate`
/// executable target) — kept here, in `DexDictateKit`, rather than alongside the controller
/// itself, so `Tests/DexDictateTests` can exercise every combination of inputs directly via
/// `@testable import DexDictateKit` without adding the `DexDictate` executable target as a
/// test dependency (the same reasoning `LivePreviewController` itself documents). Constructing
/// an actual `NSWindow`/`NSPanel` in a headless test run is unsafe/flaky, so none of this
/// touches a real window.
public enum FloatingHUDVisibilityDecision {
    /// The window should be on screen if either the user's persistent "Show Floating HUD"
    /// setting is on, or Live Preview currently has something worth showing (independent of
    /// that setting — see `LivePreviewController.shouldShowCaptionSurface`'s doc comment for
    /// why enabling Live Preview must not depend on a second, unrelated toggle).
    public static func isVisible(showFloatingHUD: Bool, shouldShowCaptionSurface: Bool) -> Bool {
        showFloatingHUD || shouldShowCaptionSurface
    }

    /// The compact Nano HUD layout has no room for a multi-line live caption (see
    /// `DexNanoHUDView` — it only ever shows `engine.liveTranscript` post-recording, during
    /// `.transcribing`, never while `.listening`). So whenever Live Preview itself is the
    /// reason the window is visible, always render the standard, caption-capable
    /// `FloatingHUDView` — Nano HUD is reserved for when the window is visible *only* because
    /// of the persistent "Show Floating HUD" + "Nano HUD" settings, with no live caption to
    /// show right now.
    public static func useNanoContent(useExperimentalNanoHUD: Bool, showFloatingHUD: Bool, shouldShowCaptionSurface: Bool) -> Bool {
        useExperimentalNanoHUD && showFloatingHUD && !shouldShowCaptionSurface
    }
}

/// Pure helper for recovering a window frame that a disconnected/resized display left
/// off-screen — `NSWindow.setFrameAutosaveName` persists whatever frame was last valid, which
/// can reference a screen that no longer exists (e.g. an external display unplugged between
/// launches). Operates on plain `NSRect`s (not live `NSScreen`s) so it's testable without a
/// real display configuration.
public enum FloatingHUDFramePositioning {
    public static func correctedFrame(_ frame: NSRect, visibleFrames: [NSRect]) -> NSRect {
        guard !visibleFrames.isEmpty else { return frame }
        if visibleFrames.contains(where: { $0.intersects(frame) }) {
            return frame
        }
        guard let primary = visibleFrames.first else { return frame }
        let x = primary.midX - frame.width / 2
        let y = primary.midY - frame.height / 2
        return NSRect(x: x, y: y, width: frame.width, height: frame.height)
    }
}
