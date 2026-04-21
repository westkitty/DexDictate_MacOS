import AVFoundation
import CoreAudio
import Foundation

public struct AudioInputDevice: Identifiable, Hashable {
    public let uid: String
    public let name: String

    public var id: String { uid }
}

public struct AudioInputDeviceMatch: Equatable {
    public let uid: String
    public let deviceID: AudioDeviceID
    public let hasInputChannels: Bool
}

public enum AudioInputDeviceResolution: Equatable {
    case systemDefault
    case available(AudioInputDeviceMatch)
    case missing(uid: String)
    case unavailableAsInput(uid: String, deviceID: AudioDeviceID?)
}

struct AudioHardwareDeviceRecord: Equatable {
    let deviceID: AudioDeviceID
    let uid: String
    let hasInputChannels: Bool
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
        if case .available(let match) = resolveInputDevice(forUID: uid) {
            return match.deviceID
        }
        return nil
    }

    static func resolveInputDevice(forUID uid: String) -> AudioInputDeviceResolution {
        guard !uid.isEmpty else { return .systemDefault }

        let deviceRecords = enumerateCoreAudioDevices()
        return resolveInputDevice(forUID: uid, deviceRecords: deviceRecords)
    }

    static func resolveInputDevice(forUID uid: String, deviceRecords: [AudioHardwareDeviceRecord]) -> AudioInputDeviceResolution {
        guard !uid.isEmpty else { return .systemDefault }

        for record in deviceRecords where record.uid == uid {
            if record.hasInputChannels {
                return .available(
                    AudioInputDeviceMatch(uid: record.uid, deviceID: record.deviceID, hasInputChannels: true)
                )
            }
            return .unavailableAsInput(uid: record.uid, deviceID: record.deviceID)
        }

        return .missing(uid: uid)
    }

    private static func enumerateCoreAudioDevices() -> [AudioHardwareDeviceRecord] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        let sizeStatus = AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &dataSize)
        if sizeStatus != noErr || dataSize == 0 {
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        let listStatus = AudioObjectGetPropertyData(systemObject, &address, 0, nil, &dataSize, &deviceIDs)
        if listStatus != noErr {
            return []
        }

        var records: [AudioHardwareDeviceRecord] = []
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
               let deviceUID = unmanagedUID?.takeRetainedValue() as String? {
                records.append(
                    AudioHardwareDeviceRecord(
                        deviceID: deviceID,
                        uid: deviceUID,
                        hasInputChannels: Self.hasInputChannels(deviceID: deviceID)
                    )
                )
            }
        }

        return records
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
