import Foundation
import Combine

// MARK: - Chat Repository Protocol

protocol ChatRepositoryProtocol {
    var conversations: [Conversation] { get }
    var currentConversation: Conversation? { get }

    func loadConversations() async throws -> [Conversation]
    func loadMessages(for conversationId: String) async throws -> [ChatMessage]
    func searchConversations(query: String) async throws -> [Conversation]
    func archiveConversation(id: String) async throws
    func deleteConversation(id: String) async throws
    func exportConversation(id: String) async throws -> ExportedConversation
}

// MARK: - Chat Repository

class ChatRepository: ChatRepositoryProtocol, ObservableObject {
    static let shared = ChatRepository()

    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var currentConversation: Conversation?
    @Published private(set) var cachedMessages: [String: [ChatMessage]] = [:]

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    func loadConversations() async throws -> [Conversation] {
        let loadedConversations: [Conversation] = try await apiClient.request(.getConversations())
        await MainActor.run {
            self.conversations = loadedConversations
        }
        return loadedConversations
    }

    func loadMessages(for conversationId: String) async throws -> [ChatMessage] {
        let messages: [ChatMessage] = try await apiClient.request(
            .getConversationMessages(id: conversationId)
        )
        await MainActor.run {
            self.cachedMessages[conversationId] = messages
        }
        return messages
    }

    func searchConversations(query: String) async throws -> [Conversation] {
        return try await apiClient.request(.searchConversations(query: query))
    }

    func archiveConversation(id: String) async throws {
        try await apiClient.requestVoid(.archiveConversation(id: id))
        await MainActor.run {
            if let index = self.conversations.firstIndex(where: { $0.id == id }) {
                self.conversations[index].isArchived = true
            }
        }
    }

    func deleteConversation(id: String) async throws {
        try await apiClient.requestVoid(.deleteConversation(id: id))
        await MainActor.run {
            self.conversations.removeAll { $0.id == id }
            self.cachedMessages.removeValue(forKey: id)
        }
    }

    func exportConversation(id: String) async throws -> ExportedConversation {
        return try await apiClient.request(.exportConversation(id: id))
    }

    func setCurrentConversation(_ conversation: Conversation?) {
        currentConversation = conversation
    }

    func clearCache() {
        cachedMessages.removeAll()
    }
}

// MARK: - Exported Conversation

struct ExportedConversation: Codable, Equatable {
    let conversation: Conversation
    let messages: [ChatMessage]
    let exportedAt: Date

    enum CodingKeys: String, CodingKey {
        case conversation, messages
        case exportedAt = "exported_at"
    }
}
