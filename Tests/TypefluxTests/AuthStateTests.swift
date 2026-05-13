import XCTest
@testable import Typeflux

@MainActor
final class AuthStateTests: XCTestCase {
    func testRestoreSessionRefreshesProfileAndPersistsUser() async {
        let fetchExpectation = expectation(description: "fetch profile")
        let storedToken = validStoredToken()
        var savedProfile: UserProfile?
        let profile = makeProfile(email: "refresh@test.com")
        let state = AuthState(
            loadStoredToken: { storedToken },
            loadStoredUserProfile: { savedProfile },
            saveStoredToken: { _, _ in },
            saveStoredUserProfile: { savedProfile = $0 },
            clearStoredSession: {},
            fetchProfile: { _ in
                fetchExpectation.fulfill()
                return profile
            },
        )

        await fulfillment(of: [fetchExpectation], timeout: 1.0)
        await waitForRefreshCompletion(state)

        XCTAssertTrue(state.isLoggedIn)
        XCTAssertEqual(state.userProfile, profile)
        XCTAssertEqual(savedProfile, profile)
    }

    func testRestoreSessionLogsOutWhenProfileRefreshUnauthorized() async {
        let fetchExpectation = expectation(description: "fetch profile")
        var storedToken: (token: String, expiresAt: Int)? = validStoredToken()
        var clearedSession = false
        let state = AuthState(
            loadStoredToken: { storedToken },
            loadStoredUserProfile: { nil },
            saveStoredToken: { _, _ in },
            saveStoredUserProfile: { _ in },
            clearStoredSession: {
                clearedSession = true
                storedToken = nil
            },
            fetchProfile: { _ in
                fetchExpectation.fulfill()
                throw AuthError.unauthorized
            },
        )

        await fulfillment(of: [fetchExpectation], timeout: 1.0)
        await waitForRefreshCompletion(state)

        XCTAssertTrue(clearedSession)
        XCTAssertFalse(state.isLoggedIn)
        XCTAssertNil(state.userProfile)
    }

    func testRestoreSessionKeepsSessionOnNetworkFailure() async {
        let fetchExpectation = expectation(description: "fetch profile")
        let storedToken = validStoredToken()
        var clearedSession = false
        let state = AuthState(
            loadStoredToken: { storedToken },
            loadStoredUserProfile: { nil },
            saveStoredToken: { _, _ in },
            saveStoredUserProfile: { _ in },
            clearStoredSession: {
                clearedSession = true
            },
            fetchProfile: { _ in
                fetchExpectation.fulfill()
                throw AuthError.networkError(NSError(domain: "test", code: -1))
            },
        )

        await fulfillment(of: [fetchExpectation], timeout: 1.0)
        await waitForRefreshCompletion(state)

        XCTAssertFalse(clearedSession)
        XCTAssertTrue(state.isLoggedIn)
        XCTAssertNil(state.userProfile)
    }

    func testLoginSuccessRefreshesSubscription() async {
        var storedToken: (token: String, expiresAt: Int)?
        var savedProfile: UserProfile?
        var fetchedSubscriptionToken: String?
        var subscriptionFetchCount = 0
        let profile = makeProfile(email: "billing@test.com")
        let activeSubscription = BillingSubscriptionSnapshot(
            planCode: BillingPlan.defaultPlanCode,
            status: "active",
            currentPeriodStart: nil,
            currentPeriodEnd: "2026-06-01T00:00:00Z",
            cancelAtPeriodEnd: false,
            entitled: true
        )
        let state = AuthState(
            loadStoredToken: { storedToken },
            loadStoredUserProfile: { nil },
            saveStoredToken: { token, expiresAt in storedToken = (token, expiresAt) },
            saveStoredUserProfile: { savedProfile = $0 },
            clearStoredSession: {},
            fetchProfile: { _ in profile },
            fetchSubscription: { token in
                subscriptionFetchCount += 1
                fetchedSubscriptionToken = token
                return activeSubscription
            },
        )

        await state.handleLoginSuccess(token: "token-1", expiresAt: Int(Date().timeIntervalSince1970) + 3600)

        XCTAssertTrue(state.isLoggedIn)
        XCTAssertEqual(savedProfile, profile)
        XCTAssertEqual(fetchedSubscriptionToken, "token-1")
        XCTAssertEqual(subscriptionFetchCount, 1)
        XCTAssertEqual(state.subscription, activeSubscription)
    }

