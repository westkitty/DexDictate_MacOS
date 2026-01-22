import SwiftUI
import AVFoundation
import Speech

@main
struct DexDictateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var engine = TranscriptionEngine()
    
    // Permission State
    @State private var axTrusted = AXIsProcessTrusted()
    @State private var speechAuth = SFSpeechRecognizer.authorizationStatus()
    
    init() { 
        print("DEBUG: App Init Started")
        Safety.setupDirectories() 
        print("DEBUG: Safety Directories Setup")
    }

    // Debug State
    @State private var debugMessage: String = "Ready"

    var body: some Scene {
        MenuBarExtra("Dex", systemImage: engine.statusIcon) {
            ZStack {
                // BACKGROUND LAYER
                Color.clear
                    .background(.ultraThinMaterial) // Glassmorphism Base
                    .ignoresSafeArea()
                
                // BRANDING LAYER (Behind content)
                Image("dog_background", bundle: Bundle.main)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(Circle())
                    .frame(width: 250, height: 250)
                    .opacity(0.15) // Faint watermark
                    .blendMode(.multiply)
                
                // CONTENT LAYER
                VStack(spacing: 12) {
                    Text("DEX DICTATE")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .blendMode(.overlay)
                                        
                    if !axTrusted || speechAuth != .authorized {
                        VStack(spacing: 8) {
                            Text("⚠️ Permissions Needed").font(.caption).bold().foregroundColor(.red)
                            
                            if !axTrusted {
                                Button("Grant Input Access") {
                                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true] as CFDictionary
                                    AXIsProcessTrustedWithOptions(options)
                                    debugMessage = "Requesting Accessibility..."
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            }
                            
                            if speechAuth != .authorized {
                                Button("Grant Speech Access") {
                                    debugMessage = "Requesting Speech..."
                                    SFSpeechRecognizer.requestAuthorization { status in
                                        DispatchQueue.main.async {
                                            self.speechAuth = status
                                            debugMessage = "Speech Status: \(status.rawValue)"
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                    } else {
                        // CONTROLS
                        VStack(spacing: 8) {
                            Text(engine.statusText)
                                .font(.headline)
                                .padding(.top, 5)
                            
                            if engine.state == .stopped {
                                Button(action: { Task { await engine.startSystem() } }) {
                                    Label("Start Dictation", systemImage: "mic.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            } else {
                                Button(action: { engine.stopSystem() }) {
                                    Label("Stop", systemImage: "stop.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                    }
                    
                    Divider()
                    
                    // DEBUG CONSOLE
                    Text(engine.debugLog)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: 40)
                    
                    HStack {
                        Button("Quit") { NSApplication.shared.terminate(nil) }
                            .buttonStyle(.bordered)
                        Button("Reload") {
                           axTrusted = AXIsProcessTrusted()
                           speechAuth = SFSpeechRecognizer.authorizationStatus()
                           engine.debugLog = "Reloading Permissions..."
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(20)
            }
            .frame(width: 320, height: 380)
            .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
                axTrusted = AXIsProcessTrusted()
                speechAuth = SFSpeechRecognizer.authorizationStatus()
            }
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("DEBUG: AppDelegate applicationDidFinishLaunching")
        // Request Permissions
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            print("DEBUG: Microphone access granted: \(granted)")
        }
        
        // PROMPT FOR ACCESSIBILITY IF NEEDED
        // PROMPT FOR ACCESSIBILITY IF NEEDED
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        print("DEBUG: AXIsProcessTrusted: \(trusted)")
    }
}
