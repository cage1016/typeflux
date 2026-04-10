import Foundation
import Security

/// Stores authentication tokens in the macOS Keychain.
struct KeychainTokenStore {
    private static let service = "dev.typeflux.auth"
    private static let tokenAccount = "accessToken"
    private static let expiresAtAccount = "expiresAt"
    private static let userProfileAccount = "userProfile"

    // MARK: - Token

    static func saveToken(_ token: String, expiresAt: Int) {
        setKeychainString(token, account: tokenAccount)
        setKeychainString(String(expiresAt), account: expiresAtAccount)
    }

    static func loadToken() -> (token: String, expiresAt: Int)? {
        guard let token = getKeychainString(account: tokenAccount),
              let expiresAtString = getKeychainString(account: expiresAtAccount),
              let expiresAt = Int(expiresAtString)
        else {
            return nil
        }
        return (token, expiresAt)
    }

    static func deleteToken() {
        deleteKeychainItem(account: tokenAccount)
        deleteKeychainItem(account: expiresAtAccount)
    }

    static var isTokenValid: Bool {
        guard let stored = loadToken() else { return false }
        return stored.expiresAt > Int(Date().timeIntervalSince1970)
    }

    // MARK: - User Profile

    static func saveUserProfile(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile),
              let json = String(data: data, encoding: .utf8)
        else {
            return
        }
        setKeychainString(json, account: userProfileAccount)
    }

    static func loadUserProfile() -> UserProfile? {
        guard let json = getKeychainString(account: userProfileAccount),
              let data = json.data(using: .utf8),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else {
            return nil
        }
        return profile
    }

    static func deleteUserProfile() {
        deleteKeychainItem(account: userProfileAccount)
    }

    // MARK: - Clear All

    static func clearAll() {
        deleteToken()
        deleteUserProfile()
    }

    // MARK: - Keychain Helpers

    private static func setKeychainString(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private static func getKeychainString(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return string
    }

    private static func deleteKeychainItem(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
