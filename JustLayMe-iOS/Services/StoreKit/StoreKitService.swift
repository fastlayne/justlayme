import Foundation
import StoreKit
import Combine

// MARK: - StoreKit Service

@MainActor
final class StoreKitService: ObservableObject {
    // MARK: - Singleton

    static let shared = StoreKitService()

    // MARK: - Published Properties

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?

    // MARK: - Properties

    private var productsLoaded = false
    private var updates: Task<Void, Never>?

    // Product identifiers matching your App Store Connect setup
    private let productIdentifiers: [String] = [
        "com.justlayme.premium.monthly",
        "com.justlayme.premium.yearly",
        "com.justlayme.premium.lifetime"
    ]

    // MARK: - Initialization

    private init() {
        // Start listening for transactions
        updates = observeTransactionUpdates()
    }

    deinit {
        updates?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        guard !productsLoaded else { return }

        isLoading = true
        error = nil

        do {
            let storeProducts = try await Product.products(for: productIdentifiers)
            products = storeProducts.sorted { $0.price < $1.price }
            productsLoaded = true

            // Update purchased products
            await updatePurchasedProducts()
        } catch {
            self.error = error
            print("Failed to load products: \(error)")
        }

        isLoading = false
    }

    // MARK: - Purchasing

    func purchase(_ product: Product) async throws -> PurchaseResult {
        isLoading = true
        error = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // Update purchased products
                await updatePurchasedProducts()

                // Always finish a transaction
                await transaction.finish()

                isLoading = false
                return .success(transaction: transaction)

            case .userCancelled:
                isLoading = false
                return .cancelled

            case .pending:
                isLoading = false
                return .pending

            @unknown default:
                isLoading = false
                return .cancelled
            }
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async throws {
        isLoading = true
        error = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            self.error = error
            throw error
        }

        isLoading = false
    }

    // MARK: - Subscription Status

    func isPremium() async -> Bool {
        // Check for active subscription or lifetime purchase
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if it's one of our products
                if productIdentifiers.contains(transaction.productID) {
                    // For subscriptions, check if not expired
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > Date() {
                            return true
                        }
                    } else {
                        // Lifetime purchase (no expiration)
                        return true
                    }
                }
            } catch {
                continue
            }
        }

        return false
    }

    func getSubscriptionStatus() async -> SubscriptionStatus {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if productIdentifiers.contains(transaction.productID) {
                    if transaction.productID.contains("lifetime") {
                        return .lifetime
                    } else if let expirationDate = transaction.expirationDate,
                              expirationDate > Date() {
                        return .premium
                    }
                }
            } catch {
                continue
            }
        }

        return .free
    }

    // MARK: - Product Helpers

    func product(for identifier: String) -> Product? {
        products.first { $0.id == identifier }
    }

    func monthlyProduct() -> Product? {
        products.first { $0.id.contains("monthly") }
    }

    func yearlyProduct() -> Product? {
        products.first { $0.id.contains("yearly") }
    }

    func lifetimeProduct() -> Product? {
        products.first { $0.id.contains("lifetime") }
    }

    // MARK: - Private Methods

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchased.insert(transaction.productID)
            } catch {
                continue
            }
        }

        purchasedProductIDs = purchased

        // Post notification
        NotificationCenter.default.post(name: .subscriptionDidUpdate, object: nil)
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    await self?.updatePurchasedProducts()
                    await transaction?.finish()
                } catch {
                    print("Transaction update error: \(error)")
                }
            }
        }
    }
}

// MARK: - Product Extension

extension Product {
    var formattedPrice: String {
        displayPrice
    }

    var subscriptionPeriodText: String? {
        guard let subscription = subscription else { return nil }

        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value

        switch unit {
        case .day:
            return value == 1 ? "day" : "\(value) days"
        case .week:
            return value == 1 ? "week" : "\(value) weeks"
        case .month:
            return value == 1 ? "month" : "\(value) months"
        case .year:
            return value == 1 ? "year" : "\(value) years"
        @unknown default:
            return nil
        }
    }

    var isSubscription: Bool {
        subscription != nil
    }

    var isLifetime: Bool {
        id.contains("lifetime")
    }
}
