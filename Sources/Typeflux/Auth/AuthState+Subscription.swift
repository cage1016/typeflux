import Foundation

@MainActor
extension AuthState {
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
}
