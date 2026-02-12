import AVFoundation
import CoreAudio
import Foundation

struct AudioInputDevice: Identifiable, Hashable {
    let uid: String
    let name: String

    var id: String { uid }
}

enum AudioDeviceManager {
    static func inputDevices() -> [AudioInputDevice] {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            deviceTypes = [.microphone, .external]
        } else {
            deviceTypes = [.builtInMicrophone, .externalUnknown]
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
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
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            var deviceUID: CFString = "" as CFString
            let uidStatus = withUnsafeMutablePointer(to: &deviceUID) { uidPtr -> OSStatus in
                uidPtr.withMemoryRebound(to: UInt8.self, capacity: Int(uidSize)) { rawPtr in
                    AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, rawPtr)
                }
            }
            if uidStatus == noErr && deviceUID as String == uid {
                return deviceID
            }
        }

        return nil
    }
}
