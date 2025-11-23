import Foundation
@testable import JustLayMe

// MARK: - Mock API Client

class MockAPIClient: APIClientProtocol {
    // Tracking
    var requestCallCount = 0
    var lastEndpoint: APIEndpoint?
    var requestedEndpoints: [APIEndpoint] = []

    // Configurable responses
    var shouldFail = false
    var errorToThrow: APIError?
    var delay: TimeInterval = 0

    // Response stubs
    var stubbedResponses: [String: Any] = [:]
    var defaultResponse: Any?

    func reset() {
        requestCallCount = 0
        lastEndpoint = nil
        requestedEndpoints = []
        shouldFail = false
        errorToThrow = nil
        delay = 0
        stubbedResponses = [:]
        defaultResponse = nil
    }

    func stub<T: Decodable>(endpoint path: String, with response: T) {
        stubbedResponses[path] = response
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        requestCallCount += 1
        lastEndpoint = endpoint
        requestedEndpoints.append(endpoint)

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw errorToThrow ?? APIError.serverError(500)
        }

        // Check for stubbed response
        if let response = stubbedResponses[endpoint.path] as? T {
            return response
        }

        // Check for default response
        if let response = defaultResponse as? T {
            return response
        }

        throw APIError.noData
    }

    func requestVoid(_ endpoint: APIEndpoint) async throws {
        requestCallCount += 1
        lastEndpoint = endpoint
        requestedEndpoints.append(endpoint)

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw errorToThrow ?? APIError.serverError(500)
        }
    }
}

// MARK: - Mock Keychain Service

class MockKeychainService: KeychainServiceProtocol {
    var storedToken: String?
    var shouldFailSave = false
    var shouldFailRead = false
    var shouldFailDelete = false

    var saveCallCount = 0
    var getCallCount = 0
    var deleteCallCount = 0

    func reset() {
        storedToken = nil
        shouldFailSave = false
        shouldFailRead = false
        shouldFailDelete = false
        saveCallCount = 0
        getCallCount = 0
        deleteCallCount = 0
    }

    func save(token: String) throws {
        saveCallCount += 1
        if shouldFailSave {
            throw KeychainError.saveFailed
        }
        storedToken = token
    }

    func getToken() throws -> String? {
        getCallCount += 1
        if shouldFailRead {
            throw KeychainError.readFailed
        }
        return storedToken
    }

    func deleteToken() throws {
        deleteCallCount += 1
        if shouldFailDelete {
            throw KeychainError.deleteFailed
        }
        storedToken = nil
    }
}

// MARK: - Mock User Repository

class MockUserRepository: UserRepositoryProtocol {
    var currentUser: User?
    var updateSubscriptionCallCount = 0
    var lastSubscriptionStatus: SubscriptionStatus?
    var lastSubscriptionEndDate: Date?

    func reset() {
        currentUser = nil
        updateSubscriptionCallCount = 0
        lastSubscriptionStatus = nil
        lastSubscriptionEndDate = nil
    }

    func setUser(_ user: User?) {
        currentUser = user
    }

    func updateSubscription(_ status: SubscriptionStatus, endDate: Date?) {
        updateSubscriptionCallCount += 1
        lastSubscriptionStatus = status
        lastSubscriptionEndDate = endDate
        currentUser?.subscriptionStatus = status
        currentUser?.subscriptionEnd = endDate
    }
}

// MARK: - Mock Chat Repository

class MockChatRepository: ChatRepositoryProtocol {
    var conversations: [Conversation] = []
    var currentConversation: Conversation?
    var cachedMessages: [String: [ChatMessage]] = [:]

    var shouldFail = false
    var loadConversationsCallCount = 0
    var loadMessagesCallCount = 0
    var searchCallCount = 0
    var archiveCallCount = 0
    var deleteCallCount = 0
    var exportCallCount = 0

    func reset() {
        conversations = []
        currentConversation = nil
        cachedMessages = [:]
        shouldFail = false
        loadConversationsCallCount = 0
        loadMessagesCallCount = 0
        searchCallCount = 0
        archiveCallCount = 0
        deleteCallCount = 0
        exportCallCount = 0
    }

    func loadConversations() async throws -> [Conversation] {
        loadConversationsCallCount += 1
        if shouldFail { throw APIError.serverError(500) }
        return conversations
    }

    func loadMessages(for conversationId: String) async throws -> [ChatMessage] {
        loadMessagesCallCount += 1
        if shouldFail { throw APIError.serverError(500) }
        return cachedMessages[conversationId] ?? []
    }

    func searchConversations(query: String) async throws -> [Conversation] {
        searchCallCount += 1
        if shouldFail { throw APIError.serverError(500) }
        return conversations.filter { $0.title?.contains(query) ?? false }
    }

    func archiveConversation(id: String) async throws {
        archiveCallCount += 1
        if shouldFail { throw APIError.serverError(500) }
    }

    func deleteConversation(id: String) async throws {
        deleteCallCount += 1
        if shouldFail { throw APIError.serverError(500) }
        conversations.removeAll { $0.id == id }
    }

    func exportConversation(id: String) async throws -> ExportedConversation {
        exportCallCount += 1
        if shouldFail { throw APIError.serverError(500) }
        guard let conversation = conversations.first(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        return ExportedConversation(
            conversation: conversation,
            messages: cachedMessages[id] ?? [],
            exportedAt: Date()
        )
    }
}

// MARK: - Mock Character Repository

class MockCharacterRepository: CharacterRepositoryProtocol {
    var characters: [AICharacter] = []
    var customizationOptions: CustomizationOptions?

    var shouldFail = false
    var loadCharactersCallCount = 0
    var loadCustomizationOptionsCallCount = 0
    var createCharacterCallCount = 0
    var updateCharacterCallCount = 0
    var deleteCharacterCallCount = 0

    func reset() {
        characters = []
        customizationOptions = nil
        shouldFail = false
        loadCharactersCallCount = 0
        loadCustomizationOptionsCallCount = 0
        createCharacterCallCount = 0
        updateCharacterCallCount = 0
        deleteCharacterCallCount = 0
    }

    func loadCharacters() async throws -> [AICharacter] {
        loadCharactersCallCount += 1
        if shouldFail { throw APIError.serverError(500) }
        return characters
    }

    func loadCustomizationOptions(for characterId: String) async throws -> CustomizationOptions {
        loadCustomizationOptionsCallCount += 1
        if shouldFail { throw APIError.serverError(500) }
        return customizationOptions ?? MockDataFactory.createCustomizationOptions()
    }

    func createCharacter(_ character: AICharacter) async throws -> AICharacter {
        createCharacterCallCount += 1
        if shouldFail { throw APIError.serverError(500) }
        var newCharacter = character
        characters.append(newCharacter)
        return newCharacter
    }

    func updateCharacter(_ character: AICharacter) async throws -> AICharacter {
        updateCharacterCallCount += 1
        if shouldFail { throw APIError.serverError(500) }
        if let index = characters.firstIndex(where: { $0.id == character.id }) {
            characters[index] = character
        }
        return character
    }

    func deleteCharacter(id: String) async throws {
        deleteCharacterCallCount += 1
        if shouldFail { throw APIError.serverError(500) }
        characters.removeAll { $0.id == id }
    }
}
