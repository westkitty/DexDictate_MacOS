import Cocoa

/// Installs a system-wide Quartz event tap to intercept the user's configured trigger shortcut.
///
/// `InputMonitor` listens for keyboard and mouse events matching `Settings.shared.userShortcut`
/// and dispatches `handleTrigger(down:)` or `toggleListening()` on the engine accordingly.
///
/// The tap runs on the current run loop and must be created on the main thread.  When the
/// event tap fails (e.g. accessibility is not yet authorised), the monitor schedules a 5-second
/// automatic retry rather than entering an error state permanently.
///
/// - Important: Requires the `com.apple.security.device.input-monitoring` entitlement and
///   user approval under **System Settings › Privacy & Security › Accessibility**.
final class InputMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Weak reference to the engine; held weakly to prevent a retain cycle since the engine
    /// owns the monitor.
    private weak var engine: TranscriptionEngine?

    init(engine: TranscriptionEngine) { self.engine = engine }

    /// Installs the Quartz event tap and registers it with the current run loop.
    ///
    /// If accessibility access has not been granted the method still prompts the user and
    /// schedules an automatic retry after 5 seconds. Calling `start()` while the tap is
    /// already active is a no-op.
    func start() {
        guard eventTap == nil else { return }
        
        // 1. Check Accessibility Trust explicitly
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        if !isTrusted {
            print("WARNING: Accessibility permissions not granted yet.")
            Task { @MainActor in
                self.engine?.statusText = "Waiting for Permissions..."
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
    
    /// Disables the event tap and removes its run loop source.
    ///
    /// Calling `stop()` when the tap is not active is a no-op.
    func stop() {
        guard let runLoopSource = runLoopSource, let eventTap = eventTap else { return }
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: false)
        self.runLoopSource = nil
        self.eventTap = nil
    }
}
