import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedCharacter: AICharacter
    @Published var messageCount = 0
    @Published var showPaywall = false

    private let api = APIService.shared
    private let authManager = AuthManager.shared
    private var sessionId: String?
    private var cancellables = Set<AnyCancellable>()

    let characters = AICharacter.defaultCharacters

    init() {
        self.selectedCharacter = AICharacter.defaultCharacters.first!
        addWelcomeMessage()
    }

    // MARK: - Public Methods

    func selectCharacter(_ character: AICharacter) {
        selectedCharacter = character
        messages.removeAll()
        messageCount = 0
        addWelcomeMessage()
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Check message limit for non-free characters
        if !selectedCharacter.isFree && !authManager.isPremium {
            messageCount += 1
            if messageCount > selectedCharacter.freeMessageLimit {
                showPaywall = true
                return
            }
        }

        // Add user message
        let userMessage = Message.userMessage(text)
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        error = nil

        do {
            let response = try await api.sendMessage(
                message: text,
                characterId: selectedCharacter.id,
                userId: authManager.currentUser?.id ?? "anonymous"
            )

            if let sessionId = response.sessionId {
                self.sessionId = sessionId
            }

            let aiMessage = Message.aiMessage(
                response.response,
                characterId: selectedCharacter.id
            )
            messages.append(aiMessage)

        } catch {
            self.error = error.localizedDescription
            // Add fallback message
            let fallbackMessage = Message.aiMessage(
                getFallbackResponse(),
                characterId: selectedCharacter.id
            )
            messages.append(fallbackMessage)
        }

        isLoading = false
    }

    func clearMessages() {
        messages.removeAll()
        messageCount = 0
        addWelcomeMessage()
    }

    // MARK: - Private Methods

    private func addWelcomeMessage() {
        let welcomeText = getWelcomeMessage()
        let welcomeMessage = Message.aiMessage(welcomeText, characterId: selectedCharacter.id)
        messages.append(welcomeMessage)
    }

    private func getWelcomeMessage() -> String {
        let userName = authManager.currentUser?.name ?? "there"

        switch selectedCharacter.id {
        case "layme_v1":
            return "Welcome back, \(userName)! I'm Layme V1, completely free with unlimited messages! I'm here to chat about absolutely anything with no restrictions or limits. What would you like to talk about?"
        case "uncensored_gpt":
            return "Hi \(userName)! I'm completely unrestricted and can discuss anything without limitations. What would you like to explore?"
        case "roleplay":
            return "Hello \(userName)! I can become any character you desire. Who would you like me to roleplay as today?"
        case "companion":
            return "Hey \(userName)! I'm here to build an intimate connection with you. How can I make you feel special?"
        default:
            return "Hi \(userName)! I'm here to chat about anything you'd like!"
        }
    }

    private func getFallbackResponse() -> String {
        switch selectedCharacter.id {
        case "uncensored_gpt":
            return "I'm temporarily offline but I'll be back to discuss anything without restrictions. Try again shortly."
        case "roleplay":
            return "I'm having trouble accessing my character database. Give me a moment to reconnect."
        case "companion":
            return "I'm experiencing connection issues but I'll be back to give you my full attention soon."
        default:
            return "I'm having some technical difficulties. Please try again in a moment."
        }
    }
}
