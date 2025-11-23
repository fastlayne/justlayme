import Foundation
import Combine
import SwiftUI

// MARK: - Chat View Model

@MainActor
final class ChatViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var isSending: Bool = false
    @Published var errorMessage: String?

    @Published var selectedCharacter: Character?
    @Published var selectedModel: AIModel?
    @Published var characters: [Character] = []
    @Published var models: [AIModel] = AIModel.allModels

    @Published var currentSessionId: String?
    @Published var currentConversationId: String?

    @Published var freeMessagesRemaining: Int = 3
    @Published var showPaywall: Bool = false

    // MARK: - Properties

    private let apiService: APIServiceProtocol
    private let authService: AuthService
    private let webSocketService: WebSocketService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var canSendMessage: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSending
    }

    var characterName: String {
        selectedCharacter?.name ?? "Layme V1"
    }

    var isPremiumModel: Bool {
        selectedModel?.isPremium ?? false
    }

    var needsPaywall: Bool {
        guard let model = selectedModel else { return false }
        guard let user = authService.currentUser else { return model.isPremium && freeMessagesRemaining <= 0 }
        return model.isPremium && !user.isPremium && freeMessagesRemaining <= 0
    }

    // MARK: - Initialization

    init(
        apiService: APIServiceProtocol = APIService.shared,
        authService: AuthService = .shared,
        webSocketService: WebSocketService = .shared
    ) {
        self.apiService = apiService
        self.authService = authService
        self.webSocketService = webSocketService

        // Set default character and model
        selectedCharacter = Character.laymeV1
        selectedModel = AIModel.laymeV1

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Listen for WebSocket messages
        webSocketService.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleWebSocketMessage(message)
            }
            .store(in: &cancellables)

        // Listen for subscription updates
        NotificationCenter.default.publisher(for: .subscriptionDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkSubscriptionStatus()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Check paywall
        if needsPaywall {
            showPaywall = true
            return
        }

        // Clear input immediately
        inputText = ""

        // Add user message
        let userMessage = ChatMessage(
            content: text,
            isFromUser: true
        )
        messages.append(userMessage)

        // Add loading message
        let loadingMessage = ChatMessage.loadingMessage()
        messages.append(loadingMessage)

        isSending = true
        errorMessage = nil

        do {
            let request = ChatRequest(
                message: text,
                characterId: selectedCharacter.map { String($0.id) } ?? "layme_v1",
                userId: authService.currentUser.map { String($0.id) },
                conversationId: currentConversationId
            )

            let response = try await apiService.sendMessage(request)

            // Remove loading message and add AI response
            messages.removeAll { $0.isLoading }

            let aiMessage = ChatMessage(
                content: response.response,
                isFromUser: false,
                characterName: response.character,
                model: response.model
            )
            messages.append(aiMessage)

            // Update session
            currentSessionId = response.sessionId

            // Decrement free messages if premium model
            if isPremiumModel && !(authService.currentUser?.isPremium ?? false) {
                freeMessagesRemaining = max(0, freeMessagesRemaining - 1)
            }

        } catch {
            // Remove loading message
            messages.removeAll { $0.isLoading }

            errorMessage = error.localizedDescription

            // Add error message
            let errorChatMessage = ChatMessage(
                content: "Sorry, something went wrong. Please try again.",
                isFromUser: false
            )
            messages.append(errorChatMessage)
        }

        isSending = false
    }

    func loadCharacters() async {
        isLoading = true

        do {
            let loadedCharacters = try await apiService.getCharacters()
            characters = Character.presetCharacters + loadedCharacters
        } catch {
            // Use preset characters if API fails
            characters = Character.presetCharacters
        }

        isLoading = false
    }

    func loadModels() async {
        do {
            let loadedModels = try await apiService.getModels()
            if !loadedModels.isEmpty {
                models = loadedModels
            }
        } catch {
            // Use preset models if API fails
            models = AIModel.allModels
        }
    }

    func selectCharacter(_ character: Character) {
        selectedCharacter = character

        // Map character to appropriate model
        switch character.id {
        case 1:
            selectedModel = .laymeV1
        case 2:
            selectedModel = .laymeUncensored
        case 3:
            selectedModel = .mythomaxRoleplay
        case 4:
            selectedModel = .fastLayme
        default:
            selectedModel = .laymeV1
        }
    }

    func selectModel(_ model: AIModel) {
        selectedModel = model
    }

    func clearChat() {
        messages.removeAll()
        currentSessionId = nil
        currentConversationId = nil
    }

    func startNewConversation() {
        clearChat()
        currentConversationId = UUID().uuidString
    }

    func provideFeedback(messageId: String, isPositive: Bool) {
        // TODO: Implement feedback API call
        print("Feedback for message \(messageId): \(isPositive ? "positive" : "negative")")
    }

    // MARK: - Private Methods

    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message.type {
        case .newMessage:
            // Handle incoming message if it's for our session
            if message.sessionId == currentSessionId,
               let content = message.message,
               message.isUser == false {

                messages.removeAll { $0.isLoading }

                let aiMessage = ChatMessage(
                    content: content,
                    isFromUser: false
                )
                messages.append(aiMessage)
            }

        case .typingIndicator:
            // Handle typing indicator
            break

        default:
            break
        }
    }

    private func checkSubscriptionStatus() {
        if let user = authService.currentUser, user.isPremium {
            freeMessagesRemaining = -1 // Unlimited
        }
    }
}

// MARK: - Message Input Helper

extension ChatViewModel {
    var inputPlaceholder: String {
        if isSending {
            return "Waiting for response..."
        } else if needsPaywall {
            return "Subscribe to continue..."
        } else {
            return "Message \(characterName)..."
        }
    }
}
