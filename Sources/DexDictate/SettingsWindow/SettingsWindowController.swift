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
    @Published var selection: SettingsPage = .general

    /// Opens the Settings window, or brings it forward and restores its last-viewed
    /// page if already open. `scanner` and `benchmarkCaptureController` are the app's
    /// single existing instances (the same ones the popover uses) — passed in rather than
    /// re-instantiated here so the Audio & Microphone / Models & Accuracy pages read live
    /// state instead of standing up duplicate controllers.
    func show(scanner: AudioDeviceScanner, benchmarkCaptureController: BenchmarkCaptureWindowController) {
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsRootView(
                    selection: Binding(
                        get: { [weak self] in self?.selection ?? .general },
                        set: { [weak self] in self?.selection = $0 }
                    ),
                    scanner: scanner,
                    benchmarkCaptureController: benchmarkCaptureController
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
