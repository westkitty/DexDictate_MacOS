import SwiftUI
import AppKit
import DexDictateKit

@MainActor
final class SilverTongueWindowController: ObservableObject {
    private var window: NSWindow?
    private var coordinator: SilverTongueCoordinator?
    private var history: TranscriptionHistory?
    private var settings: AppSettings?
    private var serviceManager: SilverTongueServiceManager?

    func setup(
        history: TranscriptionHistory,
        settings: AppSettings,
        serviceManager: SilverTongueServiceManager
    ) {
        self.history = history
        self.settings = settings
        self.serviceManager = serviceManager
        if coordinator == nil {
            coordinator = SilverTongueCoordinator(settings: settings, serviceManager: serviceManager)
        }
    }

    func show() {
        guard
            let coordinator,
            let history,
            let settings,
            let serviceManager
        else {
            return
        }

        let rootView = AnyView(
            SilverTongueView(
                coordinator: coordinator,
                serviceManager: serviceManager,
                history: history,
                settings: settings,
                onOpenSettings: {
                    NSApp.activate()
                }
            )
        )

        if window == nil {
            let hostingController = NSHostingController(rootView: rootView)
            window = NSWindow(contentViewController: hostingController)
            window?.title = "SilverTongue"
            window?.setContentSize(NSSize(width: 460, height: 560))
            window?.minSize = NSSize(width: 420, height: 500)
            window?.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window?.center()
            window?.isReleasedWhenClosed = false
        } else if let hostingController = window?.contentViewController as? NSHostingController<AnyView> {
            hostingController.rootView = rootView
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        // Do NOT call coordinator.prepare() here — SilverTongueView.onAppear already calls it
        // via the hasPrepared guard.  A second call here causes double-prepare every time the
        // window is shown (two concurrent startIfNeeded + listVoices round-trips to the service).
    }

    func showAndRead(text: String) {
        show()
        guard let coordinator else { return }
        Task { await coordinator.readBack(text: text) }
    }
}
