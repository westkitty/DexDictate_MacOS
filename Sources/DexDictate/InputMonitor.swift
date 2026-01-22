import Cocoa

class InputMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var engine: TranscriptionEngine?
    
    init(engine: TranscriptionEngine) { self.engine = engine }
    
    func start() {
        guard eventTap == nil else { return }
        // Listen for OtherMouse (Middle/Extra buttons)
        let mask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
        
        eventTap = CGEvent.tapCreate(
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
                    let down = (type == .otherMouseDown)
                    Task { @MainActor in monitor.engine?.handleTrigger(down: down) }
                    return nil // Consume event
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        if let tap = eventTap {
            print("DEBUG: InputMonitor Tap Created Successfully")
            Task { @MainActor in self.engine?.debugLog = "Input Tap Active" }
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        } else {
            print("DEBUG: CRITICAL FAILURE: InputMonitor Tap Creation Failed")
            Task { @MainActor in self.engine?.debugLog = "CRITICAL: Input Tap FAILED (Check Privacy)" }
        }
    }
    
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
    }
}
