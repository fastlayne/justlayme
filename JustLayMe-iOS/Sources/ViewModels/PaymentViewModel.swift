import Foundation
import Combine
import StripePaymentSheet
import UIKit

// MARK: - Payment ViewModel
@MainActor
final class PaymentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedPlan: SubscriptionPlan = .monthly
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var paymentSuccess = false

    // MARK: - Services
    private let paymentService = PaymentService.shared

    // MARK: - Computed Properties
    var allPlans: [SubscriptionPlan] {
        SubscriptionPlan.allCases
    }

    var premiumFeatures: [PremiumFeature] {
        PremiumFeature.allFeatures
    }

    // MARK: - Select Plan
    func selectPlan(_ plan: SubscriptionPlan) {
        selectedPlan = plan
    }

    // MARK: - Initiate Checkout
    func initiateCheckout() async {
        isLoading = true
        errorMessage = nil

        do {
            let sessionId = try await paymentService.createCheckoutSession(plan: selectedPlan)

            // Open Stripe checkout in browser (for test mode)
            // In production, you would use PaymentSheet
            await openStripeCheckout(sessionId: sessionId)

        } catch {
            showError(message: "Failed to create checkout session: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Stripe Checkout
    private func openStripeCheckout(sessionId: String) async {
        // Construct Stripe checkout URL
        // Note: In production, you would use Stripe PaymentSheet instead
        let checkoutURL = "https://checkout.stripe.com/pay/\(sessionId)"

        if let url = URL(string: checkoutURL) {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - Handle Payment Result
    func handlePaymentSuccess() {
        paymentSuccess = true
        // Refresh user data to get updated subscription status
        Task {
            if let _ = try? await ProfileService.shared.getProfile() {
                // User data refreshed
            }
        }
    }

    // MARK: - Helpers
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func dismissError() {
        showError = false
        errorMessage = nil
    }
}

// MARK: - Premium Status Check
extension PaymentViewModel {
    static func checkPremiumAccess(for character: PredefinedCharacter, user: User?, messageCount: Int) -> PremiumAccessResult {
        // Free model - always accessible
        if character == .laymeV1 {
            return .allowed
        }

        // Premium user - always allowed
        if user?.isPremium == true {
            return .allowed
        }

        // Check free message limit
        if messageCount < AppConfig.freeMessageLimit {
            return .allowedWithLimit(remaining: AppConfig.freeMessageLimit - messageCount)
        }

        // Premium required
        return .premiumRequired
    }
}

enum PremiumAccessResult {
    case allowed
    case allowedWithLimit(remaining: Int)
    case premiumRequired
}
