import Foundation
import ServiceManagement

public enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    public var isEnabled: Bool {
        switch self {
        case .enabled, .requiresApproval:
            return true
        case .disabled, .unavailable:
            return false
        }
    }

    public var message: String {
        switch self {
        case .enabled:
            return "DexDictate will open automatically when you log in."
        case .disabled:
            return "DexDictate will stay manual-start only until you enable launch at login."
        case .requiresApproval:
            return "macOS still needs approval in Login Items before launch at login becomes active."
        case .unavailable:
            return "DexDictate could not verify launch-at-login readiness yet. You can still try enabling it."
        }
    }
}

public protocol LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettings()
}

public struct SystemLaunchAtLoginService: LaunchAtLoginServicing {
    private let service: SMAppService

    public init(service: SMAppService = .mainApp) {
        self.service = service
    }

    public var status: LaunchAtLoginStatus {
        switch service.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            // Treat "not found" as a disabled-but-registrable state. In practice this can
            // occur before the app has been registered in login items for the first time.
            return .disabled
        @unknown default:
            return .unavailable
        }
    }

    public func register() throws {
        try service.register()
    }

    public func unregister() throws {
        try service.unregister()
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    @discardableResult
    public static func unregisterIfPossible() -> Bool {
        let service = SystemLaunchAtLoginService()
        guard service.status != .unavailable else { return false }

        do {
            try service.unregister()
            return true
        } catch {
            Safety.log("Launch-at-login unregister during defaults reset failed: \(error.localizedDescription)", category: .settings)
            return false
        }
    }
}

@MainActor
public final class LaunchAtLoginController: ObservableObject {
    @Published public private(set) var status: LaunchAtLoginStatus
    @Published public private(set) var lastError: String?

    private let service: LaunchAtLoginServicing

    public init(service: LaunchAtLoginServicing = SystemLaunchAtLoginService()) {
        self.service = service
        self.status = service.status
    }

    public var isEnabled: Bool {
        status.isEnabled
    }

    public var statusMessage: String {
        lastError ?? status.message
    }

    public var needsSystemApproval: Bool {
        status == .requiresApproval
    }

    public var isUnavailable: Bool {
        status == .unavailable
    }

    public var canAttemptRegistration: Bool {
        true
    }

    public func refresh() {
        status = service.status
        lastError = nil
    }

    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            status = service.status
            lastError = nil
        } catch {
            status = service.status
            lastError = error.localizedDescription
            Safety.log("Launch-at-login update failed: \(error.localizedDescription)", category: .settings)
        }
    }

    public func syncStoredPreference(into settings: AppSettings) {
        settings.launchAtLogin = isEnabled
    }

    public func openSystemSettings() {
        service.openSystemSettings()
    }
}
