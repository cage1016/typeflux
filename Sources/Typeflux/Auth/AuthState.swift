import Foundation
import os

extension Notification.Name {
    /// Posted on the main actor after a successful explicit login
    /// (email/password, Google/Apple/GitHub OAuth). Not fired on silent
    /// token refresh or session restore at app launch.
    static let authDidLogin = Notification.Name("AuthState.authDidLogin")

    /// Posted on the main actor when a checkout-started subscription refresh
    /// observes that the account has become entitled to Typeflux Cloud.
    static let authCheckoutSubscriptionDidBecomeEntitled = Notification.Name(
        "AuthState.authCheckoutSubscriptionDidBecomeEntitled",
    )
}

/// Observable auth state manager, shared across the app.
@MainActor
final class AuthState: ObservableObject {
    enum SessionRefreshResult: Equatable {
        case authenticated
        case unauthenticated
        case failed
    }

    private enum AccessTokenRefreshResult: Equatable {
        case refreshed
        case unavailable
        case failed
        case invalidated
    }

    static let shared = AuthState()

    private let logger = Logger(subsystem: "ai.gulu.app.typeflux", category: "AuthState")
    private let loadStoredToken: () -> (token: String, expiresAt: Int)?
    private let loadStoredRefreshToken: () -> String?
    private let loadStoredUserProfile: () -> UserProfile?
    private let saveStoredToken: (String, Int) -> Void
    private let saveStoredSession: (String, Int, String?) -> Void
    private let saveStoredUserProfile: (UserProfile) -> Void
    private let clearStoredSession: () -> Void
    private let fetchProfile: (String) async throws -> UserProfile
    private let refreshAccessToken: (String) async throws -> LoginResponse
    private let fetchSubscription: (String) async throws -> BillingSubscriptionSnapshot
    private let fetchCurrentPeriodUsageStats: (String) async throws -> CloudUsageCurrentPeriodStats
    private let createCheckoutSession: (String, String) async throws -> BillingCheckoutSession
    private let createPortalSession: (String) async throws -> BillingPortalSession

    @Published private(set) var isLoggedIn: Bool = false
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var subscription: BillingSubscriptionSnapshot = .none
    @Published private(set) var isLoadingSubscription: Bool = false
    @Published private(set) var subscriptionError: String?
    @Published private(set) var usageStats: CloudUsageStats = .empty
    @Published private(set) var usagePeriodStart: String?
    @Published private(set) var usagePeriodEnd: String?
    @Published private(set) var isLoadingUsage: Bool = false
    @Published private(set) var usageError: String?

    /// Refresh the access token when it expires within this window (7 days).
    private static let refreshEarlyInterval: TimeInterval = 7 * 24 * 3600

    /// Background timer interval: check every hour.
    private static let timerInterval: TimeInterval = 3600
    private static let checkoutPollingAttempts = 120
    private static let checkoutPollingInterval: Duration = .seconds(3)

    private var refreshTimer: Timer?
    private var checkoutPollingTask: Task<Void, Never>?
    private var pendingCheckoutSubscriptionEntitlement = false
    private var inMemorySessionToken: (token: String, expiresAt: Int)?
    private var cachedStoredToken: (token: String, expiresAt: Int)?
    private var cachedRefreshToken: String?

    var accessToken: String? {
        if let inMemorySessionToken,
           inMemorySessionToken.expiresAt > Int(Date().timeIntervalSince1970)
        {
            return inMemorySessionToken.token
        }
        guard let stored = cachedStoredToken,
              stored.expiresAt > Int(Date().timeIntervalSince1970)
        else {
            return nil
        }
        return stored.token
    }

