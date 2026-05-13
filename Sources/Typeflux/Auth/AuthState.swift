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

    static let shared = AuthState()

    private let logger = Logger(subsystem: "ai.gulu.app.typeflux", category: "AuthState")
    private let loadStoredToken: () -> (token: String, expiresAt: Int)?
    private let loadStoredUserProfile: () -> UserProfile?
    private let saveStoredToken: (String, Int) -> Void
    private let saveStoredUserProfile: (UserProfile) -> Void
    private let clearStoredSession: () -> Void
    private let fetchProfile: (String) async throws -> UserProfile
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

    var accessToken: String? {
        if let inMemorySessionToken,
           inMemorySessionToken.expiresAt > Int(Date().timeIntervalSince1970) {
            return inMemorySessionToken.token
        }
        guard let stored = loadStoredToken(),
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
        loadStoredUserProfile: @escaping () -> UserProfile? = {
            KeychainTokenStore.loadUserProfile()
        },
        saveStoredToken: @escaping (String, Int) -> Void = { token, expiresAt in
            KeychainTokenStore.saveToken(token, expiresAt: expiresAt)
        },
        saveStoredUserProfile: @escaping (UserProfile) -> Void = { profile in
            KeychainTokenStore.saveUserProfile(profile)
        },
        clearStoredSession: @escaping () -> Void = {
            KeychainTokenStore.clearAll()
        },
        fetchProfile: @escaping (String) async throws -> UserProfile = { token in
            try await AuthAPIService.fetchProfile(token: token)
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
        self.loadStoredUserProfile = loadStoredUserProfile
        self.saveStoredToken = saveStoredToken
        self.saveStoredUserProfile = saveStoredUserProfile
        self.clearStoredSession = clearStoredSession
        self.fetchProfile = fetchProfile
        self.fetchSubscription = fetchSubscription
        self.fetchCurrentPeriodUsageStats = fetchCurrentPeriodUsageStats
        self.createCheckoutSession = createCheckoutSession
        self.createPortalSession = createPortalSession
        restoreSession()
    }

    // MARK: - Session Restore

    private func restoreSession() {
        if accessToken != nil {
            userProfile = loadStoredUserProfile()
            isLoggedIn = true
            Task { await refreshProfile() }
            Task { await refreshTokenIfNeeded() }
        }
        startRefreshTimer()
    }

    // MARK: - Login

    func handleLoginSuccess(token: String, expiresAt: Int, refreshToken: String? = nil) async {
        let normalizedExpiresAt = normalizeLoginExpiry(expiresAt)
        inMemorySessionToken = (token, normalizedExpiresAt)
        if let refreshToken {
            KeychainTokenStore.saveToken(token, expiresAt: normalizedExpiresAt, refreshToken: refreshToken)
        } else {
            saveStoredToken(token, normalizedExpiresAt)
        }
        isLoggedIn = true
        await refreshProfile()
        NotificationCenter.default.post(name: .authDidLogin, object: self)
    }

    // MARK: - Logout

    func logout() {
        if let refreshToken = KeychainTokenStore.loadRefreshToken() {
            Task {
                try? await AuthAPIService.logout(refreshToken: refreshToken)
            }
        }
        inMemorySessionToken = nil
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
        guard KeychainTokenStore.isTokenExpiringSoon(within: Self.refreshEarlyInterval) else { return }

        guard let refreshToken = KeychainTokenStore.loadRefreshToken(), !refreshToken.isEmpty else {
            logger.debug("Token expiring soon but no refresh token stored")
            return
        }

        logger.info("Access token expiring soon, refreshing...")
        do {
            let response = try await AuthAPIService.refreshToken(refreshToken)
            let normalizedExpiresAt = normalizeLoginExpiry(response.expiresAt)
            KeychainTokenStore.saveToken(
                response.accessToken,
                expiresAt: normalizedExpiresAt,
                refreshToken: response.refreshToken
            )
            inMemorySessionToken = (response.accessToken, normalizedExpiresAt)
            logger.info("Token refreshed successfully")
        } catch let error as AuthError {
            logger.error("Token refresh failed: \(error.localizedDescription)")
            if shouldInvalidateSession(for: error) {
                logout()
            }
        } catch {
            logger.error("Token refresh error: \(error.localizedDescription)")
        }
    }

    // MARK: - Profile Refresh

    func refreshProfileIfNeeded() {
        guard isLoggedIn || accessToken != nil else { return }
        Task { await refreshProfile() }
    }

    @discardableResult
    func refreshProfile() async -> SessionRefreshResult {
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
            for attempt in 0..<Self.checkoutPollingAttempts {
                if attempt > 0 {
                    try? await Task.sleep(for: Self.checkoutPollingInterval)
                }
                guard !Task.isCancelled else { return }
                _ = await self.refreshSubscription()
                if self.subscription.entitled {
                    return
                }
            }
            self.pendingCheckoutSubscriptionEntitlement = false
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
        case .serverError(let code, _):
            code == "USER_NOT_FOUND"
                || code == "AUTH_REFRESH_TOKEN_INVALID"
                || code == "AUTH_REFRESH_TOKEN_REUSED"
        case .networkError, .invalidResponse:
            false
        }
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
