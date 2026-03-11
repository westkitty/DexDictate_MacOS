import Foundation
import CoreAudio
import AVFoundation
import Combine

/// Monitors system audio devices and publishes changes to the list of available input devices.
///
/// Use this class to support hot-swapping of microphones.
public class AudioDeviceScanner: ObservableObject {
    
    @Published public private(set) var availableDevices: [AudioInputDevice] = []
    @Published public private(set) var recoveryNotice: String?
    
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    
    public init() {
        refreshDevices()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    /// Forces a refresh of the device list.
    public func refreshDevices() {
        Task { @MainActor in
            let devices = AudioDeviceManager.inputDevices()
            let decision = AudioInputSelectionPolicy.resolve(
                preferredUID: AppSettings.shared.inputDeviceUID,
                availableDevices: devices
            )

            self.availableDevices = devices

            if AppSettings.shared.inputDeviceUID != decision.normalizedUID {
                AppSettings.shared.inputDeviceUID = decision.normalizedUID
            }

            if let recoveryNotice = decision.recoveryNotice {
                self.recoveryNotice = recoveryNotice
                Safety.log(recoveryNotice, category: .audio)
            } else {
                self.recoveryNotice = nil
            }
        }
    }
    
    private func startMonitoring() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Use a local variable to define the block, then assign it
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            // Must dispatch to main to update @Published property
            DispatchQueue.main.async {
                self?.refreshDevices()
            }
        }
        
        self.listenerBlock = listener
        
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, listener)
    }
    
    private func stopMonitoring() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if let block = listenerBlock {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, block)
        }
        listenerBlock = nil
    }
}
