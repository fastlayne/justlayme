import XCTest
import Combine
@testable import JustLayMe

@MainActor
final class SubscriptionViewModelTests: ViewModelTestCase {

    var sut: SubscriptionViewModel!

    override func setUp() {
        super.setUp()
        sut = SubscriptionViewModel(apiClient: env.mockAPIClient, userRepository: env.mockUserRepository)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.currentSubscription, .free)
        XCTAssertEqual(sut.selectedPlan, .monthly)
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isPremium)
    }

    func testInitialStateWithPremiumUser() {
        // Given
        env.mockUserRepository.currentUser = MockDataFactory.createPremiumUser()

        // When
        sut = SubscriptionViewModel(apiClient: env.mockAPIClient, userRepository: env.mockUserRepository)

        // Then
        XCTAssertEqual(sut.currentSubscription, .premium)
        XCTAssertTrue(sut.isPremium)
    }

    // MARK: - Plan Selection Tests

    func testSelectPlan() {
        XCTAssertEqual(sut.selectedPlan, .monthly)

        sut.selectPlan(.yearly)
        XCTAssertEqual(sut.selectedPlan, .yearly)

        sut.selectPlan(.lifetime)
        XCTAssertEqual(sut.selectedPlan, .lifetime)
    }

    func testAvailablePlans() {
        XCTAssertEqual(sut.availablePlans.count, 3)
        XCTAssertTrue(sut.availablePlans.contains(.monthly))
        XCTAssertTrue(sut.availablePlans.contains(.yearly))
        XCTAssertTrue(sut.availablePlans.contains(.lifetime))
    }

    // MARK: - Start Checkout Tests

    func testStartCheckoutSuccess() async {
        // Given
        let checkoutSession = MockDataFactory.createCheckoutSession()
        env.mockAPIClient.stub(endpoint: "/api/create-checkout-session", with: checkoutSession)

        // When
        await sut.startCheckout()

        // Then
        if case .checkoutReady(let sessionId) = sut.state {
            XCTAssertEqual(sessionId, checkoutSession.sessionId)
        } else {
            XCTFail("Expected checkoutReady state")
        }
    }

    func testStartCheckoutWithUserInfo() async {
        // Given
        let user = MockDataFactory.createUser(email: "test@example.com")
        env.mockUserRepository.currentUser = user

        let checkoutSession = MockDataFactory.createCheckoutSession()
        env.mockAPIClient.stub(endpoint: "/api/create-checkout-session", with: checkoutSession)

        // When
        await sut.startCheckout()

        // Then
        XCTAssertEqual(env.mockAPIClient.requestCallCount, 1)
    }

    func testStartCheckoutShowsLoading() async {
        // Given
        let checkoutSession = MockDataFactory.createCheckoutSession()
        env.mockAPIClient.stub(endpoint: "/api/create-checkout-session", with: checkoutSession)
        env.mockAPIClient.delay = 0.1

        var states: [SubscriptionState] = []
        let cancellable = sut.$state.sink { states.append($0) }

        // When
        await sut.startCheckout()

        // Then
        XCTAssertTrue(states.contains(.loading))
        cancellable.cancel()
    }

    func testStartCheckoutFailsForLifetimePremiumUser() async {
        // Given
        env.mockUserRepository.currentUser = MockDataFactory.createLifetimeUser()
        sut = SubscriptionViewModel(apiClient: env.mockAPIClient, userRepository: env.mockUserRepository)

        // When
        await sut.startCheckout()

        // Then - should not make API call
        XCTAssertEqual(env.mockAPIClient.requestCallCount, 0)
    }

    // MARK: - Checkout Error Tests

    func testStartCheckoutServerError() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .serverError(500)

        // When
        await sut.startCheckout()

        // Then
        XCTAssertEqual(sut.state, .error(.stripeNotConfigured))
    }

    func testStartCheckoutBadRequest() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .badRequest("Invalid plan")

        // When
        await sut.startCheckout()

        // Then
        XCTAssertEqual(sut.state, .error(.paymentFailed("Invalid plan")))
    }

    // MARK: - Handle Checkout Complete Tests

    func testHandleCheckoutCompleteSuccess() {
        // Given
        sut.selectPlan(.yearly)

        // When
        sut.handleCheckoutComplete(success: true)

        // Then
        XCTAssertEqual(sut.state, .success(.yearly))
        XCTAssertEqual(sut.currentSubscription, .premium)
        XCTAssertNotNil(sut.subscriptionEndDate)
    }

    func testHandleCheckoutCompleteCancelled() {
        // When
        sut.handleCheckoutComplete(success: false)

        // Then
        XCTAssertEqual(sut.state, .error(.paymentCancelled))
    }

    // MARK: - Subscription End Date Tests

    func testMonthlySubscriptionEndDate() {
        // Given
        sut.selectPlan(.monthly)

        // When
        sut.handleCheckoutComplete(success: true)

        // Then
        if let endDate = sut.subscriptionEndDate {
            let expectedDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
            let difference = Calendar.current.dateComponents([.day], from: endDate, to: expectedDate)
            XCTAssertEqual(difference.day, 0)
        } else {
            XCTFail("Expected subscription end date")
        }
    }

    func testYearlySubscriptionEndDate() {
        // Given
        sut.selectPlan(.yearly)

        // When
        sut.handleCheckoutComplete(success: true)

        // Then
        if let endDate = sut.subscriptionEndDate {
            let expectedDate = Calendar.current.date(byAdding: .day, value: 365, to: Date())!
            let difference = Calendar.current.dateComponents([.day], from: endDate, to: expectedDate)
            XCTAssertEqual(difference.day, 0)
        } else {
            XCTFail("Expected subscription end date")
        }
    }

    func testLifetimeSubscriptionNoEndDate() {
        // Given
        sut.selectPlan(.lifetime)

        // When
        sut.handleCheckoutComplete(success: true)

        // Then
        XCTAssertNil(sut.subscriptionEndDate)
    }

    // MARK: - Restore Purchases Tests

    func testRestorePurchasesSuccess() async {
        // Given
        let premiumUser = MockDataFactory.createPremiumUser()
        env.mockAPIClient.stub(endpoint: "/api/profile", with: premiumUser)

        // When
        await sut.restorePurchases()

        // Then
        XCTAssertEqual(sut.currentSubscription, .premium)
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - Features Tests

    func testFeatures() {
        let features = sut.features
        XCTAssertFalse(features.isEmpty)
        XCTAssertTrue(features.allSatisfy { $0.isPremiumOnly })
    }

    // MARK: - Plan Comparisons Tests

    func testPlanComparisons() {
        let comparisons = sut.planComparisons
        XCTAssertEqual(comparisons.count, 3)

        let yearlyComparison = comparisons.first { $0.plan == .yearly }
        XCTAssertNotNil(yearlyComparison)
        XCTAssertTrue(yearlyComparison!.isRecommended)
        XCTAssertEqual(yearlyComparison!.savings, 39.89)
    }

    // MARK: - Subscription Status Text Tests

    func testSubscriptionStatusTextFree() {
        sut = SubscriptionViewModel(apiClient: env.mockAPIClient, userRepository: nil)
        XCTAssertEqual(sut.subscriptionStatusText, "Free Plan")
    }

    func testSubscriptionStatusTextPremiumWithDate() {
        let endDate = Date.tomorrow
        env.mockUserRepository.currentUser = MockDataFactory.createPremiumUser(endDate: endDate)
        sut = SubscriptionViewModel(apiClient: env.mockAPIClient, userRepository: env.mockUserRepository)

        XCTAssertTrue(sut.subscriptionStatusText.contains("Premium until"))
    }

    func testSubscriptionStatusTextLifetime() {
        env.mockUserRepository.currentUser = MockDataFactory.createLifetimeUser()
        sut = SubscriptionViewModel(apiClient: env.mockAPIClient, userRepository: env.mockUserRepository)

        XCTAssertEqual(sut.subscriptionStatusText, "Lifetime Premium")
    }

    // MARK: - Clear Error Tests

    func testClearError() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .serverError(500)
        await sut.startCheckout()

        // When
        sut.clearError()

        // Then
        XCTAssertEqual(sut.state, .idle)
    }
}

