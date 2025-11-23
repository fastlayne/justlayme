import Foundation

// MARK: - Subscription Plans
enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case monthly
    case yearly
    case lifetime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    var price: Decimal {
        switch self {
        case .monthly: return 9.99
        case .yearly: return 79.99
        case .lifetime: return 199.00
        }
    }

    var priceString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }

    var billingPeriod: String {
        switch self {
        case .monthly: return "/month"
        case .yearly: return "/year"
        case .lifetime: return " one-time"
        }
    }

    var savings: String? {
        switch self {
        case .monthly: return nil
        case .yearly: return "Save 33%"
        case .lifetime: return "Best Value"
        }
    }

    var features: [String] {
        [
            "Access to all AI models",
            "Unlimited messages",
            "Custom character creation",
            "Chat history & export",
            "Priority support"
        ]
    }
}

// MARK: - Checkout Session
struct CheckoutSessionRequest: Codable {
    let plan: String
    let userId: String?
    let userEmail: String?

    enum CodingKeys: String, CodingKey {
        case plan
        case userId = "user_id"
        case userEmail = "user_email"
    }
}

struct CheckoutSessionResponse: Codable {
    let sessionId: String
}

// MARK: - Premium Features
struct PremiumFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

extension PremiumFeature {
    static let allFeatures: [PremiumFeature] = [
        PremiumFeature(
            icon: "flame.fill",
            title: "All AI Models",
            description: "Access LayMe Uncensored, Mythomax Roleplay, and FastLayMe"
        ),
        PremiumFeature(
            icon: "infinity",
            title: "Unlimited Messages",
            description: "No message limits on any model"
        ),
        PremiumFeature(
            icon: "person.badge.plus",
            title: "Custom Characters",
            description: "Create and customize your own AI characters"
        ),
        PremiumFeature(
            icon: "clock.arrow.circlepath",
            title: "Chat History",
            description: "Save, search, and export your conversations"
        ),
        PremiumFeature(
            icon: "star.fill",
            title: "Priority Support",
            description: "Get help faster with priority customer support"
        )
    ]
}

// MARK: - Model Availability
struct AIModelInfo: Codable, Identifiable {
    let name: String
    let displayName: String?
    let isPremium: Bool
    let isAvailable: Bool

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case isPremium = "is_premium"
        case isAvailable = "is_available"
    }
}

struct ModelsResponse: Codable {
    let models: [String: AIModelInfo]
    let defaultModel: String
    let totalModels: Int

    enum CodingKeys: String, CodingKey {
        case models
        case defaultModel = "default_model"
        case totalModels = "total_models"
    }
}
