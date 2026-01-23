import Cocoa

final class InputMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var engine: TranscriptionEngine?
    
    init(engine: TranscriptionEngine) { self.engine = engine }
    
    func start() {
        guard eventTap == nil else { return }
        // Listen for OtherMouse (Middle/Extra buttons)
        let mask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { proxy, type, event, refcon in
                // Unsafe pointer dance to get self back
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<InputMonitor>.fromOpaque(refcon).takeUnretainedValue()
                
                // Middle Mouse is Button 2
                if event.getIntegerValueField(.mouseEventButtonNumber) == 2 {
                    let isDown = (type == .otherMouseDown)
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
                self.engine?.debugLog = "CRITICAL: Input Permission FAILED"
                self.engine?.statusText = "Check Accessibility Settings"
                self.engine?.state = .stopped
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
