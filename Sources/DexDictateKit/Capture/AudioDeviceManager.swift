import AVFoundation
import CoreAudio
import Foundation

public struct AudioInputDevice: Identifiable, Hashable {
    public let uid: String
    public let name: String

    public var id: String { uid }
}

public enum AudioDeviceManager {
    public static func inputDevices() -> [AudioInputDevice] {
        // .microphone and .external are available on all supported targets (macOS 14+).
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return discovery.devices
            .map { AudioInputDevice(uid: $0.uniqueID, name: $0.localizedName) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Returns the CoreAudio `AudioDeviceID` for a device with the given UID, **only
    /// if that device has at least one input channel in the input scope**.
    ///
    /// Searching `kAudioHardwarePropertyDevices` enumerates all CoreAudio devices —
    /// both input-capable and output-only.  Passing an output-only device ID to
    /// `AudioUnitSetProperty(kAudioOutputUnitProperty_CurrentDevice, ...)` succeeds
    /// silently but causes `AVAudioEngine.start()` to fail with
    /// `kAudioOutputUnitErr_InvalidDevice` (-10868) because the AUHAL cannot open an
    /// input stream on a device that has no input channels.  This guard prevents that
    /// by only returning device IDs for devices that report ≥ 1 input channel.
    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        let sizeStatus = AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &dataSize)
        if sizeStatus != noErr || dataSize == 0 {
            return nil
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        let listStatus = AudioObjectGetPropertyData(systemObject, &address, 0, nil, &dataSize, &deviceIDs)
        if listStatus != noErr {
            return nil
        }

        for deviceID in deviceIDs {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            // CoreAudio writes a retained CFString into the pointer; we use
            // Unmanaged to avoid a double-retain and keep memory ownership explicit.
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
            var unmanagedUID: Unmanaged<CFString>? = nil
            let uidStatus = withUnsafeMutablePointer(to: &unmanagedUID) { ptr in
                AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize,
                                          UnsafeMutableRawPointer(ptr))
            }
            if uidStatus == noErr,
               let deviceUID = unmanagedUID?.takeRetainedValue() as String?,
               deviceUID == uid {
                // Found a UID match — verify the device actually has input channels
                // before returning it.  Output-only devices cause engine.start() to
                // fail with kAudioOutputUnitErr_InvalidDevice (-10868).
                guard Self.hasInputChannels(deviceID: deviceID) else {
                    return nil
                }
                return deviceID
            }
        }

        return nil
    }

    /// Returns `true` if the CoreAudio device with `deviceID` reports at least one
    /// channel in `kAudioObjectPropertyScopeInput`.
    private static func hasInputChannels(deviceID: AudioDeviceID) -> Bool {
        var streamAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &dataSize)
        guard sizeStatus == noErr, dataSize > 0 else { return false }

        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(dataSize))
        defer { bufferList.deallocate() }
        let dataStatus = AudioObjectGetPropertyData(deviceID, &streamAddress, 0, nil, &dataSize, bufferList)
        guard dataStatus == noErr else { return false }

        // AudioBufferList.mBuffers is a C flexible array member; use withUnsafePointer
        // to obtain a valid, scoped pointer to the first element before iterating.
        let count = Int(bufferList.pointee.mNumberBuffers)
        return withUnsafePointer(to: &bufferList.pointee.mBuffers) { firstBuffer in
            UnsafeBufferPointer(start: firstBuffer, count: count)
                .contains { $0.mNumberChannels > 0 }
        }
    }
}
