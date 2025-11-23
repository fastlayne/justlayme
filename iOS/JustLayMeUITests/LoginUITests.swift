import XCTest

final class LoginUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Login Screen Tests

    func testLoginScreenElementsExist() {
        // Given
        navigateToLogin()

        // Then
        XCTAssertTrue(app.textFields["emailTextField"].exists)
        XCTAssertTrue(app.secureTextFields["passwordTextField"].exists)
        XCTAssertTrue(app.buttons["loginButton"].exists)
        XCTAssertTrue(app.buttons["signUpLink"].exists)
    }

    func testLoginWithValidCredentials() {
        // Given
        navigateToLogin()

        // When
        let emailField = app.textFields["emailTextField"]
        emailField.tap()
        emailField.typeText("test@example.com")

        let passwordField = app.secureTextFields["passwordTextField"]
        passwordField.tap()
        passwordField.typeText("password123")

        app.buttons["loginButton"].tap()

        // Then
        waitForElement(app.staticTexts["welcomeMessage"], timeout: 5)
    }

    func testLoginWithInvalidEmail() {
        // Given
        navigateToLogin()

        // When
        let emailField = app.textFields["emailTextField"]
        emailField.tap()
        emailField.typeText("notanemail")

        let passwordField = app.secureTextFields["passwordTextField"]
        passwordField.tap()
        passwordField.typeText("password123")

        app.buttons["loginButton"].tap()

        // Then
        waitForElement(app.staticTexts["errorMessage"], timeout: 2)
        XCTAssertTrue(app.staticTexts["errorMessage"].label.contains("email"))
    }

    func testLoginWithShortPassword() {
        // Given
        navigateToLogin()

        // When
        let emailField = app.textFields["emailTextField"]
        emailField.tap()
        emailField.typeText("test@example.com")

        let passwordField = app.secureTextFields["passwordTextField"]
        passwordField.tap()
        passwordField.typeText("123")

        app.buttons["loginButton"].tap()

        // Then
        waitForElement(app.staticTexts["errorMessage"], timeout: 2)
        XCTAssertTrue(app.staticTexts["errorMessage"].label.contains("6 characters"))
    }

    func testNavigateToSignUp() {
        // Given
        navigateToLogin()

        // When
        app.buttons["signUpLink"].tap()

        // Then
        waitForElement(app.staticTexts["signUpTitle"], timeout: 2)
        XCTAssertTrue(app.textFields["confirmPasswordTextField"].exists)
    }

    func testPasswordVisibilityToggle() {
        // Given
        navigateToLogin()

        let passwordField = app.secureTextFields["passwordTextField"]
        passwordField.tap()
        passwordField.typeText("password123")

        // When
        app.buttons["togglePasswordVisibility"].tap()

        // Then
        XCTAssertTrue(app.textFields["passwordTextFieldVisible"].exists)
    }

    // MARK: - Helper Methods

    private func navigateToLogin() {
        if app.buttons["getStartedButton"].exists {
            app.buttons["getStartedButton"].tap()
        }
        if app.buttons["loginTab"].exists {
            app.buttons["loginTab"].tap()
        }
    }

    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval) {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element \(element) did not appear within \(timeout) seconds")
    }
}
