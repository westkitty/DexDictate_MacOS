import Foundation
import SwiftUI
import Speech
import AVFoundation

class PermissionManager: ObservableObject {
    @Published var accessibilityGranted: Bool = false
    @Published var microphoneGranted: Bool = false
    @Published var speechRecognitionGranted: Bool = false
    
    @Published var allPermissionsGranted: Bool = false
    @Published var permissionsSummary: String = "Checking permissions..."
    
    private var timer: Timer?
    private weak var engine: TranscriptionEngine?
    private var recoveryAttempts = 0
    private let maxRecoveryAttempts = 3
    
    init() {
        checkPermissions()
    }
    
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
        
        // Overall status
        allPermissionsGranted = accessibilityGranted && microphoneGranted && speechRecognitionGranted
        
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
    }
}