    init(
        loadStoredToken: @escaping () -> (token: String, expiresAt: Int)? = {
            KeychainTokenStore.loadToken()
        },
        loadStoredRefreshToken: @escaping () -> String? = {
            KeychainTokenStore.loadRefreshToken()
        },
        loadStoredUserProfile: @escaping () -> UserProfile? = {
            KeychainTokenStore.loadUserProfile()
        },
        saveStoredToken: @escaping (String, Int) -> Void = { token, expiresAt in
            KeychainTokenStore.saveToken(token, expiresAt: expiresAt)
        },
        saveStoredSession: ((String, Int, String?) -> Void)? = nil,
        saveStoredUserProfile: @escaping (UserProfile) -> Void = { profile in
            KeychainTokenStore.saveUserProfile(profile)
        },
        clearStoredSession: @escaping () -> Void = {
            KeychainTokenStore.clearAll()
        },
        fetchProfile: @escaping (String) async throws -> UserProfile = { token in
            try await AuthAPIService.fetchProfile(token: token)
        },
        refreshAccessToken: @escaping (String) async throws -> LoginResponse = { refreshToken in
            try await AuthAPIService.refreshToken(refreshToken)
        },
        fetchSubscription: @escaping (String) async throws -> BillingSubscriptionSnapshot = { token in
            try await BillingAPIService.fetchSubscription(token: token)
        },
        fetchCurrentPeriodUsageStats: @escaping (String) async throws -> CloudUsageCurrentPeriodStats = { token in
            try await CloudUsageAPIService.fetchCurrentPeriodStats(token: token)
        },
        createCheckoutSession: @escaping (String, String) async throws -> BillingCheckoutSession = { token, planCode in
            try await BillingAPIService.createCheckoutSession(token: token, planCode: planCode)
        },
        createPortalSession: @escaping (String) async throws -> BillingPortalSession = { token in
            try await BillingAPIService.createPortalSession(token: token)
        },
    ) {
        self.loadStoredToken = loadStoredToken
        self.loadStoredRefreshToken = loadStoredRefreshToken
        self.loadStoredUserProfile = loadStoredUserProfile
        self.saveStoredToken = saveStoredToken
        self.saveStoredSession = saveStoredSession ?? { token, expiresAt, refreshToken in
            if let refreshToken {
                KeychainTokenStore.saveToken(token, expiresAt: expiresAt, refreshToken: refreshToken)
            } else {
                saveStoredToken(token, expiresAt)
            }
        }
        self.saveStoredUserProfile = saveStoredUserProfile
        self.clearStoredSession = clearStoredSession
        self.fetchProfile = fetchProfile
        self.refreshAccessToken = refreshAccessToken
        self.fetchSubscription = fetchSubscription
        self.fetchCurrentPeriodUsageStats = fetchCurrentPeriodUsageStats
        self.createCheckoutSession = createCheckoutSession
        self.createPortalSession = createPortalSession
        restoreSession()
    }

    // MARK: - Session Restore

    private func restoreSession() {
        let storedToken = loadStoredToken()
        cachedStoredToken = storedToken
        cachedRefreshToken = loadStoredRefreshToken()
        let hasValidAccessToken = accessToken != nil
        let hasRefreshToken = hasStoredRefreshToken
        logger.info(
            "Session restore: storedAccessToken=\(storedToken != nil, privacy: .public), validAccessToken=\(hasValidAccessToken, privacy: .public), storedRefreshToken=\(hasRefreshToken, privacy: .public)"
        )
        if hasValidAccessToken {
            userProfile = loadStoredUserProfile()
            isLoggedIn = true
            Task { await refreshProfile() }
            Task { await refreshTokenIfNeeded() }
        } else if hasRefreshToken {
            userProfile = loadStoredUserProfile()
            isLoggedIn = true
            Task {
                switch await refreshStoredAccessToken(force: true) {
                case .refreshed:
                    await refreshProfile()
                case .invalidated:
                    logout()
                case .failed, .unavailable:
                    logger.error("Session restore could not refresh access token")
                }
            }
        }
        startRefreshTimer()
    }

    // MARK: - Login

    func handleLoginSuccess(token: String, expiresAt: Int, refreshToken: String? = nil) async {
        let normalizedExpiresAt = normalizeLoginExpiry(expiresAt)
        inMemorySessionToken = (token, normalizedExpiresAt)
        cachedStoredToken = (token, normalizedExpiresAt)
        cachedRefreshToken = refreshToken
        saveStoredSession(token, normalizedExpiresAt, refreshToken)
        logger.info(
            "Login session saved: expiresAt=\(normalizedExpiresAt, privacy: .public), refreshTokenProvided=\((refreshToken?.isEmpty == false), privacy: .public)"
        )
        isLoggedIn = true
        await refreshProfile()
        NotificationCenter.default.post(name: .authDidLogin, object: self)
    }

