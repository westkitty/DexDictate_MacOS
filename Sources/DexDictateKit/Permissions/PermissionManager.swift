import Foundation
import SwiftUI
import AVFoundation
import AppKit
import ApplicationServices

/// Polls the three macOS TCC permissions required by DexDictate and drives auto-recovery
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

    /// Whether the app can listen for system events (Input Monitoring permission).
    @Published public var inputMonitoringGranted: Bool = false

    /// `true` when all required permissions are granted; drives the banner in the UI.
    @Published public var allPermissionsGranted: Bool = false

    /// Human-readable summary of missing permissions shown in `PermissionBannerView`.
    @Published public var permissionsSummary: String = NSLocalizedString("Checking permissions...", comment: "")

    /// Live capability probe results, updated after every permission check.
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

    public var settingsURL: URL? {
        if !inputMonitoringGranted {
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    public var accessibilitySettingsURL: URL? {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    public var inputMonitoringSettingsURL: URL? {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }
    
    public init() {
        checkPermissions()
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
            self?.checkPermissions()
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

    /// Stops runtime-owned polling and clears the retained engine reference.
    public func stopRuntimeMonitoring() {
        activeMonitoringRequesters.remove(.runtime)
        engine = nil
        updateMonitoringTimerState()
    }

    /// Forces an immediate permission re-check, used when the UI opens.
    public func refreshPermissions() {
        checkPermissions()
    }

    private func ensureMonitoringTimer() {
        checkPermissions()
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
    
    private func checkPermissions() {
        let oldAccessibility = accessibilityGranted
        
        // 1. Accessibility
        accessibilityGranted = AXIsProcessTrusted()
        
        // 2. Microphone
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneGranted = (micStatus == .authorized)
        
        // 3. Input Monitoring (Speech Recognition removed — Whisper is local-only)
        // CGPreflightListenEventAccess is available on all supported targets (macOS 14+).
        inputMonitoringGranted = CGPreflightListenEventAccess()
        
        // Overall status (Speech Recognition not required — Whisper is local-only)
        allPermissionsGranted = accessibilityGranted && microphoneGranted && inputMonitoringGranted
        
        updateSummary()

        capabilityReport = capabilityChecker.run(
            accessibilityGranted: accessibilityGranted,
            inputMonitoringGranted: inputMonitoringGranted
        )

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
        if !inputMonitoringGranted { missing.append(NSLocalizedString("Input Monitoring", comment: "")) }
        
        permissionsSummary = NSLocalizedString("Missing: ", comment: "") + missing.joined(separator: ", ")
    }
    
    private func attemptRecovery() {
        guard let engine = engine else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            #if DEBUG
            print("🔄 Triggering engine retry...")
            #endif
            engine.retryInputMonitor()
            self?.checkPermissions()
        }
    }
    
    /// Proactively requests Accessibility and Input Monitoring (NOT Microphone).
    ///
    /// Microphone is requested separately via `requestMicrophoneIfNeeded()` on first dictation.
    public func requestPermissions() {
        requestAccessibilityIfNeeded()
        requestInputMonitoringIfNeeded()
    }

    public func requestAccessibilityIfNeeded() {
        guard !accessibilityGranted else { return }
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        AXIsProcessTrustedWithOptions(options)
    }

    public func requestInputMonitoringIfNeeded() {
        if !inputMonitoringGranted {
            CGRequestListenEventAccess()
        }
    }

    public func openAccessibilitySettings() {
        guard let url = accessibilitySettingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    public func openInputMonitoringSettings() {
        guard let url = inputMonitoringSettingsURL else { return }
        NSWorkspace.shared.open(url)
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