    func testLoginSuccessKeepsSessionWhenSubscriptionRefreshIsUnauthorized() async {
        var storedToken: (token: String, expiresAt: Int)?
        var savedProfile: UserProfile?
        var clearedSession = false
        let profile = makeProfile(email: "billing-auth@test.com")
        let state = AuthState(
            loadStoredToken: { storedToken },
            loadStoredUserProfile: { nil },
            saveStoredToken: { token, expiresAt in storedToken = (token, expiresAt) },
            saveStoredUserProfile: { savedProfile = $0 },
            clearStoredSession: {
                clearedSession = true
                storedToken = nil
            },
            fetchProfile: { _ in profile },
            fetchSubscription: { _ in
                throw AuthError.unauthorized
            },
        )

        await state.handleLoginSuccess(token: "token-1", expiresAt: Int(Date().timeIntervalSince1970) + 3600)

        XCTAssertFalse(clearedSession)
        XCTAssertTrue(state.isLoggedIn)
        XCTAssertEqual(storedToken?.token, "token-1")
        XCTAssertEqual(savedProfile, profile)
        XCTAssertEqual(state.subscription, .none)
        XCTAssertNotNil(state.subscriptionError)
    }

    func testLoginSuccessUsesInMemoryTokenWhenPersistenceDoesNotImmediatelyLoad() async {
        var savedProfile: UserProfile?
        var fetchedProfileToken: String?
        let profile = makeProfile(email: "memory-session@test.com")
        let state = AuthState(
            loadStoredToken: { nil },
            loadStoredUserProfile: { nil },
            saveStoredToken: { _, _ in },
            saveStoredUserProfile: { savedProfile = $0 },
            clearStoredSession: {},
            fetchProfile: { token in
                fetchedProfileToken = token
                return profile
            },
            fetchSubscription: { _ in .none },
        )

        await state.handleLoginSuccess(token: "token-1", expiresAt: Int(Date().timeIntervalSince1970) + 3600)

        XCTAssertTrue(state.isLoggedIn)
        XCTAssertEqual(fetchedProfileToken, "token-1")
        XCTAssertEqual(savedProfile, profile)
    }

    func testLoginSuccessAcceptsRelativeExpirySeconds() async {
        var storedToken: (token: String, expiresAt: Int)?
        let now = Int(Date().timeIntervalSince1970)
        let state = AuthState(
            loadStoredToken: { storedToken },
            loadStoredUserProfile: { nil },
            saveStoredToken: { token, expiresAt in storedToken = (token, expiresAt) },
            saveStoredUserProfile: { _ in },
            clearStoredSession: { storedToken = nil },
            fetchProfile: { _ in self.makeProfile(email: "relative-expiry@test.com") },
            fetchSubscription: { _ in .none },
        )

        await state.handleLoginSuccess(token: "token-1", expiresAt: 3600)

        XCTAssertTrue(state.isLoggedIn)
        XCTAssertEqual(storedToken?.token, "token-1")
        XCTAssertGreaterThanOrEqual(storedToken?.expiresAt ?? 0, now + 3600)
    }

    func testLoginSuccessNormalizesMillisecondExpiryTimestamp() async {
        var storedToken: (token: String, expiresAt: Int)?
        let expiresAt = Int(Date().timeIntervalSince1970) + 3600
        let state = AuthState(
            loadStoredToken: { storedToken },
            loadStoredUserProfile: { nil },
            saveStoredToken: { token, expiresAt in storedToken = (token, expiresAt) },
            saveStoredUserProfile: { _ in },
            clearStoredSession: { storedToken = nil },
            fetchProfile: { _ in self.makeProfile(email: "millisecond-expiry@test.com") },
            fetchSubscription: { _ in .none },
        )

        await state.handleLoginSuccess(token: "token-1", expiresAt: expiresAt * 1000)

        XCTAssertTrue(state.isLoggedIn)
        XCTAssertEqual(storedToken?.token, "token-1")
        XCTAssertEqual(storedToken?.expiresAt, expiresAt)
    }