    // MARK: - Logout

    func logout() {
        if let refreshToken = cachedRefreshToken {
            Task {
                try? await AuthAPIService.logout(refreshToken: refreshToken)
            }
        }
        inMemorySessionToken = nil
        cachedStoredToken = nil
        cachedRefreshToken = nil
        clearStoredSession()
        isLoggedIn = false
        userProfile = nil
        subscription = .none
        subscriptionError = nil
        usageStats = .empty
        usagePeriodStart = nil
        usagePeriodEnd = nil
        usageError = nil
        pendingCheckoutSubscriptionEntitlement = false
        checkoutPollingTask?.cancel()
        checkoutPollingTask = nil
        logger.info("User logged out")
    }

    // MARK: - Token Refresh

    /// Refreshes the access token when it will expire within 7 days.
    /// Safe to call from multiple trigger points; skips silently when not needed.
    func refreshTokenIfNeeded() async {
        guard isLoggedIn else { return }
        let result = await refreshStoredAccessToken(force: false)
        if result == .invalidated {
            logout()
        }
    }

    // MARK: - Profile Refresh

    func refreshProfileIfNeeded() {
        guard isLoggedIn || accessToken != nil else { return }
        Task { await refreshProfile() }
    }

    @discardableResult
    func refreshProfile() async -> SessionRefreshResult {
        await refreshProfile(allowTokenRefresh: true)
    }

    @discardableResult
    private func refreshProfile(allowTokenRefresh: Bool) async -> SessionRefreshResult {
        guard let token = accessToken else {
            logger.error("Profile refresh found no valid access token; clearing session")
            logout()
            return .unauthenticated
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await fetchProfile(token)
            userProfile = profile
            saveStoredUserProfile(profile)
            logger.info("Profile refreshed for \(profile.email)")
            await refreshSubscription()
            return .authenticated
        } catch let error as AuthError {
            if shouldInvalidateSession(for: error) {
                if allowTokenRefresh {
                    switch await refreshStoredAccessToken(force: true) {
                    case .refreshed:
                        return await refreshProfile(allowTokenRefresh: false)
                    case .failed:
                        logger.error("Profile refresh could not refresh access token: \(error.localizedDescription)")
                        return .failed
                    case .invalidated, .unavailable:
                        break
                    }
                }
                logout()
                logger.error("Profile refresh invalidated session: \(error.localizedDescription)")
                return .unauthenticated
            }
            logger.error("Failed to refresh profile: \(error.localizedDescription)")
            return .failed
        } catch {
            logger.error("Failed to refresh profile: \(error.localizedDescription)")
            return .failed
        }
    }

    // MARK: - Subscription

    func refreshSubscriptionIfNeeded() {
        guard isLoggedIn || accessToken != nil else { return }
        Task { await refreshSubscription() }
    }

