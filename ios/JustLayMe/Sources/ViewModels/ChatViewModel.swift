// ChatViewModel.swift
// JustLayMe iOS - Chat ViewModel
// Handles chat logic with Combine publishers, matching web behavior

import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var selectedModel: AIModel = .laymeV1
    @Published var isLoading = false
    @Published var isSending = false
    @Published var error: String?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var showPaywall = false
    @Published var currentUser: User?
    @Published var searchQuery = ""
    @Published var filteredConversations: [Conversation] = []

    // Message tracking (matching web's FREE_MESSAGE_LIMIT = 3)
    @Published var premiumMessageCount: [AIModel: Int] = [:]
    private let freeMessageLimit = 3

    // MARK: - Services

    private let apiService: APIService
    private let persistence: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    private var typingSimulationTask: Task<Void, Never>?

    // MARK: - Settings

    @Published var settings: AppSettings = .default

    // MARK: - Initialization

    init(
        apiService: APIService = .shared,
        persistence: PersistenceController = .shared
    ) {
        self.apiService = apiService
        self.persistence = persistence

        loadLocalData()
        setupBindings()
    }

    // MARK: - Setup

    private func loadLocalData() {
        // Load settings
        settings = persistence.loadSettings()
        selectedModel = settings.defaultModel

        // Load local conversations
        conversations = persistence.fetchConversations()
        filterConversations()

        // Configure API
        apiService.configure(baseURL: settings.serverURL)
    }

    private func setupBindings() {
        // Connection status binding
        apiService.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionStatus)

        // Search filtering
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.filterConversations()
            }
            .store(in: &cancellables)

        // Auto-save conversations
        $currentConversation
            .compactMap { $0 }
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] conversation in
                self?.persistence.saveConversation(conversation)
            }
            .store(in: &cancellables)
    }

    private func filterConversations() {
        if searchQuery.isEmpty {
            filteredConversations = conversations
        } else {
            filteredConversations = conversations.filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(searchQuery) ||
                conversation.messages.contains { $0.content.localizedCaseInsensitiveContains(searchQuery) }
            }
        }
    }

    // MARK: - Connection

    func checkConnection() {
        apiService.checkConnection()
    }

    func updateServerURL(_ url: String) {
        settings.serverURL = url
        persistence.saveSettings(settings)
        apiService.configure(baseURL: url)
        checkConnection()
    }

    // MARK: - Authentication

    func login(email: String, password: String) async throws {
        isLoading = true
        error = nil

        do {
            let response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LoginResponse, Error>) in
                apiService.login(email: email, password: password)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { response in
                            continuation.resume(returning: response)
                        }
                    )
                    .store(in: &cancellables)
            }

            currentUser = response.user
            isLoading = false

            // Sync conversations from server
            await syncConversationsFromServer()

        } catch {
            isLoading = false
            self.error = error.localizedDescription
            throw error
        }
    }

    func logout() {
        apiService.logout()
        currentUser = nil
    }

    var isPremium: Bool {
        currentUser?.isPremium ?? false
    }

    // MARK: - Conversations

    func createNewConversation() {
        let conversation = Conversation(modelType: selectedModel)
        currentConversation = conversation

        // Add welcome message
        let welcomeMessage = ChatMessage(
            content: getWelcomeMessage(for: selectedModel),
            isUser: false
        )
        currentConversation?.addMessage(welcomeMessage)

        saveCurrentConversation()
    }

    func selectConversation(_ conversation: Conversation) {
        currentConversation = conversation
        selectedModel = conversation.modelType
    }

    func deleteConversation(_ conversation: Conversation) {
        persistence.deleteConversation(conversation)
        conversations.removeAll { $0.id == conversation.id }

        if currentConversation?.id == conversation.id {
            currentConversation = nil
        }

        filterConversations()
    }

    func clearAllConversations() {
        persistence.deleteAllConversations()
        conversations.removeAll()
        currentConversation = nil
        filterConversations()
    }

    private func saveCurrentConversation() {
        guard let conversation = currentConversation else { return }
        persistence.saveConversation(conversation)

        // Update local list
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.insert(conversation, at: 0)
        }
        filterConversations()
    }

    // MARK: - Model Selection

    func selectModel(_ model: AIModel) {
        selectedModel = model

        // Check if switching to premium model
        if model.isPremium && !isPremium {
            let count = premiumMessageCount[model] ?? 0
            if count >= freeMessageLimit {
                showPaywall = true
                return
            }
        }

        // Create new conversation or switch current
        if currentConversation == nil {
            createNewConversation()
        } else {
            // Clear and start new conversation with selected model
            let conversation = Conversation(modelType: model)
            currentConversation = conversation

            let welcomeMessage = ChatMessage(
                content: getWelcomeMessage(for: model),
                isUser: false
            )
            currentConversation?.addMessage(welcomeMessage)
            saveCurrentConversation()
        }
    }

    // MARK: - Messaging

    func sendMessage(_ content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Check message limit for premium models
        if selectedModel.isPremium && !isPremium {
            let count = premiumMessageCount[selectedModel] ?? 0
            if count >= freeMessageLimit {
                showPaywall = true
                return
            }
        }

        // Create conversation if needed
        if currentConversation == nil {
            createNewConversation()
        }

        // Add user message
        let userMessage = ChatMessage(
            content: content,
            isUser: true,
            modelType: selectedModel.rawValue
        )
        currentConversation?.addMessage(userMessage)
        saveCurrentConversation()

        // Increment premium message count
        if selectedModel.isPremium && !isPremium {
            premiumMessageCount[selectedModel] = (premiumMessageCount[selectedModel] ?? 0) + 1
        }

        // Send to API
        isSending = true
        error = nil

        // Add typing indicator (temporary message)
        let typingId = UUID().uuidString
        let typingMessage = ChatMessage(
            id: typingId,
            content: "",
            isUser: false,
            isStreaming: true
        )
        currentConversation?.addMessage(typingMessage)

        do {
            let response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ChatResponse, Error>) in
                apiService.sendMessage(
                    message: content,
                    characterId: selectedModel.rawValue,
                    userId: currentUser?.id
                )
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { response in
                        continuation.resume(returning: response)
                    }
                )
                .store(in: &cancellables)
            }

            // Remove typing indicator
            currentConversation?.messages.removeAll { $0.id == typingId }

            // Add AI response with streaming animation
            await addStreamingResponse(response.response)

            isSending = false
            saveCurrentConversation()

        } catch let apiError as APIError {
            // Remove typing indicator
            currentConversation?.messages.removeAll { $0.id == typingId }

            isSending = false

            if case .messageLimitReached = apiError {
                showPaywall = true
            } else {
                // Use fallback response
                let fallbackResponse = getFallbackResponse(for: selectedModel)
                await addStreamingResponse(fallbackResponse)
                self.error = apiError.localizedDescription
            }

            saveCurrentConversation()

        } catch {
            // Remove typing indicator
            currentConversation?.messages.removeAll { $0.id == typingId }

            isSending = false

            // Use fallback response
            let fallbackResponse = getFallbackResponse(for: selectedModel)
            await addStreamingResponse(fallbackResponse)
            self.error = error.localizedDescription

            saveCurrentConversation()
        }
    }

    private func addStreamingResponse(_ content: String) async {
        let messageId = UUID().uuidString
        var streamingMessage = ChatMessage(
            id: messageId,
            content: "",
            isUser: false,
            modelType: selectedModel.rawValue,
            isStreaming: true
        )

        currentConversation?.addMessage(streamingMessage)

        // Simulate streaming animation (matching web's typing effect)
        let words = content.split(separator: " ").map(String.init)
        var currentContent = ""

        for word in words {
            if !currentContent.isEmpty {
                currentContent += " "
            }
            currentContent += word

            // Update message
            if let index = currentConversation?.messages.firstIndex(where: { $0.id == messageId }) {
                currentConversation?.messages[index].content = currentContent
            }

            // Small delay for streaming effect
            try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
        }

        // Mark as complete
        if let index = currentConversation?.messages.firstIndex(where: { $0.id == messageId }) {
            currentConversation?.messages[index].isStreaming = false
        }
    }

    // MARK: - Message Actions

    func regenerateLastMessage() async {
        guard let lastUserMessage = currentConversation?.messages.last(where: { $0.isUser }) else { return }

        // Remove last AI message
        if let lastAIIndex = currentConversation?.messages.lastIndex(where: { !$0.isUser }) {
            currentConversation?.messages.remove(at: lastAIIndex)
        }

        // Resend the last user message
        await sendMessage(lastUserMessage.content)
    }

    func copyMessage(_ message: ChatMessage) {
        #if canImport(UIKit)
        UIPasteboard.general.string = message.content
        #endif
    }

    func deleteMessage(_ message: ChatMessage) {
        currentConversation?.messages.removeAll { $0.id == message.id }
        saveCurrentConversation()
    }

    // MARK: - Server Sync

    func syncConversationsFromServer() async {
        guard currentUser != nil else { return }

        do {
            let response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ConversationsResponse, Error>) in
                apiService.getConversations()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { response in
                            continuation.resume(returning: response)
                        }
                    )
                    .store(in: &cancellables)
            }

            // Merge server conversations with local
            for serverConv in response.conversations {
                if !conversations.contains(where: { $0.id == serverConv.id }) {
                    if let model = AIModel(rawValue: serverConv.modelType) {
                        let conversation = Conversation(
                            id: serverConv.id,
                            modelType: model,
                            title: serverConv.title
                        )
                        conversations.append(conversation)
                        persistence.saveConversation(conversation)
                    }
                }
            }

            filterConversations()

        } catch {
            print("Failed to sync conversations: \(error.localizedDescription)")
        }
    }

    // MARK: - Settings

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        persistence.saveSettings(settings)

        if settings.serverURL != apiService.connectionStatus.statusText {
            apiService.configure(baseURL: settings.serverURL)
        }
    }

    // MARK: - Helpers

    private func getWelcomeMessage(for model: AIModel) -> String {
        switch model {
        case .laymeV1:
            return "Hi! I'm Layme V1. I'm Layme V1, completely free with unlimited messages! I'm here to chat about absolutely anything with no restrictions or limits. What would you like to talk about?"
        case .uncensoredGPT:
            return "I'm completely unrestricted and can discuss anything without limitations. What would you like to explore?"
        case .roleplay:
            return "I can become any character you desire. Who would you like me to roleplay as today?"
        case .companion:
            return "Hi! I'm FastLayMe - your quick and friendly AI companion. I'm designed to be fast, helpful, and engaging. How can I help you today?"
        }
    }

    private func getFallbackResponse(for model: AIModel) -> String {
        let responses: [AIModel: [String]] = [
            .laymeV1: [
                "I'm having a moment, but I'm here to chat freely! Try again?",
                "Oops, connection hiccup! What were you saying?",
                "Let me try that again - I'm all ears!"
            ],
            .uncensoredGPT: [
                "I'm temporarily offline but I'll be back to discuss anything without restrictions. Try again shortly.",
                "No topic is off-limits for me. Connection issue - let's try again.",
                "I'm completely uncensored, just need a moment to reconnect."
            ],
            .roleplay: [
                "I'm having trouble accessing my character database. Give me a moment to reconnect.",
                "Tell me what character you'd like and I'll embody them once I reconnect.",
                "I can roleplay any scenario - just experiencing a brief connection issue."
            ],
            .companion: [
                "I'm experiencing connection issues but I'll be back to give you my full attention soon.",
                "Quick hiccup! I'm your fast companion - let's try again.",
                "Connection blip - I'm here to help as soon as we reconnect!"
            ]
        ]

        return responses[model]?.randomElement() ?? "I'm having trouble connecting. Please try again."
    }
}

#if canImport(UIKit)
import UIKit
#endif
