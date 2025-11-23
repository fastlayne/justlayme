import Foundation
import StoreKit

// MARK: - Subscription Plan

struct SubscriptionPlan: Identifiable, Hashable {
    let id: String
    let name: String
    let price: Decimal
    let priceString: String
    let duration: SubscriptionDuration
    let features: [String]
    let isMostPopular: Bool

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SubscriptionPlan, rhs: SubscriptionPlan) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Subscription Duration

enum SubscriptionDuration: String, CaseIterable {
    case monthly = "monthly"
    case yearly = "yearly"
    case lifetime = "lifetime"

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    var months: Int? {
        switch self {
        case .monthly: return 1
        case .yearly: return 12
        case .lifetime: return nil
        }
    }
}

// MARK: - Preset Plans

extension SubscriptionPlan {
    static let monthly = SubscriptionPlan(
        id: "com.justlayme.premium.monthly",
        name: "Monthly Premium",
        price: 9.99,
        priceString: "$9.99/month",
        duration: .monthly,
        features: [
            "Unlimited premium model access",
            "Full chat history",
            "Priority support",
            "Character creation"
        ],
        isMostPopular: false
    )

    static let yearly = SubscriptionPlan(
        id: "com.justlayme.premium.yearly",
        name: "Yearly Premium",
        price: 79.99,
        priceString: "$79.99/year",
        duration: .yearly,
        features: [
            "All Monthly features",
            "Save 33% vs monthly",
            "Exclusive yearly badge",
            "Early access to new features"
        ],
        isMostPopular: true
    )

    static let lifetime = SubscriptionPlan(
        id: "com.justlayme.premium.lifetime",
        name: "Lifetime Premium",
        price: 199.00,
        priceString: "$199 one-time",
        duration: .lifetime,
        features: [
            "All Premium features forever",
            "No recurring payments",
            "Lifetime supporter badge",
            "Priority feature requests"
        ],
        isMostPopular: false
    )

    static let allPlans: [SubscriptionPlan] = [monthly, yearly, lifetime]
}

// MARK: - Checkout Session Request

struct CheckoutSessionRequest: Codable {
    let plan: String
    let userId: Int?
    let userEmail: String?

    enum CodingKeys: String, CodingKey {
        case plan
        case userId = "user_id"
        case userEmail = "user_email"
    }
}

// MARK: - Checkout Session Response

struct CheckoutSessionResponse: Codable {
    let sessionId: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case url
    }
}

// MARK: - Purchase Result

enum PurchaseResult {
    case success(transaction: StoreKit.Transaction)
    case pending
    case cancelled
    case failed(Error)
}

// MARK: - Subscription Error

enum SubscriptionError: LocalizedError {
    case productNotFound
    case purchaseFailed(String)
    case verificationFailed
    case networkError
    case unknownError

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "The subscription product could not be found."
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .verificationFailed:
            return "Could not verify the purchase. Please try again."
        case .networkError:
            return "Network error. Please check your connection."
        case .unknownError:
            return "An unknown error occurred."
        }
    }
}
