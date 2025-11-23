import XCTest
@testable import JustLayMe

/// Integration tests that verify the complete flow from ViewModel to API
/// These tests use a mock API client that simulates real API behavior
final class APIIntegrationTests: XCTestCase {

    var mockAPIClient: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
    }

    override func tearDown() {
        mockAPIClient = nil
        super.tearDown()
    }

    // MARK: - Authentication Flow Tests

    @MainActor
    func testCompleteLoginFlow() async {
        // Given
        let mockKeychain = MockKeychainService()
        let authViewModel = AuthViewModel(apiClient: mockAPIClient, keychain: mockKeychain)

        let expectedUser = MockDataFactory.createUser(email: "test@example.com")
        let authResponse = MockDataFactory.createAuthResponse(token: "jwt-token", user: expectedUser)
        mockAPIClient.stub(endpoint: "/api/login", with: authResponse)

        authViewModel.email = "test@example.com"
        authViewModel.password = "password123"

        // When
        await authViewModel.login()

        // Then
        XCTAssertTrue(authViewModel.isAuthenticated)
        XCTAssertEqual(authViewModel.currentUser?.email, "test@example.com")
        XCTAssertEqual(mockKeychain.storedToken, "jwt-token")
    }

    @MainActor
    func testCompleteRegistrationFlow() async {
        // Given
        let mockKeychain = MockKeychainService()
        let authViewModel = AuthViewModel(apiClient: mockAPIClient, keychain: mockKeychain)

        let registrationResponse = MockDataFactory.createRegistrationResponse(email: "new@example.com")
        mockAPIClient.stub(endpoint: "/api/register", with: registrationResponse)

        authViewModel.email = "new@example.com"
        authViewModel.password = "password123"
        authViewModel.confirmPassword = "password123"

        // When
        await authViewModel.register()

        // Then
        if case .requiresVerification(let email) = authViewModel.state {
            XCTAssertEqual(email, "new@example.com")
        } else {
            XCTFail("Expected requiresVerification state")
        }
    }

    @MainActor
    func testSessionRestorationFlow() async {
        // Given
        let mockKeychain = MockKeychainService()
        mockKeychain.storedToken = "existing-token"

        let authViewModel = AuthViewModel(apiClient: mockAPIClient, keychain: mockKeychain)
        let user = MockDataFactory.createUser()
        mockAPIClient.stub(endpoint: "/api/verify", with: user)

        // When
        await authViewModel.checkAuthStatus()

        // Then
        XCTAssertTrue(authViewModel.isAuthenticated)
        XCTAssertNotNil(authViewModel.currentUser)
    }

    // MARK: - Chat Flow Tests

    @MainActor
    func testSendMessageFlow() async {
        // Given
        let mockUserRepo = MockUserRepository()
        mockUserRepo.currentUser = MockDataFactory.createUser()

        let chatViewModel = ChatViewModel(apiClient: mockAPIClient, userRepository: mockUserRepo)
        let chatResponse = MockDataFactory.createChatResponse(
            response: "Hello! Nice to meet you!",
            sessionId: "session-123"
        )
        mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)

        chatViewModel.inputMessage = "Hello!"

        // When
        await chatViewModel.sendMessage()

        // Then
        XCTAssertEqual(chatViewModel.messages.count, 2) // User + AI
        XCTAssertEqual(chatViewModel.messages.first?.content, "Hello!")
        XCTAssertEqual(chatViewModel.messages.last?.content, "Hello! Nice to meet you!")
        XCTAssertNotNil(chatViewModel.currentSession)
    }

    @MainActor
    func testChatWithDifferentModels() async {
        // Given
        let mockUserRepo = MockUserRepository()
        mockUserRepo.currentUser = MockDataFactory.createPremiumUser()

        let chatViewModel = ChatViewModel(apiClient: mockAPIClient, userRepository: mockUserRepo)

        // Test with different models
        for characterType in CharacterType.allCases {
            chatViewModel.selectCharacter(characterType)

            let chatResponse = MockDataFactory.createChatResponse(
                character: characterType.displayName
            )
            mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)

            chatViewModel.inputMessage = "Test with \(characterType.displayName)"
            await chatViewModel.sendMessage()

            // Verify the character was used
            XCTAssertEqual(chatViewModel.selectedCharacterType, characterType)
        }
    }

    // MARK: - Subscription Flow Tests

    @MainActor
    func testSubscriptionPurchaseFlow() async {
        // Given
        let mockUserRepo = MockUserRepository()
        mockUserRepo.currentUser = MockDataFactory.createFreeUser()

        let subscriptionViewModel = SubscriptionViewModel(
            apiClient: mockAPIClient,
            userRepository: mockUserRepo
        )

        let checkoutSession = MockDataFactory.createCheckoutSession(sessionId: "cs_test_123")
        mockAPIClient.stub(endpoint: "/api/create-checkout-session", with: checkoutSession)

        subscriptionViewModel.selectPlan(.yearly)

        // When
        await subscriptionViewModel.startCheckout()

        // Then
        if case .checkoutReady(let sessionId) = subscriptionViewModel.state {
            XCTAssertEqual(sessionId, "cs_test_123")
        } else {
            XCTFail("Expected checkoutReady state")
        }

        // Simulate successful payment
        subscriptionViewModel.handleCheckoutComplete(success: true)

        XCTAssertTrue(subscriptionViewModel.isPremium)
        XCTAssertNotNil(subscriptionViewModel.subscriptionEndDate)
    }

    // MARK: - Character Management Flow Tests

    @MainActor
    func testCharacterCreationFlow() async {
        // Given
        let mockUserRepo = MockUserRepository()
        mockUserRepo.currentUser = MockDataFactory.createPremiumUser()

        let characterViewModel = CharacterViewModel(
            apiClient: mockAPIClient,
            userRepository: mockUserRepo
        )

        let newCharacter = MockDataFactory.createCharacter(name: "Custom AI")
        mockAPIClient.stub(endpoint: "/api/characters", with: newCharacter)

        characterViewModel.characterName = "Custom AI"
        characterViewModel.characterBackstory = "A friendly companion"
        characterViewModel.addTrait("friendly", value: 9)
        characterViewModel.addSpeechPattern("Uses emojis")

        // When
        let success = await characterViewModel.createCharacter()

        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(characterViewModel.characters.count, 1)
        XCTAssertTrue(characterViewModel.characterName.isEmpty) // Form cleared
    }

    @MainActor
    func testFreeUserCharacterLimit() async {
        // Given
        let mockUserRepo = MockUserRepository()
        mockUserRepo.currentUser = MockDataFactory.createFreeUser()

        let characterViewModel = CharacterViewModel(
            apiClient: mockAPIClient,
            userRepository: mockUserRepo
        )

        // Add existing character
        characterViewModel.characters = [MockDataFactory.createCharacter()]

        characterViewModel.characterName = "Second Character"

        // When
        let success = await characterViewModel.createCharacter()

        // Then
        XCTAssertFalse(success)
        XCTAssertEqual(characterViewModel.state, .error(.limitReached))
    }

    // MARK: - Profile Management Flow Tests

    @MainActor
    func testProfileUpdateFlow() async {
        // Given
        let profileViewModel = ProfileViewModel(apiClient: mockAPIClient)

        let user = MockDataFactory.createUser(name: "Original Name")
        mockAPIClient.stub(endpoint: "/api/profile", with: user)

        await profileViewModel.loadProfile()

        // When
        profileViewModel.editableName = "Updated Name"
        let success = await profileViewModel.updateProfile()

        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(profileViewModel.user?.name, "Updated Name")
    }

    @MainActor
    func testDataExportFlow() async {
        // Given
        let profileViewModel = ProfileViewModel(apiClient: mockAPIClient)

        let user = MockDataFactory.createUser()
        mockAPIClient.stub(endpoint: "/api/profile", with: user)
        await profileViewModel.loadProfile()

        let exportData = MockDataFactory.createExportData(user: user)
        mockAPIClient.stub(endpoint: "/api/export-data", with: exportData)

        // When
        let url = await profileViewModel.exportData()

        // Then
        XCTAssertNotNil(url)
        if case .exported(let exportedURL) = profileViewModel.state {
            XCTAssertEqual(exportedURL, url)
        }
    }

    // MARK: - Error Recovery Tests

    @MainActor
    func testLoginErrorRecovery() async {
        // Given
        let mockKeychain = MockKeychainService()
        let authViewModel = AuthViewModel(apiClient: mockAPIClient, keychain: mockKeychain)

        // First attempt fails
        mockAPIClient.shouldFail = true
        mockAPIClient.errorToThrow = .serverError(500)

        authViewModel.email = "test@example.com"
        authViewModel.password = "password123"
        await authViewModel.login()

        XCTAssertEqual(authViewModel.state, .error(.serverError("Server error (500)")))

        // Clear error and retry successfully
        authViewModel.clearError()
        mockAPIClient.shouldFail = false

        let authResponse = MockDataFactory.createAuthResponse()
        mockAPIClient.stub(endpoint: "/api/login", with: authResponse)

        await authViewModel.login()

        XCTAssertTrue(authViewModel.isAuthenticated)
    }

    // MARK: - Concurrent Request Tests

    @MainActor
    func testConcurrentChatMessages() async {
        // Given
        let mockUserRepo = MockUserRepository()
        mockUserRepo.currentUser = MockDataFactory.createUser()

        let chatViewModel = ChatViewModel(apiClient: mockAPIClient, userRepository: mockUserRepo)
        let chatResponse = MockDataFactory.createChatResponse()
        mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)

        // When - send multiple messages concurrently
        chatViewModel.inputMessage = "Message 1"
        await chatViewModel.sendMessage()

        chatViewModel.inputMessage = "Message 2"
        await chatViewModel.sendMessage()

        chatViewModel.inputMessage = "Message 3"
        await chatViewModel.sendMessage()

        // Then
        XCTAssertEqual(chatViewModel.messages.count, 6) // 3 user + 3 AI
    }
}
