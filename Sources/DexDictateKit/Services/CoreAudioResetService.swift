import Foundation

public enum CoreAudioResetError: Error, LocalizedError {
    case appleScriptUnavailable
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .appleScriptUnavailable:
            return "DexDictate could not create the macOS authorization prompt."
        case .commandFailed(let message):
            return message.isEmpty ? "Core Audio reset failed." : message
        }
    }
}

public struct CoreAudioResetService {
    public init() {}

    public func resetCoreAudio() async throws {
        Safety.log("CoreAudioResetService — reset requested by user", category: .audio)
        try await Task.detached(priority: .userInitiated) {
            let source = """
            do shell script "killall -9 coreaudiod" with administrator privileges
            """
            var errorInfo: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                throw CoreAudioResetError.appleScriptUnavailable
            }

            script.executeAndReturnError(&errorInfo)
            if let errorInfo {
                let message = (errorInfo[NSAppleScript.errorMessage] as? String)
                    ?? (errorInfo.description)
                Safety.log("CoreAudioResetService — reset failed: \(message)", category: .audio)
                throw CoreAudioResetError.commandFailed(message)
            }

            Safety.log("CoreAudioResetService — reset completed successfully", category: .audio)
        }.value
    }
}