    @discardableResult
    func refreshSubscription() async -> BillingSubscriptionSnapshot? {
        guard let token = accessToken else {
            subscription = .none
            return nil
        }

        isLoadingSubscription = true
        defer { isLoadingSubscription = false }

        do {
            let wasEntitled = subscription.entitled
            let snapshot = try await fetchSubscription(token)
            subscription = snapshot
            subscriptionError = nil
            if pendingCheckoutSubscriptionEntitlement, !wasEntitled, snapshot.entitled {
                pendingCheckoutSubscriptionEntitlement = false
                NotificationCenter.default.post(name: .authCheckoutSubscriptionDidBecomeEntitled, object: self)
            }
            return snapshot
        } catch let error as AuthError {
            subscriptionError = error.localizedDescription
            return nil
        } catch {
            subscriptionError = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func refreshUsage() async -> CloudUsageStats? {
        guard let token = accessToken else {
            usageStats = .empty
            return nil
        }

        isLoadingUsage = true
        defer { isLoadingUsage = false }

        do {
            let snapshot = try await fetchCurrentPeriodUsageStats(token)
            usageStats = snapshot.stats
            usagePeriodStart = snapshot.periodStart
            usagePeriodEnd = snapshot.periodEnd
            usageError = nil
            return snapshot.stats
        } catch let error as AuthError {
            if error.authErrorCode == "USAGE_PERIOD_UNAVAILABLE" {
                usageStats = .empty
                usagePeriodStart = nil
                usagePeriodEnd = nil
                usageError = nil
            } else {
                usageError = error.localizedDescription
            }
            return nil
        } catch {
            usageError = error.localizedDescription
            return nil
        }
    }

    func startCheckout(planCode: String = BillingPlan.defaultPlanCode) async throws -> URL {
        guard let token = accessToken else {
            throw AuthError.unauthorized
        }
        let session = try await createCheckoutSession(token, planCode)
        if !subscription.entitled {
            pendingCheckoutSubscriptionEntitlement = true
        }
        startCheckoutPolling()
        return session.url
    }

    func createBillingPortalSession() async throws -> URL {
        guard let token = accessToken else {
            throw AuthError.unauthorized
        }
        let session = try await createPortalSession(token)
        return session.url
    }

    private func startCheckoutPolling() {
        checkoutPollingTask?.cancel()
        checkoutPollingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for attempt in 0 ..< Self.checkoutPollingAttempts {
                if attempt > 0 {
                    try? await Task.sleep(for: Self.checkoutPollingInterval)
                }
                guard !Task.isCancelled else { return }
                _ = await refreshSubscription()
                if subscription.entitled {
                    return
                }
            }
            pendingCheckoutSubscriptionEntitlement = false
        }
    }

    // MARK: - Background Timer

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.timerInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshTokenIfNeeded()
            }
        }
    }

    // MARK: - Helpers

    private func shouldInvalidateSession(for error: AuthError) -> Bool {
        switch error {
        case .unauthorized:
            true
        case let .serverError(code, _):
            code == "USER_NOT_FOUND"
                || code == "AUTH_REFRESH_TOKEN_INVALID"
                || code == "AUTH_REFRESH_TOKEN_REUSED"
        case .networkError, .invalidResponse:
            false
        }
    }

    private var hasStoredRefreshToken: Bool {
        guard let refreshToken = cachedRefreshToken else { return false }
        return !refreshToken.isEmpty
    }

    private func refreshStoredAccessToken(force: Bool) async -> AccessTokenRefreshResult {
        if !force, !isAccessTokenExpiringSoon() {
            return .unavailable
        }

        guard let refreshToken = cachedRefreshToken, !refreshToken.isEmpty else {
            logger.debug("Access token refresh needed but no refresh token is stored")
            return .unavailable
        }

        logger.info("Refreshing access token...")
        do {
            let response = try await refreshAccessToken(refreshToken)
            let normalizedExpiresAt = normalizeLoginExpiry(response.expiresAt)
            saveStoredSession(
                response.accessToken,
                normalizedExpiresAt,
                response.refreshToken ?? refreshToken
            )
            inMemorySessionToken = (response.accessToken, normalizedExpiresAt)
            cachedStoredToken = (response.accessToken, normalizedExpiresAt)
            cachedRefreshToken = response.refreshToken ?? refreshToken
            logger.info("Token refreshed successfully")
            return .refreshed
        } catch let error as AuthError {
            logger.error("Token refresh failed: \(error.localizedDescription)")
            return shouldInvalidateSession(for: error) ? .invalidated : .failed
        } catch {
            logger.error("Token refresh error: \(error.localizedDescription)")
            return .failed
        }
    }

    private func isAccessTokenExpiringSoon() -> Bool {
        let now = Int(Date().timeIntervalSince1970)
        let threshold = Int(Date().timeIntervalSince1970 + Self.refreshEarlyInterval)
        if let inMemorySessionToken, inMemorySessionToken.expiresAt > now {
            return inMemorySessionToken.expiresAt < threshold
        }
        guard let stored = cachedStoredToken else { return true }
        return stored.expiresAt < threshold
    }

    private func normalizeLoginExpiry(_ expiresAt: Int) -> Int {
        let now = Int(Date().timeIntervalSince1970)
        // Accept common server variants: Unix milliseconds and expires-in seconds.
        if expiresAt > 10_000_000_000 {
            return expiresAt / 1000
        }
        if expiresAt > now {
            return expiresAt
        }
        if expiresAt > 0, expiresAt <= 31_536_000 {
            return now + expiresAt
        }
        return expiresAt
    }
}
