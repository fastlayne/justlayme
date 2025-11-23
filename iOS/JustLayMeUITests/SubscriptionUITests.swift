import XCTest

final class SubscriptionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-auth", "--free-user"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Subscription Screen Tests

    func testSubscriptionScreenElementsExist() {
        // Given
        navigateToSubscription()

        // Then
        XCTAssertTrue(app.staticTexts["Premium Features"].exists)
        XCTAssertTrue(app.buttons["monthlyPlanButton"].exists)
        XCTAssertTrue(app.buttons["yearlyPlanButton"].exists)
        XCTAssertTrue(app.buttons["lifetimePlanButton"].exists)
    }

    func testPlanPricesDisplayed() {
        // Given
        navigateToSubscription()

        // Then
        XCTAssertTrue(app.staticTexts["$9.99"].exists)
        XCTAssertTrue(app.staticTexts["$79.99"].exists)
        XCTAssertTrue(app.staticTexts["$199"].exists)
    }

    func testYearlyPlanShowsSavings() {
        // Given
        navigateToSubscription()

        // Then
        XCTAssertTrue(app.staticTexts["Save 33%"].exists || app.staticTexts["Save $39.89/year"].exists)
    }

    func testSelectPlan() {
        // Given
        navigateToSubscription()

        // When
        app.buttons["yearlyPlanButton"].tap()

        // Then
        XCTAssertTrue(app.buttons["yearlyPlanButton"].isSelected)
    }

    func testFeaturesList() {
        // Given
        navigateToSubscription()

        // Then
        XCTAssertTrue(app.staticTexts["Unlimited Messages"].exists)
        XCTAssertTrue(app.staticTexts["All AI Models"].exists)
        XCTAssertTrue(app.staticTexts["Chat History"].exists)
        XCTAssertTrue(app.staticTexts["Custom Characters"].exists)
    }

    func testSubscribeButton() {
        // Given
        navigateToSubscription()

        // When
        app.buttons["subscribeButton"].tap()

        // Then - Should show payment sheet or navigate to checkout
        waitForElement(app.staticTexts["Payment"].exists ? app.staticTexts["Payment"] : app.webViews.element, timeout: 5)
    }

    func testRestorePurchasesButton() {
        // Given
        navigateToSubscription()

        // Then
        XCTAssertTrue(app.buttons["restorePurchasesButton"].exists)
    }

    func testCurrentPlanDisplay() {
        // Given - launch as premium user
        app.launchArguments = ["--uitesting", "--skip-auth", "--premium-user"]
        app.launch()
        navigateToSubscription()

        // Then
        XCTAssertTrue(app.staticTexts["Current Plan: Premium"].exists || app.staticTexts["Premium"].exists)
    }

    // MARK: - Helper Methods

    private func navigateToSubscription() {
        if app.tabBars["mainTabBar"].exists {
            app.tabBars["mainTabBar"].buttons["Settings"].tap()
        }
        if app.buttons["subscriptionButton"].exists {
            app.buttons["subscriptionButton"].tap()
        }
    }

    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval) {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element \(element) did not appear")
    }
}
