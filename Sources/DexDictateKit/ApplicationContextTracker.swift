import AppKit
import Foundation

public struct ExternalApplicationContext: Equatable {
    public let bundleIdentifier: String
    public let displayName: String
    public let processIdentifier: pid_t

    public init(bundleIdentifier: String, displayName: String, processIdentifier: pid_t) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.processIdentifier = processIdentifier
    }

    public var outputTargetApplication: OutputTargetApplication {
        OutputTargetApplication(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier
        )
    }
}

@MainActor
public final class ApplicationContextTracker: ObservableObject {
    public static let shared = ApplicationContextTracker()

    @Published public private(set) var lastExternalApplication: ExternalApplicationContext?

    private var activationObserver: NSObjectProtocol?

    private init() {
        captureFrontmostExternalApplication()

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleActivation(notification)
            }
        }
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    public func recentExternalApplication() -> ExternalApplicationContext? {
        lastExternalApplication
    }

    public func recentOutputTargetApplication() -> OutputTargetApplication? {
        lastExternalApplication?.outputTargetApplication
    }

    public func refresh() {
        captureFrontmostExternalApplication()
    }

    private func handleActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        updateLastExternalApplication(from: app)
    }

    private func captureFrontmostExternalApplication() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return
        }
        updateLastExternalApplication(from: app)
    }

    private func updateLastExternalApplication(from app: NSRunningApplication) {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier ?? "com.westkitty.dexdictate.macos"
        guard let bundleIdentifier = app.bundleIdentifier,
              bundleIdentifier != ownBundleIdentifier else {
            return
        }

        lastExternalApplication = ExternalApplicationContext(
            bundleIdentifier: bundleIdentifier,
            displayName: app.localizedName ?? bundleIdentifier,
            processIdentifier: app.processIdentifier
        )
    }
}
