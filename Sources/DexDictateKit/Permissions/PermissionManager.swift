import Foundation
import SwiftUI
import AVFoundation
import AppKit
import ApplicationServices

/// Polls the macOS TCC permissions required by DexDictate and drives auto-recovery
/// when accessibility access is granted while the app is already running.
///
/// Permission states are published so SwiftUI views can react immediately. The manager
/// polls every 2 seconds rather than using a notification-based approach because TCC
/// changes are not reliably broadcast to the process that needs them.
public class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    private enum MonitoringRequester: Hashable {
        case interface
        case runtime
    }

    /// Whether the app has been granted Accessibility (required for the event tap).
    @Published public var accessibilityGranted: Bool = false

    /// Whether the user has authorised microphone access via `AVCaptureDevice`.
    @Published public var microphoneGranted: Bool = false

    /// Legacy compatibility signal for older UI/state code.
    ///
    /// DexDictate uses a modifying CGEvent tap (`.defaultTap`), whose controlling TCC
    /// authorization is Accessibility. A separate Input Monitoring grant is not required.
    /// Keep this published property temporarily so older views do not break; it mirrors
    /// Accessibility and must never trigger a separate TCC request.
    @Published public var inputMonitoringGranted: Bool = false

    /// `true` when all required permissions are granted; drives the banner in the UI.
    @Published public var allPermissionsGranted: Bool = false

    /// Human-readable summary of missing permissions shown in `PermissionBannerView`.
    @Published public var permissionsSummary: String = NSLocalizedString("Checking permissions...", comment: "")

    /// Live capability probe results, refreshed on explicit checks and Accessibility changes.
    /// Nil until the first check runs. Separate from TCC grant state: a permission
    /// can be granted yet still fail a live capability probe (e.g., after signing changes).
    @Published public var capabilityReport: PermissionCapabilityReport?

    /// Capability checker used by `checkPermissions()`. Defaults to the production
    /// system implementation; replaced in unit tests with a mock.
    var capabilityChecker: PermissionCapabilityChecker = .system

    /// 2-second polling timer; retained here so it can be invalidated on `deinit`.
    private var timer: Timer?

    /// Token returned by the block-based foreground-notification observer.
    /// Stored so it can be unregistered in `deinit`.
    private var foregroundObserver: NSObjectProtocol?

    /// Weak reference to the engine so the manager can trigger a monitor retry after
    /// accessibility is granted without creating a retain cycle.
    private weak var engine: TranscriptionEngine?
    private var activeMonitoringRequesters = Set<MonitoringRequester>()

    var hasActivePollingTimer: Bool {
        timer != nil
    }

    public var microphoneSettingsURL: URL? {
        PermissionSettingsLinker.url(for: .microphone)
    }

    public var accessibilitySettingsURL: URL? {
        PermissionSettingsLinker.url(for: .accessibility)
    }

    public var inputMonitoringSettingsURL: URL? {
        // Legacy API compatibility: callers that still ask for this route should land on
        // the permission that actually governs DexDictate's modifying event tap.
        PermissionSettingsLinker.url(for: .accessibility)
    }
    
    public init() {
        checkPermissions(forceCapabilityProbe: true)
        // Immediately re-check when the app comes to the foreground. This reduces the
        // felt permission-grant latency from up to 2 seconds (polling interval) to near-zero
        // in the common case where the user grants a permission in System Settings and
        // immediately switches back to DexDictate.
        //
        // Uses block-based observation (not selector-based) so the observer token can be
        // stored and explicitly unregistered in deinit without requiring NSObject inheritance.
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkPermissions(forceCapabilityProbe: true)
        }
    }

    deinit {
        timer?.invalidate()
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
    
    /// Starts the 2-second polling loop and stores a reference to the engine for recovery.
    ///
    /// This variant is used by UI surfaces such as onboarding that need live permission state.
    public func startMonitoring() {
        activeMonitoringRequesters.insert(.interface)
        ensureMonitoringTimer()
    }

    /// Starts the 2-second polling loop and stores a reference to the engine for recovery.
    ///
    /// - Parameter engine: The engine to retry when accessibility is newly granted.
    public func startMonitoring(engine: TranscriptionEngine) {
        self.engine = engine
        activeMonitoringRequesters.insert(.runtime)
        ensureMonitoringTimer()
    }
    
    /// Stops polling requested by UI surfaces such as onboarding.
    public func stopMonitoring() {
        activeMonitoringRequesters.remove(.interface)
        updateMonitoringTimerState()
    }

    /// Stops runtime-owned polling and clears the engine reference (held `weak`, so this
    /// doesn't release anything — it just stops referring to an engine that may be gone).
    public func stopRuntimeMonitoring() {
        activeMonitoringRequesters.remove(.runtime)
        engine = nil
        updateMonitoringTimerState()
    }

    /// Forces an immediate permission re-check, used when the UI opens.
    public func refreshPermissions() {
        checkPermissions(forceCapabilityProbe: true)
    }

    private func ensureMonitoringTimer() {
        checkPermissions(forceCapabilityProbe: true)
        updateMonitoringTimerState()
    }

    private func updateMonitoringTimerState() {
        if activeMonitoringRequesters.isEmpty {
            timer?.invalidate()
            timer = nil
            return
        }

        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
    }
    
    private func checkPermissions(forceCapabilityProbe: Bool = false) {
        let oldAccessibility = accessibilityGranted
        
        // 1. Accessibility
        accessibilityGranted = AXIsProcessTrusted()
        
        // 2. Microphone
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneGranted = (micStatus == .authorized)
        
        // DexDictate's global shortcut monitor uses a modifying CGEvent tap (`.defaultTap`).
        // Accessibility is the relevant TCC permission for that path. Do not gate startup
        // on CGPreflightListenEventAccess(): doing so asks users for an unnecessary second
        // permission and can force repeated quit/reopen cycles on newer macOS releases.
        inputMonitoringGranted = accessibilityGranted
        
        // Overall status: only the permissions actually required by the product.
        allPermissionsGranted = accessibilityGranted && microphoneGranted
        
        updateSummary()

        // The live event-tap probe creates a real active tap. Do not recreate that tap on
        // every 2-second TCC poll. Probe on explicit refresh/foreground transitions, first
        // initialization, or when Accessibility itself changes.
        if forceCapabilityProbe || capabilityReport == nil || oldAccessibility != accessibilityGranted {
            capabilityReport = capabilityChecker.run(
                accessibilityGranted: accessibilityGranted,
                inputMonitoringGranted: inputMonitoringGranted
            )
        }

        // Auto-recovery logic
        if !oldAccessibility && accessibilityGranted {
            #if DEBUG
            print("✅ Accessibility granted! Attempting recovery...")
            #endif
            attemptRecovery()
        }
    }
    
    private func updateSummary() {
        if allPermissionsGranted {
            permissionsSummary = NSLocalizedString("All permissions granted", comment: "")
            return
        }
        
        var missing: [String] = []
        if !accessibilityGranted { missing.append(NSLocalizedString("Accessibility", comment: "")) }
        if !microphoneGranted { missing.append(NSLocalizedString("Microphone", comment: "")) }

        permissionsSummary = NSLocalizedString("Missing: ", comment: "") + missing.joined(separator: ", ")
    }
    
    private func attemptRecovery() {
        guard let engine = engine else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            #if DEBUG
            print("🔄 Triggering engine retry...")
            #endif
            engine.retryInputMonitor()
            self?.checkPermissions(forceCapabilityProbe: true)
        }
    }
    
    /// Proactively requests Accessibility (NOT Microphone).
    ///
    /// Microphone is requested separately via `requestMicrophoneIfNeeded()` on first dictation.
    /// DexDictate intentionally does not request standalone Input Monitoring: its modifying
    /// event tap is governed by Accessibility.
    public func requestPermissions() {
        requestAccessibilityIfNeeded()
    }

    public func requestAccessibilityIfNeeded() {
        guard !accessibilityGranted else { return }
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        AXIsProcessTrustedWithOptions(options)
    }

    /// Deprecated compatibility shim. The global trigger path is governed by Accessibility.
    public func requestInputMonitoringIfNeeded() {
        requestAccessibilityIfNeeded()
    }

    public func openMicrophoneSettings() {
        PermissionSettingsLinker.open(.microphone)
    }

    public func openAccessibilitySettings() {
        PermissionSettingsLinker.open(.accessibility)
    }

    /// Deprecated compatibility shim. Open the permission that actually governs the event tap.
    public func openInputMonitoringSettings() {
        PermissionSettingsLinker.open(.accessibility)
    }

    /// Requests microphone permission if not already granted.
    /// Call this before starting dictation to prompt user for microphone access.
    public func requestMicrophoneIfNeeded() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }
    }
}
