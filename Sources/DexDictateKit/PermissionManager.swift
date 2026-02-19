import Foundation
import SwiftUI
import AVFoundation
import ApplicationServices

/// Polls the three macOS TCC permissions required by DexDictate and drives auto-recovery
/// when accessibility access is granted while the app is already running.
///
/// Permission states are published so SwiftUI views can react immediately. The manager
/// polls every 2 seconds rather than using a notification-based approach because TCC
/// changes are not reliably broadcast to the process that needs them.
public class PermissionManager: ObservableObject {

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

    /// 2-second polling timer; retained here so it can be invalidated on `deinit`.
    private var timer: Timer?

    /// Weak reference to the engine so the manager can trigger a monitor retry after
    /// accessibility is granted without creating a retain cycle.
    private weak var engine: TranscriptionEngine?

    private var recoveryAttempts = 0
    private let maxRecoveryAttempts = 3

    public var settingsURL: URL? {
        if !inputMonitoringGranted {
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }
    
    public init() {
        checkPermissions()
    }

    deinit {
        timer?.invalidate()
    }
    
    /// Starts the 2-second polling loop and stores a reference to the engine for recovery.
    ///
    /// - Parameter engine: The engine to retry when accessibility is newly granted.
    public func startMonitoring(engine: TranscriptionEngine) {
        self.engine = engine
        // Poll every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Forces an immediate permission re-check, used when the UI opens.
    public func refreshPermissions() {
        checkPermissions()
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
        
        // Reset recovery attempts if it's been a while (optional, implementation detail)
        // Here we just check max attempts for this session of becoming trusted? 
        // Actually, if we just became trusted, we should definitely try.
        
        // Delay slightly to ensure the system propagates the permission.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            #if DEBUG
            print("🔄 Triggering engine retry...")
            #endif
            engine.retryInputMonitor()
            self?.recoveryAttempts += 1
        }
    }
    
    /// Proactively requests Accessibility and Input Monitoring (NOT Microphone).
    ///
    /// Microphone is requested separately via `requestMicrophoneIfNeeded()` on first dictation.
    public func requestPermissions() {
        // Request Accessibility (via opening system prefs if needed)
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        AXIsProcessTrustedWithOptions(options)

        // Request Input Monitoring
        if !inputMonitoringGranted {
            CGRequestListenEventAccess()
        }
        // NOTE: Microphone is NOT requested here — see requestMicrophoneIfNeeded()
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
