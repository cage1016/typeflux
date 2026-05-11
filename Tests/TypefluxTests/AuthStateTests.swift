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
                fetchedSubscriptionToken = token
                return activeSubscription
            },
        )

        await state.handleLoginSuccess(token: "token-1", expiresAt: Int(Date().timeIntervalSince1970) + 3600)

        XCTAssertTrue(state.isLoggedIn)
        XCTAssertEqual(savedProfile, profile)
        XCTAssertEqual(fetchedSubscriptionToken, "token-1")
        XCTAssertEqual(state.subscription, activeSubscription)
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
