import SwiftUI
import AppKit

/// Manages the lifecycle of the DexDictate Help window.
///
/// Follows the same pattern as `HistoryWindowController`: lazy NSWindow creation,
/// `isReleasedWhenClosed = false` so the window persists across open/close cycles,
/// and `makeKeyAndOrderFront` to bring it forward on repeated calls.
@MainActor
class HelpWindowController: ObservableObject {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: HelpView())
            window = NSWindow(contentViewController: hosting)
            window?.title = NSLocalizedString("DexDictate Help", comment: "Help window title")
            window?.setContentSize(NSSize(width: 720, height: 540))
            window?.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window?.minSize = NSSize(width: 520, height: 400)
            window?.center()
            window?.isReleasedWhenClosed = false
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
