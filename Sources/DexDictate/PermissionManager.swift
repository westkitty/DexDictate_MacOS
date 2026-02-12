import Foundation
import SwiftUI
import Speech
import AVFoundation
import ApplicationServices

/// Polls the three macOS TCC permissions required by DexDictate and drives auto-recovery
/// when accessibility access is granted while the app is already running.
///
/// Permission states are published so SwiftUI views can react immediately. The manager
/// polls every 2 seconds rather than using a notification-based approach because TCC
/// changes are not reliably broadcast to the process that needs them.
class PermissionManager: ObservableObject {

    /// Whether the app has been granted Accessibility (required for the event tap).
    @Published var accessibilityGranted: Bool = false

    /// Whether the user has authorised microphone access via `AVCaptureDevice`.
    @Published var microphoneGranted: Bool = false

    /// Whether `SFSpeechRecognizer` has been authorised to recognise speech.
    @Published var speechRecognitionGranted: Bool = false

    /// Whether the app can listen for system events (Input Monitoring permission).
    @Published var inputMonitoringGranted: Bool = false

    /// `true` when all required permissions are granted; drives the banner in the UI.
    @Published var allPermissionsGranted: Bool = false

    /// Human-readable summary of missing permissions shown in `PermissionBannerView`.
    @Published var permissionsSummary: String = "Checking permissions..."

    /// 2-second polling timer; retained here so it can be invalidated on `deinit`.
    private var timer: Timer?

    /// Weak reference to the engine so the manager can trigger a monitor retry after
    /// accessibility is granted without creating a retain cycle.
    private weak var engine: TranscriptionEngine?

    private var recoveryAttempts = 0
    private let maxRecoveryAttempts = 3

    var settingsURL: URL? {
        if !inputMonitoringGranted {
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }
    
    init() {
        checkPermissions()
    }

    deinit {
        timer?.invalidate()
    }
    
    /// Starts the 2-second polling loop and stores a reference to the engine for recovery.
    ///
    /// - Parameter engine: The engine to retry when accessibility is newly granted.
    func startMonitoring(engine: TranscriptionEngine) {
        self.engine = engine
        // Poll every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Forces an immediate permission re-check, used when the UI opens.
    func refreshPermissions() {
        checkPermissions()
    }
    
    private func checkPermissions() {
        let oldAccessibility = accessibilityGranted
        
        // 1. Accessibility
        accessibilityGranted = AXIsProcessTrusted()
        
        // 2. Microphone
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneGranted = (micStatus == .authorized)
        
        // 3. Speech Recognition
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        speechRecognitionGranted = (speechStatus == .authorized)

        // 4. Input Monitoring
        if #available(macOS 10.15, *) {
            inputMonitoringGranted = CGPreflightListenEventAccess()
        } else {
            inputMonitoringGranted = true
        }
        
        // Overall status
        allPermissionsGranted = accessibilityGranted && microphoneGranted && speechRecognitionGranted && inputMonitoringGranted
        
        updateSummary()
        
        // Auto-recovery logic
        if !oldAccessibility && accessibilityGranted {
            print("✅ Accessibility granted! Attempting recovery...")
            attemptRecovery()
        }
    }
    
    private func updateSummary() {
        if allPermissionsGranted {
            permissionsSummary = "All permissions granted"
            return
        }
        
        var missing: [String] = []
        if !accessibilityGranted { missing.append("Accessibility") }
        if !microphoneGranted { missing.append("Microphone") }
        if !speechRecognitionGranted { missing.append("Speech Recognition") }
        if !inputMonitoringGranted { missing.append("Input Monitoring") }
        
        permissionsSummary = "Missing: " + missing.joined(separator: ", ")
    }
    
    private func attemptRecovery() {
        guard let engine = engine else { return }
        
        // Reset recovery attempts if it's been a while (optional, implementation detail)
        // Here we just check max attempts for this session of becoming trusted? 
        // Actually, if we just became trusted, we should definitely try.
        
        // We delay slightly to ensure system propigates the permission
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            print("🔄 Triggering engine retry...")
            engine.retryInputMonitor()
            self?.recoveryAttempts += 1
        }
    }
    
    /// Proactively requests all undetermined permissions and prompts for accessibility.
    ///
    /// Requests that are already `.authorized` or `.denied` are silently skipped.
    func requestPermissions() {
        // Request Microphone
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }
        
        // Request Speech
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { _ in }
        }
        
        // Request Accessibility (via opening system prefs if needed)
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        AXIsProcessTrustedWithOptions(options)

        if #available(macOS 10.15, *) {
            if !inputMonitoringGranted {
                CGRequestListenEventAccess()
            }
        }
    }
}
