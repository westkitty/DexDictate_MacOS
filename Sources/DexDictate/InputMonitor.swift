import Cocoa

final class InputMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var engine: TranscriptionEngine?
    
    init(engine: TranscriptionEngine) { self.engine = engine }
    
    func start() {
        guard eventTap == nil else { return }
        
        // 1. Check Accessibility Trust explicitly
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        if !isTrusted {
            print("WARNING: Accessibility permissions not granted yet.")
            Task { @MainActor in
                self.engine?.statusText = "Waiting for Permissions..."
                self.engine?.debugLog = "Please Grant Accessibility in Settings"
            }
            // We don't return here immediately; AXIsProcessTrustedWithOptions calls the prompt.
            // But tapCreate will likely fail until granted.
        }

        // Monitor for both Mouse (Other) and Keyboard events to support custom shortcuts
        let mask = (1 << CGEventType.otherMouseDown.rawValue) | 
                   (1 << CGEventType.otherMouseUp.rawValue) | 
                   (1 << CGEventType.keyDown.rawValue) | 
                   (1 << CGEventType.keyUp.rawValue) |
                   (1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { proxy, type, event, refcon in
                // Unsafe pointer dance to get self back
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<InputMonitor>.fromOpaque(refcon).takeUnretainedValue()
                
                let shortcut = Settings.shared.userShortcut
                var match = false
                var isDown = false
                
                // 1. Mouse Trigger
                if let requiredButton = shortcut.mouseButton {
                    // Only check mouse events
                    if type == .otherMouseDown || type == .otherMouseUp {
                        let btnNum = event.getIntegerValueField(.mouseEventButtonNumber)
                        if btnNum == requiredButton {
                            // Check modifiers (strict match optional, but allow loose for now)
                            let flags = event.flags
                            // If modifiers required, check them
                            if shortcut.modifiers != 0 && (flags.rawValue & shortcut.modifiers) != shortcut.modifiers {
                                // Modifier mismatch
                                return Unmanaged.passUnretained(event)
                            }
                            
                            match = true
                            isDown = (type == .otherMouseDown)
                        }
                    }
                }
                
                // 2. Keyboard Trigger
                else if let requiredKey = shortcut.keyCode {
                    if type == .keyDown || type == .keyUp {
                        let key = event.getIntegerValueField(.keyboardEventKeycode)
                        if key == Int64(requiredKey) {
                             // Check modifiers
                             let flags = event.flags
                             if (flags.rawValue & shortcut.modifiers) == shortcut.modifiers {
                                 match = true
                                 isDown = (type == .keyDown)
                             }
                        }
                    }
                }

                if match {
                    let mode = Settings.shared.triggerMode
                    
                    if mode == .holdToTalk {
                         Task { @MainActor in monitor.engine?.handleTrigger(down: isDown) }
                         return nil // Consume event
                    } else if mode == .toggle {
                        if isDown {
                             // Toggle logic: Only act on Press
                             Task { @MainActor in monitor.engine?.toggleListening() }
                        }
                        return nil // Consume event
                    }
                }
                
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("CRITICAL: Failed to create Event Tap")
            Task { @MainActor in
                self.engine?.debugLog = "Event Tap Failed - Check System Settings > Privacy & Security > Accessibility"
                self.engine?.statusText = "Grant Accessibility Permission"
                self.engine?.state = .error
            }

            // Automatic retry after 5 seconds if permission granted
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                guard let self = self else { return }
                if AXIsProcessTrusted() && self.eventTap == nil {
                    print("🔄 Retrying event tap creation...")
                    self.start()
                }
            }
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap!, enable: true)
    }
    
    func stop() {
        guard let runLoopSource = runLoopSource, let eventTap = eventTap else { return }
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: false)
        self.runLoopSource = nil
        self.eventTap = nil
    }
}
