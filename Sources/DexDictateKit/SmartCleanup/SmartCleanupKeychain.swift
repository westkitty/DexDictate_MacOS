import Foundation
import Security

/// Minimal Keychain wrapper for the Smart Cleanup API key. Scoped to a single generic
/// password item (service + account); no access-group entitlement is required since this
/// app is not sandboxed (`Sources/DexDictate/DexDictate.entitlements` has no
/// `com.apple.security.app-sandbox` key) — `SecItemAdd`/`SecItemCopyMatching` against the
/// default access group work without any entitlement changes.
enum SmartCleanupKeychain {
    private static let service = "com.westkitty.dexdictate.macos.smartcleanup"
    private static let account = "apiKey"

    static func save(_ value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        guard !value.isEmpty else { return }

        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