// MARK: - Subscription Plan Tests

final class SubscriptionPlanTests: XCTestCase {

    func testPrices() {
        XCTAssertEqual(SubscriptionPlan.monthly.price, 9.99)
        XCTAssertEqual(SubscriptionPlan.yearly.price, 79.99)
        XCTAssertEqual(SubscriptionPlan.lifetime.price, 199.00)
    }

    func testPricesInCents() {
        XCTAssertEqual(SubscriptionPlan.monthly.priceInCents, 999)
        XCTAssertEqual(SubscriptionPlan.yearly.priceInCents, 7999)
        XCTAssertEqual(SubscriptionPlan.lifetime.priceInCents, 19900)
    }

    func testDisplayNames() {
        XCTAssertEqual(SubscriptionPlan.monthly.displayName, "Monthly Premium")
        XCTAssertEqual(SubscriptionPlan.yearly.displayName, "Yearly Premium")
        XCTAssertEqual(SubscriptionPlan.lifetime.displayName, "Lifetime Premium")
    }

    func testDurations() {
        XCTAssertEqual(SubscriptionPlan.monthly.durationInDays, 30)
        XCTAssertEqual(SubscriptionPlan.yearly.durationInDays, 365)
        XCTAssertNil(SubscriptionPlan.lifetime.durationInDays)
    }

    func testSavings() {
        XCTAssertNil(SubscriptionPlan.monthly.savings)
        XCTAssertNotNil(SubscriptionPlan.yearly.savings)
        XCTAssertNotNil(SubscriptionPlan.lifetime.savings)
    }
}
