import Foundation

// MARK: - Subscription Models

enum SubscriptionPlan: String, CaseIterable, Codable, Equatable {
    case monthly
    case yearly
    case lifetime

    var price: Decimal {
        switch self {
        case .monthly: return 9.99
        case .yearly: return 79.99
        case .lifetime: return 199.00
        }
    }

    var priceInCents: Int {
        switch self {
        case .monthly: return 999
        case .yearly: return 7999
        case .lifetime: return 19900
        }
    }

    var displayName: String {
        switch self {
        case .monthly: return "Monthly Premium"
        case .yearly: return "Yearly Premium"
        case .lifetime: return "Lifetime Premium"
        }
    }

    var description: String {
        switch self {
        case .monthly: return "Billed monthly"
        case .yearly: return "Save 33% - Billed yearly"
        case .lifetime: return "One-time payment"
        }
    }

    var savings: String? {
        switch self {
        case .monthly: return nil
        case .yearly: return "Save $39.89/year"
        case .lifetime: return "Best value!"
        }
    }

    var durationInDays: Int? {
        switch self {
        case .monthly: return 30
        case .yearly: return 365
        case .lifetime: return nil
        }
    }
}

struct CheckoutSession: Codable, Equatable {
    let sessionId: String
}

struct PaymentResult: Equatable {
    let success: Bool
    let plan: SubscriptionPlan?
    let error: PaymentError?
}

enum PaymentError: Error, Equatable {
    case stripeNotConfigured
    case sessionCreationFailed
    case paymentCancelled
    case paymentFailed(String)
    case networkError(String)

    var localizedDescription: String {
        switch self {
        case .stripeNotConfigured:
            return "Payment system is not configured"
        case .sessionCreationFailed:
            return "Could not create checkout session"
        case .paymentCancelled:
            return "Payment was cancelled"
        case .paymentFailed(let message):
            return "Payment failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

struct SubscriptionFeature: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let isPremiumOnly: Bool

    static let allFeatures: [SubscriptionFeature] = [
        SubscriptionFeature(
            title: "Unlimited Messages",
            description: "Chat without limits with all AI models",
            iconName: "message.fill",
            isPremiumOnly: true
        ),
        SubscriptionFeature(
            title: "All AI Models",
            description: "Access to all uncensored and roleplay models",
            iconName: "brain.head.profile",
            isPremiumOnly: true
        ),
        SubscriptionFeature(
            title: "Chat History",
            description: "Save and search your conversation history",
            iconName: "clock.fill",
            isPremiumOnly: true
        ),
        SubscriptionFeature(
            title: "Custom Characters",
            description: "Create unlimited custom AI characters",
            iconName: "person.crop.circle.badge.plus",
            isPremiumOnly: true
        ),
        SubscriptionFeature(
            title: "Priority Support",
            description: "Get faster responses and dedicated help",
            iconName: "star.fill",
            isPremiumOnly: true
        )
    ]
}
