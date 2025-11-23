import XCTest
import Combine
@testable import JustLayMe

@MainActor
final class ChatViewModelTests: ViewModelTestCase {

    var sut: ChatViewModel!

    override func setUp() {
        super.setUp()
        sut = ChatViewModel(apiClient: env.mockAPIClient, userRepository: env.mockUserRepository)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(sut.state, .idle)
        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertTrue(sut.inputMessage.isEmpty)
        XCTAssertEqual(sut.selectedCharacterType, .laymeV1)
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.canSendMessage)
    }

    // MARK: - Send Message Tests

    func testSendMessageSuccess() async {
        // Given
        let chatResponse = MockDataFactory.createChatResponse()
        env.mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)
        sut.inputMessage = "Hello!"

        // When
        await sut.sendMessage()

        // Then
        XCTAssertEqual(sut.messages.count, 2) // User + AI
        XCTAssertEqual(sut.messages.first?.senderType, .human)
        XCTAssertEqual(sut.messages.first?.content, "Hello!")
        XCTAssertEqual(sut.messages.last?.senderType, .ai)
        XCTAssertEqual(sut.messages.last?.content, chatResponse.response)
        XCTAssertTrue(sut.inputMessage.isEmpty)
        XCTAssertEqual(sut.state, .idle)
    }

    func testSendEmptyMessage() async {
        // Given
        sut.inputMessage = "   "

        // When
        await sut.sendMessage()

        // Then
        XCTAssertEqual(sut.state, .error(.invalidMessage))
        XCTAssertTrue(sut.messages.isEmpty)
    }

    func testCanSendMessage() {
        XCTAssertFalse(sut.canSendMessage)

        sut.inputMessage = "Hello"
        XCTAssertTrue(sut.canSendMessage)

        sut.inputMessage = "   "
        XCTAssertFalse(sut.canSendMessage)
    }

    func testSendMessageShowsLoadingState() async {
        // Given
        let chatResponse = MockDataFactory.createChatResponse()
        env.mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)
        env.mockAPIClient.delay = 0.1
        sut.inputMessage = "Hello"

        // Track states
        var states: [ChatState] = []
        let cancellable = sut.$state.sink { states.append($0) }

        // When
        await sut.sendMessage()

        // Then
        XCTAssertTrue(states.contains(.loading))
        cancellable.cancel()
    }

    // MARK: - Premium Model Message Limit Tests

    func testPremiumModelMessageLimit() async {
        // Given - select a premium model
        sut.selectCharacter(.uncensoredGPT)
        env.mockUserRepository.currentUser = MockDataFactory.createFreeUser()

        // Simulate 3 messages already sent
        sut.inputMessage = "Test"
        for _ in 0..<3 {
            let chatResponse = MockDataFactory.createChatResponse()
            env.mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)
            await sut.sendMessage()
            sut.inputMessage = "Another message"
        }

        // When - try to send 4th message
        sut.inputMessage = "Fourth message"
        await sut.sendMessage()

        // Then
        XCTAssertEqual(sut.state, .error(.messageLimitReached))
    }

    func testFreeModelUnlimitedMessages() async {
        // Given - use free Layme V1
        sut.selectCharacter(.laymeV1)
        env.mockUserRepository.currentUser = MockDataFactory.createFreeUser()

        // When - send many messages
        for i in 0..<5 {
            let chatResponse = MockDataFactory.createChatResponse()
            env.mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)
            sut.inputMessage = "Message \(i)"
            await sut.sendMessage()
        }

        // Then
        XCTAssertEqual(sut.messages.count, 10) // 5 user + 5 AI
        XCTAssertEqual(sut.state, .idle)
    }

    func testPremiumUserNoMessageLimit() async {
        // Given
        sut.selectCharacter(.uncensoredGPT)
        env.mockUserRepository.currentUser = MockDataFactory.createPremiumUser()

        // Send more than 3 messages
        for i in 0..<5 {
            let chatResponse = MockDataFactory.createChatResponse()
            env.mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)
            sut.inputMessage = "Message \(i)"
            await sut.sendMessage()
        }

        // Then - no error, all messages sent
        XCTAssertEqual(sut.messages.count, 10)
        XCTAssertEqual(sut.state, .idle)
    }

    func testRemainingFreeMessages() async {
        // Given
        sut.selectCharacter(.uncensoredGPT)

        // When - send 2 messages
        for _ in 0..<2 {
            let chatResponse = MockDataFactory.createChatResponse()
            env.mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)
            sut.inputMessage = "Test"
            await sut.sendMessage()
        }

        // Then
        XCTAssertEqual(sut.remainingFreeMessages, 1)
    }

    // MARK: - Character Selection Tests

    func testSelectCharacter() {
        XCTAssertEqual(sut.selectedCharacterType, .laymeV1)

        sut.selectCharacter(.roleplay)
        XCTAssertEqual(sut.selectedCharacterType, .roleplay)

        sut.selectCharacter(.companion)
        XCTAssertEqual(sut.selectedCharacterType, .companion)
    }

    // MARK: - Clear Chat Tests

    func testClearChat() async {
        // Given - add some messages
        let chatResponse = MockDataFactory.createChatResponse()
        env.mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)
        sut.inputMessage = "Hello"
        await sut.sendMessage()

        XCTAssertFalse(sut.messages.isEmpty)

        // When
        sut.clearChat()

        // Then
        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertNil(sut.currentSession)
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - Retry Message Tests

    func testRetryLastMessage() async {
        // Given - send a message
        let chatResponse = MockDataFactory.createChatResponse()
        env.mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)
        sut.inputMessage = "Original message"
        await sut.sendMessage()

        let originalMessageCount = sut.messages.count

        // When
        await sut.retryLastMessage()

        // Then
        XCTAssertEqual(sut.messages.count, originalMessageCount)
    }

    // MARK: - Session Management Tests

    func testSessionCreatedOnFirstMessage() async {
        // Given
        let chatResponse = MockDataFactory.createChatResponse(sessionId: "test-session-123")
        env.mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)
        sut.inputMessage = "Hello"

        XCTAssertNil(sut.currentSession)

        // When
        await sut.sendMessage()

        // Then
        XCTAssertNotNil(sut.currentSession)
        XCTAssertEqual(sut.currentSession?.id, "test-session-123")
    }

    // MARK: - Error Handling Tests

    func testAIUnavailableError() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .serverError(500)
        sut.inputMessage = "Hello"

        // When
        await sut.sendMessage()

        // Then
        XCTAssertEqual(sut.state, .error(.aiUnavailable))
    }

    func testNetworkError() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .badRequest("Network error")
        sut.inputMessage = "Hello"

        // When
        await sut.sendMessage()

        // Then
        if case .error(.networkError) = sut.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected network error state")
        }
    }

    // MARK: - Show Upgrade Prompt Tests

    func testShowUpgradePromptForPremiumModel() async {
        // Given - free user on premium model
        sut.selectCharacter(.uncensoredGPT)
        env.mockUserRepository.currentUser = MockDataFactory.createFreeUser()

        // Use up free messages
        for _ in 0..<3 {
            let chatResponse = MockDataFactory.createChatResponse()
            env.mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)
            sut.inputMessage = "Test"
            await sut.sendMessage()
        }

        // Then
        XCTAssertTrue(sut.showUpgradePrompt)
        XCTAssertEqual(sut.remainingFreeMessages, 0)
    }

    func testNoUpgradePromptForFreeModel() {
        // Given
        sut.selectCharacter(.laymeV1)

        // Then
        XCTAssertFalse(sut.showUpgradePrompt)
    }

    // MARK: - Message Content Tests

    func testMessageMetadataIncluded() async {
        // Given
        let chatResponse = MockDataFactory.createChatResponse(
            character: "Mythomax Roleplay",
            model: "mythomax-13b",
            customized: true
        )
        env.mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)
        sut.selectCharacter(.roleplay)
        sut.inputMessage = "Hello"

        // When
        await sut.sendMessage()

        // Then
        let aiMessage = sut.messages.last
        XCTAssertEqual(aiMessage?.metadata?.characterName, "Mythomax Roleplay")
        XCTAssertEqual(aiMessage?.metadata?.model, "mythomax-13b")
        XCTAssertEqual(aiMessage?.metadata?.customized, true)
    }

    // MARK: - Concurrent Message Tests

    func testPreventsConcurrentMessages() async {
        // Given
        env.mockAPIClient.delay = 0.5
        let chatResponse = MockDataFactory.createChatResponse()
        env.mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)

        sut.inputMessage = "First message"

        // When - start first message
        Task {
            await sut.sendMessage()
        }

        // Wait a bit for loading to start
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then - can't send while loading
        XCTAssertFalse(sut.canSendMessage)
    }
}
