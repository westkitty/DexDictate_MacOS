import Foundation
import AVFoundation
import ApplicationServices
import Combine

public enum TriggerValidationState: Equatable {
    case idle
    case ready
    case missingAccessibility
    case missingInputMonitoring
    case eventTapUnavailable

    public var headline: String {
        switch self {
        case .idle:
            return "Trigger test not run yet"
        case .ready:
            return "Trigger capture is ready"
        case .missingAccessibility:
            return "Accessibility is still missing"
        case .missingInputMonitoring:
            return "Input Monitoring is still missing"
        case .eventTapUnavailable:
            return "Event tap could not be created"
        }
    }

    public var detail: String {
        switch self {
        case .idle:
            return "Run the trigger check after granting Accessibility and Input Monitoring."
        case .ready:
            return "DexDictate was able to create the same kind of event tap it needs for global trigger capture."
        case .missingAccessibility:
            return "Grant Accessibility first. Without it, the event tap trust path will not initialize."
        case .missingInputMonitoring:
            return "Grant Input Monitoring so macOS will deliver the global trigger events DexDictate listens for."
        case .eventTapUnavailable:
            return "Permissions look close, but the event tap still failed. A restart or permission re-check may be needed."
        }
    }

    public var isSuccess: Bool {
        self == .ready
    }
}

public enum MicrophoneValidationState: Equatable {
    case idle
    case running
    case ready
    case permissionRequired
    case noDevicesAvailable
    case noInputDetected
    case recorderFailed(String)

    public var headline: String {
        switch self {
        case .idle:
            return "Microphone test not run yet"
        case .running:
            return "Listening for microphone activity"
        case .ready:
            return "Microphone activity detected"
        case .permissionRequired:
            return "Microphone permission is still missing"
        case .noDevicesAvailable:
            return "No microphone devices were found"
        case .noInputDetected:
            return "No microphone activity was detected"
        case .recorderFailed:
            return "Microphone test could not start"
        }
    }

    public var detail: String {
        switch self {
        case .idle:
            return "Run the microphone test to confirm that local capture works before first dictation."
        case .running:
            return "Speak for a moment. DexDictate is checking for actual input level, not just permission state."
        case .ready:
            return "DexDictate saw live microphone input during the test window."
        case .permissionRequired:
            return "Run the microphone test to trigger the macOS permission prompt now. If access was denied earlier, re-enable it in System Settings."
        case .noDevicesAvailable:
            return "macOS did not report any usable audio input devices."
        case .noInputDetected:
            return "The test started, but the input level stayed flat. Check the selected microphone or your hardware mute state."
        case .recorderFailed(let message):
            return "Audio capture failed to start: \(message)"
        }
    }

    public var isSuccess: Bool {
        self == .ready
    }
}

public enum TriggerValidationProbe {
    private static let callback: CGEventTapCallBack = { _, _, event, _ in
        Unmanaged.passUnretained(event)
    }

    public static func runCheck() -> TriggerValidationState {
        guard AXIsProcessTrusted() else {
            return .missingAccessibility
        }

        guard CGPreflightListenEventAccess() else {
            return .missingInputMonitoring
        }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: nil
        ) else {
            return .eventTapUnavailable
        }

        CFMachPortInvalidate(tap)
        return .ready
    }
}

@MainActor
public final class MicrophoneValidationHarness: ObservableObject {
    @Published public private(set) var inputLevel: Double = 0
    @Published public private(set) var state: MicrophoneValidationState = .idle

    private let audioService = AudioRecorderService()
    private var cancellables = Set<AnyCancellable>()
    private var pendingTask: Task<Void, Never>?
    private var maxObservedLevel: Double = 0

    public init() {
        audioService.$inputLevel
            .sink { [weak self] level in
                self?.inputLevel = level
                self?.maxObservedLevel = max(self?.maxObservedLevel ?? 0, level)
            }
            .store(in: &cancellables)
    }

    deinit {
        pendingTask?.cancel()
        audioService.stopRecording()
    }

    public func runTest(inputDeviceUID: String = "", durationSeconds: Double = 1.5) {
        pendingTask?.cancel()
        audioService.stopRecording()
        inputLevel = 0
        maxObservedLevel = 0

        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus == .notDetermined {
            state = .running
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted {
                        self.runTest(inputDeviceUID: inputDeviceUID, durationSeconds: durationSeconds)
                    } else {
                        self.state = .permissionRequired
                        self.inputLevel = 0
                    }
                }
            }
            return
        }

        guard micStatus == .authorized else {
            state = .permissionRequired
            return
        }

        let deviceCount = AudioDeviceManager.inputDevices().count
        guard deviceCount > 0 else {
            state = .noDevicesAvailable
            return
        }

        state = .running
        audioService.startRecordingAsync(inputDeviceUID: inputDeviceUID) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.state = .recorderFailed(error.localizedDescription)
            case .success:
                self.pendingTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(nanoseconds: UInt64(durationSeconds * 1_000_000_000))
                    _ = self.audioService.stopAndCollect()
                    self.inputLevel = 0
                    self.state = self.maxObservedLevel > 0.05 ? .ready : .noInputDetected
                }
            }
        }
    }
}
