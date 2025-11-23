// MARK: - Payment Service
// Handles Stripe payment integration and subscription management

import Foundation
import Combine

public final class PaymentService: ObservableObject {
    public static let shared = PaymentService()

    private let client: APIClient
    private var cancellables = Set<AnyCancellable>()

    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastSessionId: String?

    /// Stripe publishable key for client-side operations
    public var stripePublishableKey: String?

    public init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Pricing Information

    public struct PricingInfo {
        public let plan: PaymentPlan
        public let displayName: String
        public let price: Double
        public let priceDisplay: String
        public let description: String
        public let features: [String]

        public static let monthly = PricingInfo(
            plan: .monthly,
            displayName: "Monthly",
            price: 9.99,
            priceDisplay: "$9.99/month",
            description: "Perfect for trying out premium features",
            features: [
                "Unlimited messages",
                "Access to all AI models",
                "Chat history",
                "Priority support"
            ]
        )

        public static let yearly = PricingInfo(
            plan: .yearly,
            displayName: "Yearly",
            price: 79.99,
            priceDisplay: "$79.99/year",
            description: "Best value - save 33%",
            features: [
                "Everything in Monthly",
                "2 months free",
                "Early access to new features",
                "Custom characters"
            ]
        )

        public static let lifetime = PricingInfo(
            plan: .lifetime,
            displayName: "Lifetime",
            price: 199.00,
            priceDisplay: "$199 one-time",
            description: "Pay once, use forever",
            features: [
                "Everything in Yearly",
                "Lifetime access",
                "All future updates included",
                "VIP support"
            ]
        )

        public static let all: [PricingInfo] = [monthly, yearly, lifetime]
    }

    // MARK: - Create Checkout Session

    /// Create a Stripe checkout session for a subscription plan
    public func createCheckoutSession(
        plan: PaymentPlan,
        userId: String? = nil,
        userEmail: String? = nil
    ) -> AnyPublisher<CreateCheckoutSessionResponse, APIError> {
        isLoading = true

        let request = CreateCheckoutSessionRequest(
            plan: plan,
            userId: userId,
            userEmail: userEmail
        )

        return client.request(.createCheckoutSession, body: request)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.lastSessionId = response.sessionId
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func createCheckoutSession(
        plan: PaymentPlan,
        userId: String? = nil,
        userEmail: String? = nil
    ) async throws -> CreateCheckoutSessionResponse {
        isLoading = true
        defer { isLoading = false }

        let request = CreateCheckoutSessionRequest(
            plan: plan,
            userId: userId,
            userEmail: userEmail
        )

        let response: CreateCheckoutSessionResponse = try await client.request(.createCheckoutSession, body: request)
        lastSessionId = response.sessionId
        return response
    }

    // MARK: - Stripe Checkout URL

    /// Generate Stripe checkout URL from session ID
    public func checkoutURL(sessionId: String) -> URL? {
        // Note: In production, this would be handled by Stripe SDK
        // This is just the web fallback URL
        URL(string: "https://checkout.stripe.com/pay/\(sessionId)")
    }

    // MARK: - Helper Methods

    /// Get pricing info for a plan
    public func pricingInfo(for plan: PaymentPlan) -> PricingInfo {
        switch plan {
        case .monthly:
            return .monthly
        case .yearly:
            return .yearly
        case .lifetime:
            return .lifetime
        }
    }

    /// Calculate savings percentage for yearly plan
    public var yearlySavingsPercentage: Int {
        let monthlyAnnual = PricingInfo.monthly.price * 12
        let yearlyCost = PricingInfo.yearly.price
        let savings = ((monthlyAnnual - yearlyCost) / monthlyAnnual) * 100
        return Int(savings.rounded())
    }
}

// MARK: - Payment Plan Extensions

extension PaymentPlan {
    public var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    public var price: Double {
        switch self {
        case .monthly: return 9.99
        case .yearly: return 79.99
        case .lifetime: return 199.00
        }
    }

    public var priceInCents: Int {
        switch self {
        case .monthly: return 999
        case .yearly: return 7999
        case .lifetime: return 19900
        }
    }
}
