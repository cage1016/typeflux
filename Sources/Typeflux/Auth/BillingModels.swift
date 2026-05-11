import Foundation

struct BillingSubscriptionSnapshot: Decodable, Equatable {
    let planCode: String?
    let status: String?
    let currentPeriodStart: String?
    let currentPeriodEnd: String?
    let cancelAtPeriodEnd: Bool
    let entitled: Bool

    enum CodingKeys: String, CodingKey {
        case planCode = "plan_code"
        case status
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case cancelAtPeriodEnd = "cancel_at_period_end"
        case entitled
        case subscription
        case entitlement
    }

    enum EntitlementCodingKeys: String, CodingKey {
        case entitled
    }

    init(
        planCode: String?,
        status: String?,
        currentPeriodStart: String?,
        currentPeriodEnd: String?,
        cancelAtPeriodEnd: Bool,
        entitled: Bool
    ) {
        self.planCode = planCode
        self.status = status
        self.currentPeriodStart = currentPeriodStart
        self.currentPeriodEnd = currentPeriodEnd
        self.cancelAtPeriodEnd = cancelAtPeriodEnd
        self.entitled = entitled
    }

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: CodingKeys.self)
        let source = (try? root.nestedContainer(keyedBy: CodingKeys.self, forKey: .subscription)) ?? root
        let entitlement = try? root.nestedContainer(keyedBy: EntitlementCodingKeys.self, forKey: .entitlement)

        let status = try source.decodeIfPresent(String.self, forKey: .status)
        let entitled = try entitlement?.decodeIfPresent(Bool.self, forKey: .entitled)
            ?? root.decodeIfPresent(Bool.self, forKey: .entitled)
            ?? Self.defaultEntitlement(for: status, periodEnd: try source.decodeIfPresent(String.self, forKey: .currentPeriodEnd))

        self.init(
            planCode: try source.decodeIfPresent(String.self, forKey: .planCode),
            status: status,
            currentPeriodStart: try source.decodeIfPresent(String.self, forKey: .currentPeriodStart),
            currentPeriodEnd: try source.decodeIfPresent(String.self, forKey: .currentPeriodEnd),
            cancelAtPeriodEnd: try source.decodeIfPresent(Bool.self, forKey: .cancelAtPeriodEnd) ?? false,
            entitled: entitled
        )
    }

    var hasSubscription: Bool {
        guard let status, !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return true
    }

    static var none: BillingSubscriptionSnapshot {
        BillingSubscriptionSnapshot(
            planCode: nil,
            status: nil,
            currentPeriodStart: nil,
            currentPeriodEnd: nil,
            cancelAtPeriodEnd: false,
            entitled: false
        )
    }

    private static func defaultEntitlement(for status: String?, periodEnd: String?) -> Bool {
        guard let status else { return false }
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized == "active" || normalized == "trialing" else { return false }
        guard let periodEnd, let endDate = ISO8601DateFormatter.typefluxBillingDate(from: periodEnd) else {
            return true
        }
        return endDate > Date()
    }
}

struct BillingCheckoutSession: Decodable, Equatable {
    let sessionID: String?
    let url: URL

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case url
    }
}

struct BillingPortalSession: Decodable, Equatable {
    let url: URL
}

struct BillingCheckoutSessionRequest: Encodable {
    let planCode: String

    enum CodingKeys: String, CodingKey {
        case planCode = "plan_code"
    }
}

enum BillingPlan {
    static let defaultPlanCode = "typeflux_cloud_monthly"
}

struct AccountSubscriptionPresentation: Equatable {
    enum BillingAction: Equatable {
        case subscribe
        case manageBilling
    }

    enum TextValue: Equatable {
        case localized(String)
        case literal(String)
    }

    enum PeriodValue: Equatable {
        case unavailable
        case renewsOn(String)
        case endsOn(String)
    }

    let subtitleKey: String
    let plan: TextValue
    let status: TextValue
    let period: PeriodValue
    let billingAction: BillingAction

    static func make(from snapshot: BillingSubscriptionSnapshot) -> AccountSubscriptionPresentation {
        AccountSubscriptionPresentation(
            subtitleKey: subtitleKey(for: snapshot),
            plan: planValue(for: snapshot),
            status: statusValue(for: snapshot),
            period: periodValue(for: snapshot),
            billingAction: snapshot.hasSubscription ? .manageBilling : .subscribe
        )
    }

    private static func subtitleKey(for snapshot: BillingSubscriptionSnapshot) -> String {
        if snapshot.entitled {
            return "auth.account.subscriptionActiveHint"
        }
        if snapshot.hasSubscription {
            return "auth.account.subscriptionInactiveHint"
        }
        return "auth.account.subscriptionRequiredHint"
    }

    private static func planValue(for snapshot: BillingSubscriptionSnapshot) -> TextValue {
        guard let planCode = snapshot.planCode, !planCode.isEmpty else {
            return .localized("auth.account.subscriptionNoPlan")
        }
        if planCode == BillingPlan.defaultPlanCode {
            return .localized("auth.account.subscriptionDefaultPlan")
        }
        return .literal(planCode.replacingOccurrences(of: "_", with: " ").capitalized)
    }

    private static func statusValue(for snapshot: BillingSubscriptionSnapshot) -> TextValue {
        guard let status = snapshot.status, !status.isEmpty else {
            return .localized("auth.account.subscriptionStatusNone")
        }
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "active":
            return .localized("auth.account.subscriptionStatusActive")
        case "trialing":
            return .localized("auth.account.subscriptionStatusTrialing")
        case "past_due":
            return .localized("auth.account.subscriptionStatusPastDue")
        case "canceled", "cancelled":
            return .localized("auth.account.subscriptionStatusCanceled")
        case "unpaid":
            return .localized("auth.account.subscriptionStatusUnpaid")
        default:
            return .literal(status.replacingOccurrences(of: "_", with: " ").capitalized)
        }
    }

    private static func periodValue(for snapshot: BillingSubscriptionSnapshot) -> PeriodValue {
        guard let periodEnd = snapshot.currentPeriodEnd else {
            return .unavailable
        }
        if snapshot.cancelAtPeriodEnd {
            return .endsOn(periodEnd)
        }
        return .renewsOn(periodEnd)
    }
}

extension ISO8601DateFormatter {
    static func typefluxBillingDate(from string: String) -> Date? {
        typefluxBilling.date(from: string) ?? typefluxBillingFallback.date(from: string)
    }

    static let typefluxBilling: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let typefluxBillingFallback: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
