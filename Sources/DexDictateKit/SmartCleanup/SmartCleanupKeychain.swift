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
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            // Previously discarded entirely — the caller (SmartCleanupSettings.apiKey's
            // setter) has no other way to know the save failed, so the user would believe
            // Smart Cleanup is configured when a subsequent `load()` silently returns nil.
            Safety.log(
                "SmartCleanupKeychain.save() — SecItemAdd failed with OSStatus \(status); API key was not persisted",
                category: .settings
            )
        }
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
