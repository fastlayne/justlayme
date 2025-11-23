import XCTest
import Combine
@testable import JustLayMe

final class ChatRepositoryTests: XCTestCase {

    var sut: ChatRepository!
    var mockAPIClient: MockAPIClient!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = ChatRepository(apiClient: mockAPIClient)
        cancellables = []
    }

    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertTrue(sut.conversations.isEmpty)
        XCTAssertNil(sut.currentConversation)
        XCTAssertTrue(sut.cachedMessages.isEmpty)
    }

    // MARK: - Load Conversations Tests

    @MainActor
    func testLoadConversationsSuccess() async throws {
        // Given
        let conversations = MockDataFactory.createConversations(count: 5)
        mockAPIClient.stub(endpoint: "/api/conversations", with: conversations)

        // When
        let result = try await sut.loadConversations()

        // Then
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(sut.conversations.count, 5)
    }

    @MainActor
    func testLoadConversationsEmpty() async throws {
        // Given
        let conversations: [Conversation] = []
        mockAPIClient.stub(endpoint: "/api/conversations", with: conversations)

        // When
        let result = try await sut.loadConversations()

        // Then
        XCTAssertTrue(result.isEmpty)
        XCTAssertTrue(sut.conversations.isEmpty)
    }

    @MainActor
    func testLoadConversationsError() async {
        // Given
        mockAPIClient.shouldFail = true
        mockAPIClient.errorToThrow = .serverError(500)

        // When/Then
        do {
            _ = try await sut.loadConversations()
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(sut.conversations.isEmpty)
        }
    }

    // MARK: - Load Messages Tests

    @MainActor
    func testLoadMessagesSuccess() async throws {
        // Given
        let messages = MockDataFactory.createConversation(count: 10)
        mockAPIClient.stub(endpoint: "/api/conversations/conv123/messages", with: messages)

        // When
        let result = try await sut.loadMessages(for: "conv123")

        // Then
        XCTAssertEqual(result.count, 10)
        XCTAssertEqual(sut.cachedMessages["conv123"]?.count, 10)
    }

    @MainActor
    func testLoadMessagesCachesResults() async throws {
        // Given
        let messages = MockDataFactory.createConversation(count: 5)
        mockAPIClient.stub(endpoint: "/api/conversations/conv1/messages", with: messages)

        // When
        _ = try await sut.loadMessages(for: "conv1")
        _ = try await sut.loadMessages(for: "conv1")

        // Then - API called twice (no automatic caching)
        XCTAssertEqual(mockAPIClient.requestCallCount, 2)
        XCTAssertNotNil(sut.cachedMessages["conv1"])
    }

    // MARK: - Search Conversations Tests

    @MainActor
    func testSearchConversationsSuccess() async throws {
        // Given
        let conversations = MockDataFactory.createConversations(count: 3)
        mockAPIClient.stub(endpoint: "/api/conversations/search", with: conversations)

        // When
        let result = try await sut.searchConversations(query: "test")

        // Then
        XCTAssertEqual(result.count, 3)
    }

    // MARK: - Archive Conversation Tests

    @MainActor
    func testArchiveConversationSuccess() async throws {
        // Given
        let conversations = MockDataFactory.createConversations(count: 1)
        sut.conversations = conversations
        let conversationId = conversations[0].id

        // When
        try await sut.archiveConversation(id: conversationId)

        // Then
        XCTAssertTrue(sut.conversations.first?.isArchived ?? false)
    }

    @MainActor
    func testArchiveConversationNotFound() async throws {
        // Given - empty conversations

        // When
        try await sut.archiveConversation(id: "nonexistent")

        // Then - should not crash
        XCTAssertTrue(sut.conversations.isEmpty)
    }

    // MARK: - Delete Conversation Tests

    @MainActor
    func testDeleteConversationSuccess() async throws {
        // Given
        let conversations = MockDataFactory.createConversations(count: 3)
        sut.conversations = conversations
        let conversationToDelete = conversations[1]
        sut.cachedMessages[conversationToDelete.id] = MockDataFactory.createConversation(count: 5)

        // When
        try await sut.deleteConversation(id: conversationToDelete.id)

        // Then
        XCTAssertEqual(sut.conversations.count, 2)
        XCTAssertNil(sut.cachedMessages[conversationToDelete.id])
    }

    @MainActor
    func testDeleteConversationClearsCache() async throws {
        // Given
        let conversationId = "test-conv"
        sut.cachedMessages[conversationId] = MockDataFactory.createConversation(count: 10)

        // When
        try await sut.deleteConversation(id: conversationId)

        // Then
        XCTAssertNil(sut.cachedMessages[conversationId])
    }

    // MARK: - Export Conversation Tests

    @MainActor
    func testExportConversationSuccess() async throws {
        // Given
        let conversation = MockDataFactory.createConversationModel()
        let messages = MockDataFactory.createConversation(count: 5)
        let exportedConv = ExportedConversation(conversation: conversation, messages: messages, exportedAt: Date())
        mockAPIClient.stub(endpoint: "/api/conversations/\(conversation.id)/export", with: exportedConv)

        // When
        let result = try await sut.exportConversation(id: conversation.id)

        // Then
        XCTAssertEqual(result.conversation.id, conversation.id)
        XCTAssertEqual(result.messages.count, 5)
    }

    // MARK: - Current Conversation Tests

    @MainActor
    func testSetCurrentConversation() {
        // Given
        let conversation = MockDataFactory.createConversationModel()

        // When
        sut.setCurrentConversation(conversation)

        // Then
        XCTAssertEqual(sut.currentConversation, conversation)
    }

    @MainActor
    func testClearCurrentConversation() {
        // Given
        sut.setCurrentConversation(MockDataFactory.createConversationModel())

        // When
        sut.setCurrentConversation(nil)

        // Then
        XCTAssertNil(sut.currentConversation)
    }

    // MARK: - Clear Cache Tests

    @MainActor
    func testClearCache() {
        // Given
        sut.cachedMessages["conv1"] = MockDataFactory.createConversation(count: 5)
        sut.cachedMessages["conv2"] = MockDataFactory.createConversation(count: 3)

        // When
        sut.clearCache()

        // Then
        XCTAssertTrue(sut.cachedMessages.isEmpty)
    }
}