    func testStartCheckoutCreatesSessionAndRefreshesSubscriptionDuringPolling() async throws {
        var storedToken: (token: String, expiresAt: Int)? = validStoredToken()
        var requestedPlanCode: String?
        var refreshCount = 0
        let activeSubscription = BillingSubscriptionSnapshot(
            planCode: BillingPlan.defaultPlanCode,
            status: "active",
            currentPeriodStart: nil,
            currentPeriodEnd: "2026-06-01T00:00:00Z",
            cancelAtPeriodEnd: false,
            entitled: true
        )
        let state = AuthState(
            loadStoredToken: { storedToken },
            loadStoredUserProfile: { nil },
            saveStoredToken: { token, expiresAt in storedToken = (token, expiresAt) },
            saveStoredUserProfile: { _ in },
            clearStoredSession: { storedToken = nil },
            fetchProfile: { _ in self.makeProfile(email: "checkout@test.com") },
            fetchSubscription: { _ in
                refreshCount += 1
                return activeSubscription
            },
            createCheckoutSession: { _, planCode in
                requestedPlanCode = planCode
                return BillingCheckoutSession(
                    sessionID: "cs_test_1",
                    url: URL(string: "https://checkout.stripe.com/cs_test_1")!
                )
            },
        )

        let url = try await state.startCheckout()
        await waitForSubscriptionRefreshCount { refreshCount }

        XCTAssertEqual(url.absoluteString, "https://checkout.stripe.com/cs_test_1")
        XCTAssertEqual(requestedPlanCode, BillingPlan.defaultPlanCode)
        XCTAssertEqual(state.subscription, activeSubscription)
    }

    func testStartCheckoutPostsEntitlementNotificationWhenSubscriptionBecomesActive() async throws {
        var storedToken: (token: String, expiresAt: Int)?
        var checkoutStarted = false
        let activeSubscription = BillingSubscriptionSnapshot(
            planCode: BillingPlan.defaultPlanCode,
            status: "active",
            currentPeriodStart: nil,
            currentPeriodEnd: "2026-06-01T00:00:00Z",
            cancelAtPeriodEnd: false,
            entitled: true
        )
        let state = AuthState(
            loadStoredToken: { storedToken },
            loadStoredUserProfile: { nil },
            saveStoredToken: { token, expiresAt in storedToken = (token, expiresAt) },
            saveStoredUserProfile: { _ in },
            clearStoredSession: { storedToken = nil },
            fetchProfile: { _ in self.makeProfile(email: "checkout-entitled@test.com") },
            fetchSubscription: { _ in checkoutStarted ? activeSubscription : .none },
            createCheckoutSession: { _, _ in
                checkoutStarted = true
                return BillingCheckoutSession(
                    sessionID: "cs_test_1",
                    url: URL(string: "https://checkout.stripe.com/cs_test_1")!
                )
            },
        )
        await state.handleLoginSuccess(token: "token-1", expiresAt: Int(Date().timeIntervalSince1970) + 3600)
        XCTAssertFalse(state.subscription.entitled)

        let expectation = expectation(description: "checkout subscription entitlement notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .authCheckoutSubscriptionDidBecomeEntitled,
            object: state,
            queue: .main,
        ) { _ in
            expectation.fulfill()
        }

        _ = try await state.startCheckout()

        await fulfillment(of: [expectation], timeout: 1)
        NotificationCenter.default.removeObserver(observer)
    }

    func testLogoutClearsSubscription() async {
        var storedToken: (token: String, expiresAt: Int)? = validStoredToken()
        let state = AuthState(
            loadStoredToken: { storedToken },
            loadStoredUserProfile: { nil },
            saveStoredToken: { _, _ in },
            saveStoredUserProfile: { _ in },
            clearStoredSession: { storedToken = nil },
            fetchProfile: { _ in self.makeProfile(email: "logout@test.com") },
            fetchSubscription: { _ in
                BillingSubscriptionSnapshot(
                    planCode: BillingPlan.defaultPlanCode,
                    status: "active",
                    currentPeriodStart: nil,
                    currentPeriodEnd: nil,
                    cancelAtPeriodEnd: false,
                    entitled: true
                )
            },
        )
        await waitForRefreshCompletion(state)
        await state.refreshSubscription()

        state.logout()

        XCTAssertFalse(state.isLoggedIn)
        XCTAssertEqual(state.subscription, .none)
    }

