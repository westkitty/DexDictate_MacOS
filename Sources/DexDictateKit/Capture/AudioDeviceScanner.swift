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
    private var pendingPreferredFallbackWorkItem: DispatchWorkItem?
    private var pendingMissingPreferredUID: String?
    private let missingPreferredGraceInterval: TimeInterval = 3.0

    public init() {
        refreshDevices()
        startMonitoring()
    }

    deinit {
        cancelPendingPreferredFallback()
        stopMonitoring()
    }

    /// Forces a refresh of the device list.
    public func refreshDevices() {
        refreshDevices(missingPreferredGraceExpired: false)
    }

    private func refreshDevices(missingPreferredGraceExpired: Bool) {
        MainActorDispatch.async { [weak self] in
            guard let self else { return }
            let devices = AudioDeviceManager.inputDevices()
            let currentPreferredUID = AppSettings.shared.inputDeviceUID
            let graceExpiredForCurrentPreferred =
                missingPreferredGraceExpired && currentPreferredUID == self.pendingMissingPreferredUID
            let decision = AudioInputSelectionPolicy.resolve(
                preferredUID: currentPreferredUID,
                availableDevices: devices,
                missingPreferredGraceExpired: graceExpiredForCurrentPreferred
            )

            self.availableDevices = devices

            switch decision.status {
            case .systemDefault, .preferredAvailable, .fellBackToSystemDefault:
                self.cancelPendingPreferredFallback()
            case .preferredTemporarilyUnavailable:
                self.schedulePreferredFallbackRecheck(for: currentPreferredUID)
            }

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

    private func schedulePreferredFallbackRecheck(for preferredUID: String) {
        guard !preferredUID.isEmpty else {
            cancelPendingPreferredFallback()
            return
        }
        guard pendingMissingPreferredUID != preferredUID || pendingPreferredFallbackWorkItem == nil else {
            return
        }

        cancelPendingPreferredFallback()
        pendingMissingPreferredUID = preferredUID

        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshDevices(missingPreferredGraceExpired: true)
        }
        pendingPreferredFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + missingPreferredGraceInterval, execute: workItem)
    }

    private func cancelPendingPreferredFallback() {
        pendingPreferredFallbackWorkItem?.cancel()
        pendingPreferredFallbackWorkItem = nil
        pendingMissingPreferredUID = nil
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
