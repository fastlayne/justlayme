import Foundation
import Combine

// MARK: - Chat ViewModel
@MainActor
final class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [Message] = []
    @Published var inputText = ""
    @Published var isTyping = false
    @Published var selectedCharacter: PredefinedCharacter = .laymeV1
    @Published var customCharacter: AICharacter?

    @Published var messageCount = 0
    @Published var showPaywall = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Services
    private let chatService = ChatService.shared
    private let settingsManager = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var currentCharacterId: String {
        customCharacter?.id ?? selectedCharacter.rawValue
    }

    var currentCharacterName: String {
        customCharacter?.name ?? selectedCharacter.displayName
    }

    var isFreeTier: Bool {
        selectedCharacter == .laymeV1
    }

    var remainingFreeMessages: Int {
        max(0, AppConfig.freeMessageLimit - messageCount)
    }

    var canSendMessage: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }

    // MARK: - Initialization
    init() {
        loadLastSelectedCharacter()
    }

    // MARK: - Character Selection
    func selectCharacter(_ character: PredefinedCharacter, isPremium: Bool) {
        // Check if premium character requires subscription
        if character.isPremium && !isPremium && messageCount >= AppConfig.freeMessageLimit {
            showPaywall = true
            return
        }

        selectedCharacter = character
        customCharacter = nil
        settingsManager.lastSelectedCharacter = character.rawValue

        // Clear messages when switching characters
        messages = []
    }

    func selectCustomCharacter(_ character: AICharacter) {
        customCharacter = character
        settingsManager.lastSelectedCharacter = character.id
        messages = []
    }

    // MARK: - Send Message
    func sendMessage(userId: String?, isPremium: Bool) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Check message limits for premium models
        if selectedCharacter.isPremium && !isPremium && messageCount >= AppConfig.freeMessageLimit {
            showPaywall = true
            return
        }

        // Add user message
        let userMessage = Message(
            id: UUID().uuidString,
            conversationId: nil,
            senderType: .human,
            content: text,
            metadata: nil,
            createdAt: Date()
        )
        messages.append(userMessage)
        inputText = ""

        // Add typing indicator
        var typingMessage = Message(
            id: "typing",
            conversationId: nil,
            senderType: .ai,
            content: "",
            metadata: nil,
            createdAt: Date(),
            isLoading: true
        )
        messages.append(typingMessage)
        isTyping = true

        do {
            let response = try await chatService.sendMessage(
                message: text,
                characterId: currentCharacterId,
                userId: userId
            )

            // Remove typing indicator
            messages.removeAll { $0.id == "typing" }
            isTyping = false

            // Add AI response
            let aiMessage = Message(
                id: UUID().uuidString,
                conversationId: nil,
                senderType: .ai,
                content: response.response,
                metadata: MessageMetadata(
                    model: response.model,
                    characterId: response.character,
                    responseTime: nil
                ),
                createdAt: Date()
            )
            messages.append(aiMessage)

            // Update session ID if provided
            if let sessionId = response.sessionId {
                SessionManager.shared.sessionId = sessionId
            }

            // Increment message count for premium models
            if selectedCharacter.isPremium {
                messageCount += 1
            }

        } catch {
            // Remove typing indicator
            messages.removeAll { $0.id == "typing" }
            isTyping = false

            // Show error
            showError(message: "Failed to send message: \(error.localizedDescription)")
        }
    }

    // MARK: - Clear Chat
    func clearChat() {
        messages = []
    }

    // MARK: - Helpers
    private func loadLastSelectedCharacter() {
        if let lastCharacter = settingsManager.lastSelectedCharacter,
           let predefined = PredefinedCharacter(rawValue: lastCharacter) {
            selectedCharacter = predefined
        } else {
            selectedCharacter = .laymeV1
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func dismissError() {
        showError = false
        errorMessage = nil
    }
}

// MARK: - Character List ViewModel
@MainActor
final class CharacterListViewModel: ObservableObject {
    @Published var customCharacters: [AICharacter] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let characterService = CharacterService.shared

    let predefinedCharacters = PredefinedCharacter.allCases

    func loadCharacters() async {
        isLoading = true

        do {
            customCharacters = try await characterService.getCharacters()
        } catch {
            errorMessage = "Failed to load characters"
        }

        isLoading = false
    }

    func createCharacter(name: String, backstory: String?, traits: [String]?) async throws -> AICharacter {
        let request = CreateCharacterRequest(
            name: name,
            backstory: backstory,
            personalityTraits: traits,
            speechPatterns: nil
        )
        let character = try await characterService.createCharacter(request)
        customCharacters.append(character)
        return character
    }
}
