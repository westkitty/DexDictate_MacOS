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
    /// Pending retry work item — cancelled in stop() so a discarded InputMonitor
    /// cannot create a second event tap after a new one has already been installed.
    private var retryWorkItem: DispatchWorkItem?

    /// Weak reference to the engine; held weakly to prevent a retain cycle since the engine
    /// owns the monitor.
    private weak var engine: TranscriptionEngine?

    /// True after a successful `CGEvent.tapCreate`. Readable from the main actor
    /// immediately after `start()` returns to determine whether to set engine state
    /// to `.ready` or leave it as `.error` (which the async Task in start() will set).
    var isEventTapActive: Bool { eventTap != nil }

    init(engine: TranscriptionEngine) { self.engine = engine }

    /// Installs the Quartz event tap and registers it with the current run loop.
    ///
    /// Calling `start()` while the tap is already active is a no-op.
    func start() {
        guard eventTap == nil else { return }

        // Check accessibility — do NOT prompt here. Prompting is done once in
        // PermissionManager.requestPermissions() from .onAppear. Calling
        // AXIsProcessTrustedWithOptions(prompt:true) here causes the system dialog
        // to pop every time the menu bar is opened, which is wrong.
        let isTrusted = AXIsProcessTrusted()
        Safety.log("InputMonitor.start() — AXIsProcessTrusted=\(isTrusted)")

        if !isTrusted {
            Safety.log("WARNING: Accessibility not granted — event tap will likely fail. Grant in System Settings > Privacy > Accessibility.")
            Task { @MainActor in
                self.engine?.statusText = "Waiting for Accessibility Permission..."
            }
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

                // Handle Tap Disabled events to re-enable
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    Safety.log("Event Tap disabled by system (\(type == .tapDisabledByTimeout ? "Timeout" : "User Input")) — re-enabling")
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                let shortcut = AppSettings.shared.userShortcut
                var match = false
                var isDown = false

                // 1. Mouse Trigger
                if let requiredButton = shortcut.mouseButton {
                    if type == .otherMouseDown || type == .otherMouseUp {
                        let btnNum = event.getIntegerValueField(.mouseEventButtonNumber)
                        if btnNum == requiredButton {
                            let flags = event.flags
                            if shortcut.modifiers != 0 && (flags.rawValue & shortcut.modifiers) != shortcut.modifiers {
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
                            let flags = event.flags
                            if (flags.rawValue & shortcut.modifiers) == shortcut.modifiers {
                                match = true
                                isDown = (type == .keyDown)
                            }
                        }
                    }
                }

                if match {
                    let mode = AppSettings.shared.triggerMode
                    Safety.log("Trigger matched — mode=\(mode) isDown=\(isDown)")

                    if mode == .holdToTalk {
                        Task { @MainActor in monitor.engine?.handleTrigger(down: isDown) }
                        return nil // Consume event
                    } else if mode == .toggle {
                        if isDown {
                            Task { @MainActor in monitor.engine?.toggleListening() }
                        }
                        return nil // Consume event
                    }
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            Safety.log("CRITICAL: CGEvent.tapCreate failed — accessibility permission required")
            Task { @MainActor in
                self.engine?.statusText = "Grant Accessibility Permission"
                self.engine?.state = .error
            }

            // Automatic retry after 5 seconds if permission granted.
            // Stored as a cancellable work item so stop() can cancel it — otherwise
            // a replaced InputMonitor would fire its retry and create a duplicate tap.
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if AXIsProcessTrusted() && self.eventTap == nil {
                    Safety.log("Retrying event tap creation...")
                    self.start()
                }
            }
            retryWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
            return
        }

        Safety.log("Event tap created successfully")
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Disables the event tap and removes its run loop source.
    ///
    /// Also cancels any pending retry work item so a replaced InputMonitor cannot
    /// create a duplicate event tap after `setupInputMonitor()` has already built a new one.
    ///
    /// Calling `stop()` when the tap is not active is a no-op.
    func stop() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
        guard let runLoopSource = runLoopSource, let eventTap = eventTap else { return }
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: false)
        self.runLoopSource = nil
        self.eventTap = nil
    }
}
