import Foundation
import os
import Security

/// Stores authentication tokens in the macOS Keychain.
struct KeychainTokenStore {
    private struct StoredToken: Codable {
        let token: String
        let expiresAt: Int
        let refreshToken: String?
    }

    private static var service: String {
        let environmentBundleID = ProcessInfo.processInfo.environment["TYPEFLUX_BUNDLE_IDENTIFIER"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleID = environmentBundleID?.isEmpty == false
            ? environmentBundleID!
            : (Bundle.main.bundleIdentifier ?? "ai.gulu.app.typeflux")
        return "\(bundleID).auth"
    }
    private static let tokenAccount = "session"
    private static let userProfileAccount = "userProfile"
    private static let logger = Logger(subsystem: "ai.gulu.app.typeflux", category: "KeychainTokenStore")

    // MARK: - Token

    @discardableResult
    static func saveToken(_ token: String, expiresAt: Int, refreshToken: String? = nil) -> Bool {
        let storedToken = StoredToken(token: token, expiresAt: expiresAt, refreshToken: refreshToken)
        return setKeychainValue(storedToken, account: tokenAccount)
    }

    static func loadToken() -> (token: String, expiresAt: Int)? {
        guard let storedToken: StoredToken = getKeychainValue(account: tokenAccount) else {
            return nil
        }
        return (storedToken.token, storedToken.expiresAt)
    }

    static func loadRefreshToken() -> String? {
        let stored: StoredToken? = getKeychainValue(account: tokenAccount)
        return stored?.refreshToken
    }

    static func deleteToken() {
        deleteKeychainItem(account: tokenAccount)
    }

    static var isTokenValid: Bool {
        guard let stored = loadToken() else { return false }
        return stored.expiresAt > Int(Date().timeIntervalSince1970)
    }

    /// Returns true if the access token will expire within the given interval.
    static func isTokenExpiringSoon(within interval: TimeInterval = 7 * 24 * 3600) -> Bool {
        guard let stored = loadToken() else { return true }
        let threshold = Int(Date().timeIntervalSince1970 + interval)
        return stored.expiresAt < threshold
    }

    // MARK: - User Profile

    @discardableResult
    static func saveUserProfile(_ profile: UserProfile) -> Bool {
        setKeychainValue(profile, account: userProfileAccount)
    }

    static func loadUserProfile() -> UserProfile? {
        getKeychainValue(account: userProfileAccount)
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

    @discardableResult
    private static func setKeychainValue<Value: Encodable>(_ value: Value, account: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else {
            logger.error("Failed to encode keychain value for account \(account, privacy: .public)")
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        if updateStatus != errSecItemNotFound {
            logger.error(
                "Failed to update keychain account \(account, privacy: .public): \(describeStatus(updateStatus), privacy: .public)"
            )
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return true
        }
        logger.error(
            "Failed to add keychain account \(account, privacy: .public): \(describeStatus(addStatus), privacy: .public)"
        )
        return false
    }

    private static func getKeychainValue<Value: Decodable>(account: String) -> Value? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                logger.error(
                    "Failed to load keychain account \(account, privacy: .public): \(describeStatus(status), privacy: .public)"
                )
            }
            return nil
        }
        guard let data = result as? Data else {
            logger.error("Loaded non-data keychain value for account \(account, privacy: .public)")
            return nil
        }
        guard let value = try? JSONDecoder().decode(Value.self, from: data) else {
            logger.error("Failed to decode keychain value for account \(account, privacy: .public)")
            return nil
        }
        return value
    }

    private static func deleteKeychainItem(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func describeStatus(_ status: OSStatus) -> String {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return "\(status) (\(message))"
        }
        return "\(status)"
    }
}
