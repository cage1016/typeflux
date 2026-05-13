import Foundation
import os
import Security

/// Stores authentication tokens in the macOS Keychain.
enum KeychainTokenStore {
    private struct StoredToken: Codable {
        let token: String
        let expiresAt: Int
        let refreshToken: String?
    }

    private static let service = "ai.gulu.app.typeflux.auth"
    private static let legacyServices = [
        "ai.gulu.app.typeflux.auth.v2",
        "ai.gulu.app.typeflux.auth.v1",
    ]

    private static var runtimeDerivedService: String {
        let environmentBundleID = ProcessInfo.processInfo.environment["TYPEFLUX_BUNDLE_IDENTIFIER"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleID = environmentBundleID?.isEmpty == false
            ? environmentBundleID!
            : (Bundle.main.bundleIdentifier ?? "ai.gulu.app.typeflux")
        return "\(bundleID).auth"
    }

    private static var serviceCandidates: [String] {
        let candidates = [service] + legacyServices + [runtimeDerivedService]
        var seen = Set<String>()
        return candidates.filter { candidate in
            seen.insert(candidate).inserted
        }
    }

    private static let tokenAccount = "session"
    private static let userProfileAccount = "userProfile"
    private static let logger = Logger(subsystem: "ai.gulu.app.typeflux", category: "KeychainTokenStore")
    private static let inMemoryLock = NSLock()
    private static var inMemoryValues: [String: Data] = [:]
    static var useInMemoryStoreForTesting = false

    private static var usesInMemoryStore: Bool {
        useInMemoryStoreForTesting
    }

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
    private static func setKeychainValue(_ value: some Encodable, account: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else {
            logger.error("Failed to encode keychain value for account \(account, privacy: .public)")
            return false
        }

        if usesInMemoryStore {
            inMemoryLock.lock()
            inMemoryValues[account] = data
            inMemoryLock.unlock()
            return true
        }

        for query in writeMatchingQueries(service: service, account: account) {
            let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if updateStatus == errSecSuccess {
                return true
            }
            if updateStatus != errSecItemNotFound {
                logger.error(
                    "Failed to update keychain account \(account, privacy: .public): \(describeStatus(updateStatus), privacy: .public)",
                )
            }
        }

        var addQuery = addQuery(service: service, account: account)
        addQuery[kSecValueData as String] = data

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return true
        }
        if addStatus == errSecDuplicateItem {
            logger.error(
                "Keychain account \(account, privacy: .public) already exists but update did not match; replacing stale item"
            )
            if replaceKeychainValue(data, account: account) || updateDuplicateKeychainValue(data, account: account) {
                return true
            }
            return false
        }
        logger.error(
            "Failed to add keychain account \(account, privacy: .public): \(describeStatus(addStatus), privacy: .public)",
        )
        return false
    }

    private static func getKeychainValue<Value: Decodable>(account: String) -> Value? {
        if usesInMemoryStore {
            inMemoryLock.lock()
            let data = inMemoryValues[account]
            inMemoryLock.unlock()
            guard let data else { return nil }
            return try? JSONDecoder().decode(Value.self, from: data)
        }

        for candidateService in serviceCandidates {
            if let value: Value = getKeychainValue(account: account, service: candidateService) {
                if candidateService != service {
                    migrateLegacyItem(account: account, from: candidateService)
                }
                return value
            }
        }
        return nil
    }

    private static func getKeychainValue<Value: Decodable>(account: String, service candidateService: String) -> Value? {
        let queries = readMatchingQueries(service: candidateService, account: account)

        var result: AnyObject?
        let status = copyFirstMatching(queries, result: &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                logger.error(
                    "Failed to load keychain account \(account, privacy: .public): \(describeStatus(status), privacy: .public)",
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
        if usesInMemoryStore {
            inMemoryLock.lock()
            inMemoryValues.removeValue(forKey: account)
            inMemoryLock.unlock()
            return
        }

        for candidateService in serviceCandidates {
            for query in deleteMatchingQueries(service: candidateService, account: account) {
                let status = SecItemDelete(query as CFDictionary)
                if status != errSecSuccess, status != errSecItemNotFound {
                    logger.error(
                        "Failed to delete keychain account \(account, privacy: .public): \(describeStatus(status), privacy: .public)"
                    )
                }
            }
        }
    }

    private static func migrateLegacyItem(account: String, from legacyService: String) {
        let queries = readMatchingQueries(service: legacyService, account: account)

        var result: AnyObject?
        let status = copyFirstMatching(queries, result: &result)
        guard status == errSecSuccess, let data = result as? Data else { return }

        let primaryQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        var addQuery = primaryQuery
        addQuery[kSecValueData as String] = data

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess || addStatus == errSecDuplicateItem {
            logger.info(
                "Migrated keychain account \(account, privacy: .public) from legacy service \(legacyService, privacy: .public)"
            )
        } else {
            logger.error(
                "Failed to migrate keychain account \(account, privacy: .public): \(describeStatus(addStatus), privacy: .public)"
            )
        }
    }

    private static func replaceKeychainValue(_ data: Data, account: String) -> Bool {
        deleteKeychainItem(account: account)

        var addQuery = addQuery(service: service, account: account)
        addQuery[kSecValueData as String] = data

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return true
        }
        logger.error(
            "Failed to replace keychain account \(account, privacy: .public): \(describeStatus(addStatus), privacy: .public)"
        )
        return false
    }

    private static func updateDuplicateKeychainValue(_ data: Data, account: String) -> Bool {
        for query in writeMatchingQueries(service: service, account: account) {
            let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if status == errSecSuccess {
                return true
            }
            if status != errSecItemNotFound {
                logger.error(
                    "Failed to update duplicate keychain account \(account, privacy: .public): \(describeStatus(status), privacy: .public)"
                )
            }
        }
        logger.error("Failed to update duplicate keychain account \(account, privacy: .public)")
        return false
    }

    private static func copyFirstMatching(_ queries: [[String: Any]], result: inout AnyObject?) -> OSStatus {
        var lastStatus: OSStatus = errSecItemNotFound
        for query in queries {
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecSuccess {
                return status
            }
            lastStatus = status
        }
        return lastStatus
    }

    private static func readMatchingQueries(service queryService: String, account: String) -> [[String: Any]] {
        searchQueries(service: queryService, account: account).map { query in
            var readQuery = query
            readQuery[kSecReturnData as String] = true
            readQuery[kSecMatchLimit as String] = kSecMatchLimitOne
            return readQuery
        }
    }

    private static func writeMatchingQueries(service queryService: String, account: String) -> [[String: Any]] {
        searchQueries(service: queryService, account: account)
    }

    private static func deleteMatchingQueries(service queryService: String, account: String) -> [[String: Any]] {
        searchQueries(service: queryService, account: account)
    }

    private static func searchQueries(service queryService: String, account: String) -> [[String: Any]] {
        var nonSynchronizableQuery = addQuery(service: queryService, account: account)
        nonSynchronizableQuery[kSecAttrSynchronizable as String] = false

        return [
            addQuery(service: queryService, account: account),
            nonSynchronizableQuery,
        ]
    }

    private static func addQuery(service queryService: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: queryService,
            kSecAttrAccount as String: account,
        ]
    }

    private static func describeStatus(_ status: OSStatus) -> String {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return "\(status) (\(message))"
        }
        return "\(status)"
    }
}
