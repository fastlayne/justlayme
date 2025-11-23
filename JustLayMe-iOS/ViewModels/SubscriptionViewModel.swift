import Foundation
import Combine
import StoreKit

// MARK: - Subscription View Model

@MainActor
final class SubscriptionViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var plans: [SubscriptionPlan] = SubscriptionPlan.allPlans
    @Published var products: [Product] = []
    @Published var selectedPlan: SubscriptionPlan?

    @Published var isLoading: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    @Published var currentSubscriptionStatus: SubscriptionStatus = .free
    @Published var subscriptionEndDate: Date?

    // MARK: - Properties

    private let storeKitService: StoreKitService
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var isPremium: Bool {
        currentSubscriptionStatus != .free
    }

    var statusText: String {
        switch currentSubscriptionStatus {
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

    // MARK: - Initialization

    init(
        storeKitService: StoreKitService = .shared,
        authService: AuthService = .shared
    ) {
        self.storeKitService = storeKitService
        self.authService = authService

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Listen for StoreKit products
        storeKitService.$products
            .receive(on: DispatchQueue.main)
            .assign(to: &$products)

        storeKitService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        // Listen for auth changes
        authService.$authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if case .authenticated(let user) = state {
                    self?.currentSubscriptionStatus = user.subscriptionStatus
                    self?.subscriptionEndDate = user.subscriptionEnd
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func loadProducts() async {
        await storeKitService.loadProducts()
        await refreshSubscriptionStatus()
    }

    func selectPlan(_ plan: SubscriptionPlan) {
        selectedPlan = plan
    }

    func purchase() async {
        guard let plan = selectedPlan else {
            errorMessage = "Please select a plan"
            return
        }

        guard let product = products.first(where: { $0.id == plan.id }) else {
            errorMessage = "Product not available"
            return
        }

        isPurchasing = true
        errorMessage = nil
        successMessage = nil

        do {
            let result = try await storeKitService.purchase(product)

            switch result {
            case .success:
                successMessage = "Thank you for subscribing!"
                await refreshSubscriptionStatus()

                // Refresh user data from server
                if authService.currentUser != nil {
                    _ = try? await authService.refreshUser()
                }

            case .pending:
                successMessage = "Purchase pending. You'll be notified when complete."

            case .cancelled:
                // User cancelled, no message needed
                break

            case .failed(let error):
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isPurchasing = false
    }

    func purchasePlan(_ plan: SubscriptionPlan) async {
        selectedPlan = plan
        await purchase()
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await storeKitService.restorePurchases()
            await refreshSubscriptionStatus()
            successMessage = "Purchases restored successfully"
        } catch {
            errorMessage = "Failed to restore purchases"
        }

        isLoading = false
    }

    func refreshSubscriptionStatus() async {
        currentSubscriptionStatus = await storeKitService.getSubscriptionStatus()
    }

    // MARK: - Plan Helpers

    func planProduct(_ plan: SubscriptionPlan) -> Product? {
        products.first { $0.id == plan.id }
    }

    func formattedPrice(for plan: SubscriptionPlan) -> String {
        if let product = planProduct(plan) {
            return product.displayPrice
        }
        return plan.priceString
    }

    func pricePerMonth(for plan: SubscriptionPlan) -> String? {
        guard plan.duration != .monthly else { return nil }

        let monthlyPrice: Decimal
        switch plan.duration {
        case .monthly:
            return nil
        case .yearly:
            monthlyPrice = plan.price / 12
        case .lifetime:
            // Assume 24 month value for comparison
            monthlyPrice = plan.price / 24
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"

        return formatter.string(from: monthlyPrice as NSNumber)
    }

    func savings(for plan: SubscriptionPlan) -> String? {
        guard plan.duration == .yearly else { return nil }

        let monthlyCost = SubscriptionPlan.monthly.price * 12
        let yearlyCost = plan.price
        let savings = monthlyCost - yearlyCost
        let percentage = Int((savings / monthlyCost) * 100)

        return "Save \(percentage)%"
    }
}

// MARK: - Plan Features

extension SubscriptionPlan {
    static let freeFeatures: [String] = [
        "Unlimited Layme V1 messages",
        "3 free premium model messages",
        "Basic chat history"
    ]

    static let premiumFeatures: [String] = [
        "Unlimited all model access",
        "Full conversation history",
        "Character creation",
        "Priority support",
        "Early access to new features"
    ]
}
