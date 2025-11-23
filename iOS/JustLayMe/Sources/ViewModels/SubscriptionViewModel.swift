import Foundation
import Combine

// MARK: - Subscription State

enum SubscriptionState: Equatable {
    case idle
    case loading
    case checkoutReady(sessionId: String)
    case success(SubscriptionPlan)
    case error(PaymentError)
}

// MARK: - Subscription ViewModel

@MainActor
class SubscriptionViewModel: ObservableObject {
    @Published private(set) var state: SubscriptionState = .idle
    @Published private(set) var currentSubscription: SubscriptionStatus = .free
    @Published var selectedPlan: SubscriptionPlan = .monthly
    @Published private(set) var subscriptionEndDate: Date?

    private let apiClient: APIClientProtocol
    private let userRepository: UserRepositoryProtocol?
    private var cancellables = Set<AnyCancellable>()

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var isPremium: Bool {
        currentSubscription.isPremium
    }

    var features: [SubscriptionFeature] {
        SubscriptionFeature.allFeatures
    }

    var availablePlans: [SubscriptionPlan] {
        SubscriptionPlan.allCases
    }

    var subscriptionStatusText: String {
        switch currentSubscription {
        case .free:
            return "Free Plan"
        case .premium:
            if let endDate = subscriptionEndDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Premium until \(formatter.string(from: endDate))"
            }
            return "Premium"
        case .lifetime:
            return "Lifetime Premium"
        }
    }

    init(
        apiClient: APIClientProtocol = APIClient.shared,
        userRepository: UserRepositoryProtocol? = nil
    ) {
        self.apiClient = apiClient
        self.userRepository = userRepository
        loadCurrentSubscription()
    }

    func selectPlan(_ plan: SubscriptionPlan) {
        selectedPlan = plan
    }

    func startCheckout() async {
        guard !isPremium || currentSubscription != .lifetime else {
            return
        }

        state = .loading

        do {
            let userId = userRepository?.currentUser?.id
            let email = userRepository?.currentUser?.email

            let response: CheckoutSession = try await apiClient.request(
                .createCheckoutSession(
                    plan: selectedPlan.rawValue,
                    userId: userId,
                    email: email
                )
            )

            state = .checkoutReady(sessionId: response.sessionId)
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            state = .error(.networkError(error.localizedDescription))
        }
    }

    func handleCheckoutComplete(success: Bool) {
        if success {
            state = .success(selectedPlan)
            currentSubscription = .premium
            calculateSubscriptionEndDate()
        } else {
            state = .error(.paymentCancelled)
        }
    }

    func restorePurchases() async {
        // For Stripe, this would involve checking the backend
        // For StoreKit, this would use SKPaymentQueue.restoreCompletedTransactions
        state = .loading

        do {
            // Refresh user data from server
            if let user: User = try? await apiClient.request(.getProfile()) {
                currentSubscription = user.subscriptionStatus
                subscriptionEndDate = user.subscriptionEnd
            }
            state = .idle
        } catch {
            state = .error(.networkError("Failed to restore purchases"))
        }
    }

    func clearError() {
        if case .error = state {
            state = .idle
        }
    }

    // MARK: - Private Methods

    private func loadCurrentSubscription() {
        if let user = userRepository?.currentUser {
            currentSubscription = user.subscriptionStatus
            subscriptionEndDate = user.subscriptionEnd
        }
    }

    private func calculateSubscriptionEndDate() {
        guard let days = selectedPlan.durationInDays else {
            subscriptionEndDate = nil
            return
        }

        subscriptionEndDate = Calendar.current.date(
            byAdding: .day,
            value: days,
            to: Date()
        )
    }

    private func handleAPIError(_ error: APIError) {
        switch error {
        case .serverError:
            state = .error(.stripeNotConfigured)
        case .badRequest(let message):
            state = .error(.paymentFailed(message))
        default:
            state = .error(.networkError(error.localizedDescription ?? "Unknown error"))
        }
    }
}

// MARK: - Plan Comparison

extension SubscriptionViewModel {
    struct PlanComparison: Identifiable {
        let id = UUID()
        let plan: SubscriptionPlan
        let monthlyEquivalent: Decimal
        let savings: Decimal?
        let isRecommended: Bool
    }

    var planComparisons: [PlanComparison] {
        [
            PlanComparison(
                plan: .monthly,
                monthlyEquivalent: 9.99,
                savings: nil,
                isRecommended: false
            ),
            PlanComparison(
                plan: .yearly,
                monthlyEquivalent: 6.67,
                savings: 39.89,
                isRecommended: true
            ),
            PlanComparison(
                plan: .lifetime,
                monthlyEquivalent: 0,
                savings: nil,
                isRecommended: false
            )
        ]
    }
}