    func testRefreshUsageUsesCurrentSubscriptionPeriod() async {
        var storedToken: (token: String, expiresAt: Int)? = validStoredToken()
        var usageFetchCount = 0
        let stats = CloudUsageStats(
            asrCount: 2,
            asrAudioDurationMs: 60000,
            asrOutputChars: 300,
            chatCount: 1,
            chatOutputChars: 100,
            chatInputTokens: 200,
            chatOutputTokens: 50,
            chatTotalTokens: 250
        )
        let state = AuthState(
            loadStoredToken: { storedToken },
            loadStoredUserProfile: { nil },
            saveStoredToken: { _, _ in },
            saveStoredUserProfile: { _ in },
            clearStoredSession: { storedToken = nil },
            fetchProfile: { _ in self.makeProfile(email: "usage@test.com") },
            fetchSubscription: { _ in
                BillingSubscriptionSnapshot(
                    planCode: BillingPlan.defaultPlanCode,
                    status: "active",
                    currentPeriodStart: "2026-05-01T00:00:00Z",
                    currentPeriodEnd: "2026-06-01T00:00:00Z",
                    cancelAtPeriodEnd: false,
                    entitled: true
                )
            },
            fetchCurrentPeriodUsageStats: { _ in
                usageFetchCount += 1
                return CloudUsageCurrentPeriodStats(
                    periodStart: "2026-05-01T00:00:00Z",
                    periodEnd: "2026-06-01T00:00:00Z",
                    stats: stats
                )
            },
        )

        await state.refreshSubscription()
        await state.refreshUsage()

        XCTAssertEqual(usageFetchCount, 1)
        XCTAssertEqual(state.usageStats, stats)
        XCTAssertEqual(state.usagePeriodStart, "2026-05-01T00:00:00Z")
        XCTAssertEqual(state.usagePeriodEnd, "2026-06-01T00:00:00Z")
    }

    func testRefreshUsageSurfacesServerPeriodError() async {
        var storedToken: (token: String, expiresAt: Int)? = validStoredToken()
        let state = AuthState(
            loadStoredToken: { storedToken },
            loadStoredUserProfile: { nil },
            saveStoredToken: { _, _ in },
            saveStoredUserProfile: { _ in },
            clearStoredSession: { storedToken = nil },
            fetchProfile: { _ in self.makeProfile(email: "usage@test.com") },
            fetchSubscription: { _ in .none },
            fetchCurrentPeriodUsageStats: { _ in
                throw AuthError.serverError(code: "USAGE_PERIOD_UNAVAILABLE", message: "current billing period is unavailable")
            },
        )

        await state.refreshSubscription()
        await state.refreshUsage()

        XCTAssertEqual(state.usageStats, .empty)
        XCTAssertNil(state.usagePeriodStart)
        XCTAssertNil(state.usagePeriodEnd)
        XCTAssertNil(state.usageError)
    }

    func testRefreshUsageKeepsSessionWhenUnauthorized() async {
        var storedToken: (token: String, expiresAt: Int)?
        var clearedSession = false
        let state = AuthState(
            loadStoredToken: { storedToken },
            loadStoredUserProfile: { nil },
            saveStoredToken: { token, expiresAt in storedToken = (token, expiresAt) },
            saveStoredUserProfile: { _ in },
            clearStoredSession: {
                clearedSession = true
                storedToken = nil
            },
            fetchProfile: { _ in self.makeProfile(email: "usage-auth@test.com") },
            fetchSubscription: { _ in .none },
            fetchCurrentPeriodUsageStats: { _ in
                throw AuthError.unauthorized
            },
        )

        await state.handleLoginSuccess(token: "token-1", expiresAt: Int(Date().timeIntervalSince1970) + 3600)
        await state.refreshUsage()

        XCTAssertFalse(clearedSession)
        XCTAssertTrue(state.isLoggedIn)
        XCTAssertEqual(storedToken?.token, "token-1")
        XCTAssertEqual(state.usageStats, .empty)
        XCTAssertNotNil(state.usageError)
    }

    private func makeProfile(email: String) -> UserProfile {
        UserProfile(
            id: UUID().uuidString,
            email: email,
            name: "Test User",
            status: 1,
            provider: "password",
            createdAt: "2024-04-09T12:00:00Z",
            updatedAt: "2024-04-09T12:00:00Z",
        )
    }

    private func validStoredToken() -> (token: String, expiresAt: Int) {
        ("valid-token", Int(Date().timeIntervalSince1970) + 3600)
    }

    private func waitForRefreshCompletion(_ state: AuthState) async {
        while state.isLoading {
            await Task.yield()
        }
        await Task.yield()
    }

    private func waitForSubscriptionRefreshCount(_ count: @escaping () -> Int) async {
        for _ in 0..<100 where count() == 0 {
            await Task.yield()
        }
    }
}
