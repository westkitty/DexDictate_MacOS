import AppKit
import CoreGraphics

/// Sizing helper for the menu-bar popover windows.
///
/// `MenuBarExtra(.window)` fixes its hosting window size at first presentation and does not
/// grow at runtime. On short displays a fixed preferred height (e.g. 560) can exceed the
/// usable screen area, pushing the bottom of the popover — and its scrollbar — off-screen,
/// so the lower settings panels become unreachable even though the content is in a `ScrollView`.
///
/// Capping the preferred height to the active screen's usable height keeps the whole window
/// on-screen, which makes the existing inner `ScrollView` able to reach every panel.
enum PopoverSizing {
    static func cappedHeight(
        preferred: CGFloat,
        margin: CGFloat = 24,
        minimum: CGFloat = 360
    ) -> CGFloat {
        let usable = (NSScreen.main?.visibleFrame.height ?? 900) - margin
        return max(minimum, min(preferred, usable))
    }
}
