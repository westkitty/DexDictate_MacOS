import SwiftUI
import AppKit
import DexDictateKit

/// Manages the lifecycle of the DexDictate Settings window.
///
/// Follows the same pattern as `HistoryWindowController` / `HelpWindowController`: lazy
/// NSWindow creation, `isReleasedWhenClosed = false` so the window persists across
/// open/close cycles, and `makeKeyAndOrderFront` to bring it forward on repeated calls.
/// This is a normal (non-floating) window — closing it never affects dictation focus.
@MainActor
class SettingsWindowController: ObservableObject {
    private var window: NSWindow?

    /// Opens the Settings window, or brings it forward and restores its last-viewed
    /// page if already open. `scanner`, `benchmarkCaptureController`, `historyController`,
    /// and `profileManager` are the app's single existing instances (the same ones the
    /// popover uses) — passed in rather than re-instantiated here. `historyController` in
    /// particular has already been `.setup(engine:vocabularyManager:)` by the app's
    /// onAppear; a fresh instance would silently no-op on `.show()`. `profileManager` must
    /// be the same instance so a profile switch made in Settings is immediately visible in
    /// the popover's ticker/watermark, not just in a disconnected copy.
    ///
    /// BUG-005 fix: `SettingsRootView` now owns its own `selection` as `@State` (see that
    /// file's doc comment) — this controller no longer threads a page-selection binding
    /// through at all. "Last-viewed page persists across close/reopen" still holds because
    /// `window`/`hosting` (and the `SettingsRootView` instance's `@State` storage) are only
    /// created once and reused via `makeKeyAndOrderFront` on every subsequent `show()`.
    func show(
        scanner: AudioDeviceScanner,
        benchmarkCaptureController: BenchmarkCaptureWindowController,
        historyController: HistoryWindowController,
        profileManager: ProfileManager,
        adaptiveBenchmarkController: AdaptiveBenchmarkController
    ) {
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsRootView(
                    scanner: scanner,
                    benchmarkCaptureController: benchmarkCaptureController,
                    historyController: historyController,
                    profileManager: profileManager,
                    adaptiveBenchmarkController: adaptiveBenchmarkController
                )
            )
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = NSLocalizedString("DexDictate Settings", comment: "Settings window title")
            newWindow.setContentSize(NSSize(width: 720, height: 480))
            newWindow.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            newWindow.minSize = NSSize(width: 560, height: 380)
            newWindow.center()
            newWindow.isReleasedWhenClosed = false
            newWindow.level = .normal
            window = newWindow
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
