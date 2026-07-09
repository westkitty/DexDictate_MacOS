import SwiftUI
import Foundation

/// Persistent settings for Smart Cleanup (LLM post-processing of the committed transcript
/// via an OpenAI-compatible endpoint, e.g. a remote Ollama tunnel). Isolated from
/// `AppSettings` per this packet's own architecture — Smart Cleanup is not a transcription
/// provider and must never appear alongside Models & Accuracy. `enabled` defaults to
/// `false`; when off, `SmartCleanupCoordinator` makes zero network requests.
@MainActor
public final class SmartCleanupSettings: ObservableObject {
    public static let shared = SmartCleanupSettings()

    @AppStorage("smartCleanupEnabled") public var enabled: Bool = false
    /// Example placeholder only — never a hard-coded default. Deliberately empty until the
    /// user fills it in with their own tunnel/server address.
    @AppStorage("smartCleanupBaseURL") public var baseURLString: String = ""
    @AppStorage("smartCleanupModel") public var model: String = ""

    /// Backed by Keychain, never `UserDefaults` — API keys must not land in a plist.
    public var apiKey: String {
        get { SmartCleanupKeychain.load() ?? "" }
        set { SmartCleanupKeychain.save(newValue) }
    }

    private init() {}
}

/// Pure, network-free URL validation — kept separate from `SmartCleanupClient` so it can be
/// unit tested without a live endpoint.
public enum SmartCleanupURLValidation {
    /// A base URL is valid if it parses with an `http`/`https` scheme and a non-empty host.
    public static func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              let host = url.host, !host.isEmpty else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }

    /// True when the URL is cleartext (`http`, not `https`) and its host is not a loopback
    /// address — i.e. text would travel unencrypted to a non-local machine. Used to show a
    /// non-blocking warning, never to reject the URL.
    public static func isNonLoopbackCleartext(_ string: String) -> Bool {
        guard let url = URL(string: string),
              url.scheme?.lowercased() == "http",
              let host = url.host, !host.isEmpty else {
            return false
        }
        return !isLoopbackHost(host)
    }

    private static func isLoopbackHost(_ host: String) -> Bool {
        let normalized = host.lowercased()
        return normalized == "127.0.0.1"
            || normalized == "localhost"
            || normalized == "::1"
            || normalized.hasPrefix("127.")
    }
}
