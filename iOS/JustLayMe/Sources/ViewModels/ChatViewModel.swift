import Foundation
import Combine

// MARK: - Chat State

enum ChatState: Equatable {
    case idle
    case loading
    case streaming
    case error(ChatError)
}

enum ChatError: Error, Equatable, LocalizedError {
    case messageLimitReached
    case premiumRequired
    case aiUnavailable
    case networkError(String)
    case invalidMessage

    var errorDescription: String? {
        switch self {
        case .messageLimitReached:
            return "You've reached your message limit. Upgrade to Premium for unlimited messages."
        case .premiumRequired:
            return "This feature requires a Premium subscription."
        case .aiUnavailable:
            return "AI service is temporarily unavailable. Please try again."
        case .networkError(let message):
            return message
        case .invalidMessage:
            return "Please enter a valid message."
        }
    }
}

// MARK: - Chat ViewModel

@MainActor
class ChatViewModel: ObservableObject {
    @Published private(set) var state: ChatState = .idle
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var currentSession: ChatSession?
    @Published var inputMessage: String = ""
    @Published var selectedCharacterType: CharacterType = .laymeV1
    @Published private(set) var messageCountForPremiumModels: [String: Int] = [:]

    private let apiClient: APIClientProtocol
    private let userRepository: UserRepositoryProtocol?
    private var cancellables = Set<AnyCancellable>()

    var isLoading: Bool {
        if case .loading = state { return true }
        if case .streaming = state { return true }
        return false
    }

    var canSendMessage: Bool {
        !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var remainingFreeMessages: Int {
        let count = messageCountForPremiumModels[selectedCharacterType.rawValue] ?? 0
        return max(0, selectedCharacterType.freeMessageLimit - count)
    }

    var showUpgradePrompt: Bool {
        selectedCharacterType.isPremium && remainingFreeMessages == 0
    }

    init(
        apiClient: APIClientProtocol = APIClient.shared,
        userRepository: UserRepositoryProtocol? = nil
    ) {
        self.apiClient = apiClient
        self.userRepository = userRepository
    }

    func sendMessage() async {
        let trimmedMessage = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            state = .error(.invalidMessage)
            return
        }

        // Check message limit for premium models
        if selectedCharacterType.isPremium {
            let count = messageCountForPremiumModels[selectedCharacterType.rawValue] ?? 0
            if count >= selectedCharacterType.freeMessageLimit {
                if let user = userRepository?.currentUser, !user.subscriptionStatus.isPremium {
                    state = .error(.messageLimitReached)
                    return
                }
            }
        }

        // Add user message immediately
        let userMessage = createMessage(content: trimmedMessage, senderType: .human)
        messages.append(userMessage)
        inputMessage = ""

        state = .loading

        do {
            let userId = userRepository?.currentUser?.id
            let sessionId = currentSession?.id

            let response: ChatResponse = try await apiClient.request(
                .chat(
                    message: trimmedMessage,
                    characterId: selectedCharacterType.rawValue,
                    userId: userId,
                    sessionId: sessionId
                )
            )

            // Create and add AI response
            let aiMessage = createMessage(
                content: response.response,
                senderType: .ai,
                metadata: MessageMetadata(
                    characterId: selectedCharacterType.rawValue,
                    model: response.model,
                    customized: response.customized,
                    characterName: response.character
                )
            )
            messages.append(aiMessage)

            // Update session
            if let sessionId = response.sessionId {
                updateSession(sessionId: sessionId)
            }

            // Increment message count for premium models
            if selectedCharacterType.isPremium {
                let count = messageCountForPremiumModels[selectedCharacterType.rawValue] ?? 0
                messageCountForPremiumModels[selectedCharacterType.rawValue] = count + 1
            }

            state = .idle
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            state = .error(.networkError(error.localizedDescription))
        }
    }

    func selectCharacter(_ type: CharacterType) {
        selectedCharacterType = type
        // Optionally clear messages when switching characters
        // messages.removeAll()
    }

    func clearChat() {
        messages.removeAll()
        currentSession = nil
        state = .idle
    }

    func retryLastMessage() async {
        guard let lastUserMessage = messages.last(where: { $0.senderType == .human }) else {
            return
        }

        // Remove the last user message and any subsequent AI messages
        if let index = messages.lastIndex(where: { $0.senderType == .human }) {
            messages.removeSubrange(index...)
        }

        inputMessage = lastUserMessage.content
        await sendMessage()
    }

    func loadConversationHistory() async {
        guard let _ = userRepository?.currentUser else { return }

        state = .loading

        do {
            let conversations: [Conversation] = try await apiClient.request(.getConversations())

            // Find the most recent conversation for the current character type
            if let conversation = conversations.first(where: { $0.modelType == selectedCharacterType.rawValue }) {
                let loadedMessages: [ChatMessage] = try await apiClient.request(
                    .getConversationMessages(id: conversation.id)
                )
                messages = loadedMessages.sorted { $0.createdAt < $1.createdAt }
            }

            state = .idle
        } catch {
            state = .idle // Silently fail for history loading
        }
    }

    // MARK: - Private Methods

    private func createMessage(
        content: String,
        senderType: SenderType,
        metadata: MessageMetadata? = nil
    ) -> ChatMessage {
        ChatMessage(
            id: UUID().uuidString,
            conversationId: currentSession?.id,
            senderType: senderType,
            content: content,
            metadata: metadata,
            createdAt: Date()
        )
    }

    private func updateSession(sessionId: String) {
        if currentSession == nil {
            currentSession = ChatSession(
                id: sessionId,
                messages: messages,
                characterType: selectedCharacterType,
                isActive: true,
                startedAt: Date(),
                lastActivityAt: Date()
            )
        } else {
            currentSession?.lastActivityAt = Date()
        }
    }

    private func handleAPIError(_ error: APIError) {
        switch error {
        case .forbidden(let message):
            if message.contains("limit") {
                state = .error(.messageLimitReached)
            } else {
                state = .error(.premiumRequired)
            }
        case .serverError:
            state = .error(.aiUnavailable)
        default:
            state = .error(.networkError(error.localizedDescription ?? "Unknown error"))
        }
    }
}

// MARK: - User Repository Protocol

protocol UserRepositoryProtocol {
    var currentUser: User? { get }
}
