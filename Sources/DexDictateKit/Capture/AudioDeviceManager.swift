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
                return deviceID
            }
        }

        return nil
    }
}
