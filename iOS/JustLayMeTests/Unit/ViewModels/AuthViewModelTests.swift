import XCTest
import Combine
@testable import JustLayMe

@MainActor
final class AuthViewModelTests: ViewModelTestCase {

    var sut: AuthViewModel!

    override func setUp() {
        super.setUp()
        sut = AuthViewModel(apiClient: env.mockAPIClient, keychain: env.mockKeychain)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(sut.state, .idle)
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.currentUser)
        XCTAssertTrue(sut.email.isEmpty)
        XCTAssertTrue(sut.password.isEmpty)
    }

    // MARK: - Login Tests

    func testLoginSuccess() async {
        // Given
        let expectedUser = MockDataFactory.createUser()
        let authResponse = MockDataFactory.createAuthResponse(user: expectedUser)
        env.mockAPIClient.stub(endpoint: "/api/login", with: authResponse)

        sut.email = "test@example.com"
        sut.password = "password123"

        // When
        await sut.login()

        // Then
        XCTAssertEqual(sut.state, .authenticated(expectedUser))
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertEqual(sut.currentUser, expectedUser)
        XCTAssertEqual(env.mockKeychain.saveCallCount, 1)
        XCTAssertEqual(env.mockKeychain.storedToken, authResponse.token)
    }

    func testLoginWithInvalidEmail() async {
        // Given
        sut.email = "notanemail"
        sut.password = "password123"

        // When
        await sut.login()

        // Then
        XCTAssertEqual(sut.state, .error(.invalidEmail))
        XCTAssertFalse(sut.isAuthenticated)
    }

    func testLoginWithEmptyEmail() async {
        // Given
        sut.email = ""
        sut.password = "password123"

        // When
        await sut.login()

        // Then
        XCTAssertEqual(sut.state, .error(.invalidEmail))
    }

    func testLoginWithShortPassword() async {
        // Given
        sut.email = "test@example.com"
        sut.password = "123"

        // When
        await sut.login()

        // Then
        XCTAssertEqual(sut.state, .error(.passwordTooShort))
    }

    func testLoginWithInvalidCredentials() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .unauthorized

        sut.email = "test@example.com"
        sut.password = "wrongpassword"

        // When
        await sut.login()

        // Then
        XCTAssertEqual(sut.state, .error(.invalidCredentials))
    }

    func testLoginWithUnverifiedEmail() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .forbidden("Email not verified")

        sut.email = "test@example.com"
        sut.password = "password123"

        // When
        await sut.login()

        // Then
        XCTAssertEqual(sut.state, .error(.emailNotVerified))
    }

    func testLoginClearsFormOnSuccess() async {
        // Given
        let authResponse = MockDataFactory.createAuthResponse()
        env.mockAPIClient.stub(endpoint: "/api/login", with: authResponse)

        sut.email = "test@example.com"
        sut.password = "password123"

        // When
        await sut.login()

        // Then
        XCTAssertTrue(sut.email.isEmpty)
        XCTAssertTrue(sut.password.isEmpty)
    }

    func testLoginShowsLoadingState() async {
        // Given
        let authResponse = MockDataFactory.createAuthResponse()
        env.mockAPIClient.stub(endpoint: "/api/login", with: authResponse)
        env.mockAPIClient.delay = 0.1

        sut.email = "test@example.com"
        sut.password = "password123"

        // Track state changes
        var states: [AuthState] = []
        let cancellable = sut.$state.sink { states.append($0) }

        // When
        await sut.login()

        // Then
        XCTAssertTrue(states.contains(.loading))
        cancellable.cancel()
    }

    // MARK: - Registration Tests

    func testRegisterSuccess() async {
        // Given
        let registrationResponse = MockDataFactory.createRegistrationResponse()
        env.mockAPIClient.stub(endpoint: "/api/register", with: registrationResponse)

        sut.email = "newuser@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        // When
        await sut.register()

        // Then
        if case .requiresVerification(let email) = sut.state {
            XCTAssertEqual(email, "newuser@example.com")
        } else {
            XCTFail("Expected requiresVerification state")
        }
    }

    func testRegisterWithMismatchedPasswords() async {
        // Given
        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "differentpassword"

        // When
        await sut.register()

        // Then
        XCTAssertEqual(sut.state, .error(.passwordsDoNotMatch))
    }

    func testRegisterWithExistingEmail() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .badRequest("Email already registered")

        sut.email = "existing@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"

        // When
        await sut.register()

        // Then
        XCTAssertEqual(sut.state, .error(.emailAlreadyRegistered))
    }

    // MARK: - Email Verification Tests

    func testResendVerificationEmail() async {
        // Given
        sut = AuthViewModel(apiClient: env.mockAPIClient, keychain: env.mockKeychain)

        // Set initial state to requiresVerification
        let registrationResponse = MockDataFactory.createRegistrationResponse()
        env.mockAPIClient.stub(endpoint: "/api/register", with: registrationResponse)
        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"
        await sut.register()

        // Stub resend endpoint
        let verificationResponse = MockDataFactory.createVerificationResponse()
        env.mockAPIClient.stub(endpoint: "/api/resend-verification", with: verificationResponse)

        // When
        await sut.resendVerificationEmail()

        // Then
        if case .requiresVerification = sut.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected requiresVerification state")
        }
    }

    func testVerifyEmailSuccess() async {
        // Given
        let verificationResponse = MockDataFactory.createVerificationResponse()
        env.mockAPIClient.stub(endpoint: "/api/verify-email", with: verificationResponse)

        // When
        await sut.verifyEmail(token: "valid-token")

        // Then
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - Check Auth Status Tests

    func testCheckAuthStatusWithValidToken() async {
        // Given
        let user = MockDataFactory.createUser()
        env.mockKeychain.storedToken = "valid-token"
        env.mockAPIClient.stub(endpoint: "/api/verify", with: user)

        // When
        await sut.checkAuthStatus()

        // Then
        XCTAssertEqual(sut.state, .authenticated(user))
        XCTAssertTrue(sut.isAuthenticated)
    }

    func testCheckAuthStatusWithNoToken() async {
        // Given
        env.mockKeychain.storedToken = nil

        // When
        await sut.checkAuthStatus()

        // Then
        XCTAssertEqual(sut.state, .idle)
        XCTAssertFalse(sut.isAuthenticated)
    }

    func testCheckAuthStatusWithExpiredToken() async {
        // Given
        env.mockKeychain.storedToken = "expired-token"
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .unauthorized

        // When
        await sut.checkAuthStatus()

        // Then
        XCTAssertEqual(sut.state, .idle)
        XCTAssertNil(env.mockKeychain.storedToken)
    }

    // MARK: - Logout Tests

    func testLogout() async {
        // Given - first login
        let authResponse = MockDataFactory.createAuthResponse()
        env.mockAPIClient.stub(endpoint: "/api/login", with: authResponse)
        sut.email = "test@example.com"
        sut.password = "password123"
        await sut.login()

        XCTAssertTrue(sut.isAuthenticated)

        // When
        sut.logout()

        // Then
        XCTAssertEqual(sut.state, .idle)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.currentUser)
        XCTAssertNil(env.mockKeychain.storedToken)
    }

    // MARK: - Clear Error Tests

    func testClearError() async {
        // Given
        sut.email = "notanemail"
        sut.password = "password123"
        await sut.login()
        XCTAssertEqual(sut.state, .error(.invalidEmail))

        // When
        sut.clearError()

        // Then
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - Credential Validation Tests

    func testLoginCredentialsValidation() {
        sut.email = "test@example.com"
        sut.password = "password123"
        XCTAssertTrue(sut.loginCredentials.isValid)

        sut.email = ""
        XCTAssertFalse(sut.loginCredentials.isValid)

        sut.email = "test@example.com"
        sut.password = "12345"
        XCTAssertFalse(sut.loginCredentials.isValid)
    }

    func testRegistrationCredentialsValidation() {
        sut.email = "test@example.com"
        sut.password = "password123"
        sut.confirmPassword = "password123"
        XCTAssertTrue(sut.registrationCredentials.isValid)
        XCTAssertTrue(sut.registrationCredentials.passwordsMatch)

        sut.confirmPassword = "different"
        XCTAssertFalse(sut.registrationCredentials.isValid)
        XCTAssertFalse(sut.registrationCredentials.passwordsMatch)
    }

    // MARK: - Network Error Tests

    func testLoginNetworkError() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .serverError(500)

        sut.email = "test@example.com"
        sut.password = "password123"

        // When
        await sut.login()

        // Then
        if case .error(.serverError) = sut.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected server error state")
        }
    }

    // MARK: - Trimming Tests

    func testEmailIsTrimmed() async {
        // Given
        let authResponse = MockDataFactory.createAuthResponse()
        env.mockAPIClient.stub(endpoint: "/api/login", with: authResponse)

        sut.email = "  test@example.com  "
        sut.password = "password123"

        // When
        await sut.login()

        // Then - check the endpoint was called (email trimmed internally)
        XCTAssertEqual(env.mockAPIClient.requestCallCount, 1)
    }
}
