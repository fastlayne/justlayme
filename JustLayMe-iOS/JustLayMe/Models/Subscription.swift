import Foundation

struct SubscriptionPlan: Identifiable {
    let id: String
    let name: String
    let price: Decimal
    let period: String
    let features: [String]
    let isRecommended: Bool

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }

    static let plans: [SubscriptionPlan] = [
        SubscriptionPlan(
            id: "monthly",
            name: "Monthly Premium",
            price: 9.99,
            period: "/month",
            features: [
                "Unlimited messages",
                "All AI personalities",
                "Priority responses",
                "Cancel anytime"
            ],
            isRecommended: false
        ),
        SubscriptionPlan(
            id: "yearly",
            name: "Yearly Premium",
            price: 79.99,
            period: "/year",
            features: [
                "Everything in monthly",
                "Save 33%",
                "Custom personalities",
                "Early access features"
            ],
            isRecommended: true
        ),
        SubscriptionPlan(
            id: "lifetime",
            name: "Lifetime Premium",
            price: 199.00,
            period: "once",
            features: [
                "Lifetime access",
                "All future updates",
                "VIP support",
                "API access"
            ],
            isRecommended: false
        )
    ]
}

struct CheckoutSessionRequest: Codable {
    let plan: String
    let userId: String
    let userEmail: String

    enum CodingKeys: String, CodingKey {
        case plan
        case userId = "user_id"
        case userEmail = "user_email"
    }
}

struct CheckoutSessionResponse: Codable {
    let sessionId: String
}
