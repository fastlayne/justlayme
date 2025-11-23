// MARK: - Chat Service
// Handles all chat-related API operations

import Foundation
import Combine

public final class ChatService: ObservableObject {
    public static let shared = ChatService()

    private let client: APIClient
    private var cancellables = Set<AnyCancellable>()

    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var currentSessionId: String?
    @Published public private(set) var lastResponse: ChatResponse?

    public init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Main Chat Endpoint (Public - No Auth Required)

    /// Send a chat message to the AI (works for both authenticated and guest users)
    public func sendMessage(
        _ message: String,
        characterId: CharacterType = .laymeV1,
        userId: String? = nil
    ) -> AnyPublisher<ChatResponse, APIError> {
        isLoading = true

        let request = ChatRequest(
            message: message,
            characterId: characterId.rawValue,
            userId: userId
        )

        return client.request(.chat, body: request)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.lastResponse = response
                    if let sessionId = response.sessionId {
                        self?.currentSessionId = sessionId
                        self?.client.sessionId = sessionId
                    }
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func sendMessage(
        _ message: String,
        characterId: CharacterType = .laymeV1,
        userId: String? = nil
    ) async throws -> ChatResponse {
        isLoading = true
        defer { isLoading = false }

        let request = ChatRequest(
            message: message,
            characterId: characterId.rawValue,
            userId: userId
        )

        let response: ChatResponse = try await client.request(.chat, body: request)
        lastResponse = response
        if let sessionId = response.sessionId {
            currentSessionId = sessionId
            client.sessionId = sessionId
        }
        return response
    }

    // MARK: - Character-Specific Chat (Authenticated)

    /// Send a chat message to a specific character (requires authentication)
    public func sendMessage(
        _ message: String,
        toCharacter characterId: String
    ) -> AnyPublisher<ChatResponse, APIError> {
        isLoading = true

        struct CharacterChatRequest: Codable {
            let message: String
        }

        let request = CharacterChatRequest(message: message)

        return client.request(.chatWithCharacter(characterId), body: request)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.lastResponse = response
                    if let sessionId = response.sessionId {
                        self?.currentSessionId = sessionId
                    }
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func sendMessage(
        _ message: String,
        toCharacter characterId: String
    ) async throws -> ChatResponse {
        isLoading = true
        defer { isLoading = false }

        struct CharacterChatRequest: Codable {
            let message: String
        }

        let request = CharacterChatRequest(message: message)
        let response: ChatResponse = try await client.request(.chatWithCharacter(characterId), body: request)
        lastResponse = response
        if let sessionId = response.sessionId {
            currentSessionId = sessionId
        }
        return response
    }

    // MARK: - Submit Feedback

    /// Submit feedback for an AI response
    public func submitFeedback(
        memoryId: String,
        score: Int,
        correctedResponse: String? = nil,
        patternType: String? = nil
    ) -> AnyPublisher<FeedbackResponse, APIError> {
        let request = FeedbackRequest(
            score: score,
            correctedResponse: correctedResponse,
            patternType: patternType
        )

        return client.request(.feedback(memoryId), body: request)
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func submitFeedback(
        memoryId: String,
        score: Int,
        correctedResponse: String? = nil,
        patternType: String? = nil
    ) async throws -> FeedbackResponse {
        let request = FeedbackRequest(
            score: score,
            correctedResponse: correctedResponse,
            patternType: patternType
        )

        return try await client.request(.feedback(memoryId), body: request)
    }

    // MARK: - Session Management

    /// Start a new chat session
    public func startNewSession() {
        currentSessionId = nil
        client.sessionId = nil
        lastResponse = nil
    }

    /// Set session ID (for resuming sessions)
    public func setSessionId(_ sessionId: String) {
        currentSessionId = sessionId
        client.sessionId = sessionId
    }
}

// MARK: - Chat Message Helper

public struct ChatMessage: Identifiable, Equatable {
    public let id: String
    public let content: String
    public let isUser: Bool
    public let timestamp: Date
    public let characterName: String?
    public let model: String?

    public init(
        id: String = UUID().uuidString,
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        characterName: String? = nil,
        model: String? = nil
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.characterName = characterName
        self.model = model
    }

    public static func fromResponse(_ response: ChatResponse, userMessage: String) -> [ChatMessage] {
        let userMsg = ChatMessage(
            content: userMessage,
            isUser: true
        )

        let aiMsg = ChatMessage(
            id: response.messageId ?? UUID().uuidString,
            content: response.response,
            isUser: false,
            characterName: response.character,
            model: response.model
        )

        return [userMsg, aiMsg]
    }
}

// MARK: - Chat View Model

/// A ready-to-use view model for chat interfaces
public final class ChatViewModel: ObservableObject {
    @Published public var messages: [ChatMessage] = []
    @Published public var currentMessage: String = ""
    @Published public var isLoading: Bool = false
    @Published public var error: String?
    @Published public var selectedCharacter: CharacterType = .laymeV1

    private let chatService: ChatService
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    public init(
        chatService: ChatService = .shared,
        authService: AuthService = .shared
    ) {
        self.chatService = chatService
        self.authService = authService

        // Observe loading state
        chatService.$isLoading
            .assign(to: &$isLoading)
    }

    public func sendMessage() {
        guard !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let messageText = currentMessage
        currentMessage = ""
        error = nil

        // Add user message immediately for responsiveness
        let userMessage = ChatMessage(content: messageText, isUser: true)
        messages.append(userMessage)

        chatService.sendMessage(
            messageText,
            characterId: selectedCharacter,
            userId: authService.currentUser?.id
        )
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let apiError) = completion {
                    self?.error = apiError.localizedDescription
                    // Remove the user message if failed
                    self?.messages.removeAll { $0.id == userMessage.id }
                }
            },
            receiveValue: { [weak self] response in
                let aiMessage = ChatMessage(
                    id: response.messageId ?? UUID().uuidString,
                    content: response.response,
                    isUser: false,
                    characterName: response.character,
                    model: response.model
                )
                self?.messages.append(aiMessage)
            }
        )
        .store(in: &cancellables)
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func sendMessageAsync() async {
        guard !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let messageText = currentMessage
        currentMessage = ""
        error = nil

        let userMessage = ChatMessage(content: messageText, isUser: true)
        messages.append(userMessage)

        do {
            let response = try await chatService.sendMessage(
                messageText,
                characterId: selectedCharacter,
                userId: authService.currentUser?.id
            )

            let aiMessage = ChatMessage(
                id: response.messageId ?? UUID().uuidString,
                content: response.response,
                isUser: false,
                characterName: response.character,
                model: response.model
            )
            messages.append(aiMessage)
        } catch let apiError as APIError {
            error = apiError.localizedDescription
            messages.removeAll { $0.id == userMessage.id }
        } catch {
            self.error = error.localizedDescription
            messages.removeAll { $0.id == userMessage.id }
        }
    }

    public func clearMessages() {
        messages.removeAll()
        chatService.startNewSession()
    }

    public func changeCharacter(to character: CharacterType) {
        selectedCharacter = character
        clearMessages()
    }
}
