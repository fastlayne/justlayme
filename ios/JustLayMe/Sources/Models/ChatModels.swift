// ChatModels.swift
// JustLayMe iOS - Chat Data Models
// Matches web implementation at justlay.me

import Foundation

// MARK: - AI Models (matching web implementation)

enum AIModel: String, CaseIterable, Codable, Identifiable {
    case laymeV1 = "layme_v1"
    case uncensoredGPT = "uncensored_gpt"
    case roleplay = "roleplay"
    case companion = "companion"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .laymeV1: return "Layme V1"
        case .uncensoredGPT: return "LayMe Uncensored"
        case .roleplay: return "Mythomax Roleplay"
        case .companion: return "FastLayMe"
        }
    }

    var description: String {
        switch self {
        case .laymeV1: return "FREE & Unlimited - No Paywall"
        case .uncensoredGPT: return "No Limits - Dolphin 46.7B"
        case .roleplay: return "Dark & Seductive - 13B"
        case .companion: return "Fast & Light - Zephyr 7B"
        }
    }

    var emoji: String {
        switch self {
        case .laymeV1: return "free"
        case .uncensoredGPT: return "L"
        case .roleplay: return "M"
        case .companion: return "F"
        }
    }

    var isPremium: Bool {
        self != .laymeV1
    }

    var gradientColors: (String, String) {
        switch self {
        case .laymeV1: return ("#10b981", "#059669")
        case .uncensoredGPT: return ("#667eea", "#764ba2")
        case .roleplay: return ("#f093fb", "#f5576c")
        case .companion: return ("#4facfe", "#00f2fe")
        }
    }

    var freeMessageLimit: Int {
        isPremium ? 3 : Int.max
    }
}

// MARK: - Message Model

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let content: String
    let isUser: Bool
    let timestamp: Date
    let modelType: String?
    var isStreaming: Bool

    init(
        id: String = UUID().uuidString,
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        modelType: String? = nil,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.modelType = modelType
        self.isStreaming = isStreaming
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Conversation Model

struct Conversation: Identifiable, Codable {
    let id: String
    let modelType: AIModel
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var tags: [String]

    init(
        id: String = UUID().uuidString,
        modelType: AIModel,
        title: String? = nil,
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.modelType = modelType
        self.title = title ?? "\(modelType.displayName) - \(Self.formatDate(createdAt))"
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.tags = tags
    }

    var lastMessage: ChatMessage? {
        messages.last
    }

    var messageCount: Int {
        messages.count
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = Date()

        // Update title based on first user message
        if messages.count == 1 && message.isUser {
            let preview = String(message.content.prefix(50))
            title = message.content.count > 50 ? "\(preview)..." : preview
        }
    }
}

// MARK: - User Model

struct User: Codable {
    let id: String
    let email: String
    var name: String?
    let subscriptionStatus: SubscriptionStatus
    let emailVerified: Bool

    enum SubscriptionStatus: String, Codable {
        case free = "free"
        case premium = "premium"
    }

    var isPremium: Bool {
        subscriptionStatus == .premium
    }
}

// MARK: - API Response Models

struct ChatResponse: Codable {
    let response: String
    let character: String
    let model: String
    let customized: Bool?
    let modelInfo: ModelInfo?
    let sessionId: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case response, character, model, customized, error
        case modelInfo = "model_info"
        case sessionId = "sessionId"
    }
}

struct ModelInfo: Codable {
    let name: String
    let size: Int?
    let capabilities: ModelCapabilities?
    let recommendedFor: [String]?

    enum CodingKeys: String, CodingKey {
        case name, size, capabilities
        case recommendedFor = "recommended_for"
    }
}

struct ModelCapabilities: Codable {
    let strengths: [String]?
    let bestFor: [String]?
    let memoryUsage: String?
    let speed: String?

    enum CodingKeys: String, CodingKey {
        case strengths
        case bestFor = "best_for"
        case memoryUsage = "memory_usage"
        case speed
    }
}

struct LoginResponse: Codable {
    let token: String
    let user: User
}

struct ModelsResponse: Codable {
    let models: [AvailableModel]
    let defaultModel: String?
    let totalModels: Int?

    enum CodingKeys: String, CodingKey {
        case models
        case defaultModel = "default_model"
        case totalModels = "total_models"
    }
}

struct AvailableModel: Codable, Identifiable {
    let name: String
    let size: Int?
    let modified: String?
    let capabilities: ModelCapabilities?

    var id: String { name }
}

struct ConversationsResponse: Codable {
    let conversations: [ServerConversation]
    let pagination: Pagination?
}

struct ServerConversation: Codable, Identifiable {
    let id: String
    let userId: String?
    let modelType: String
    var title: String?
    var messageCount: Int?
    var isArchived: Bool?
    var tags: [String]?
    let createdAt: String?
    var updatedAt: String?
    let lastMessagePreview: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case modelType = "model_type"
        case title
        case messageCount = "message_count"
        case isArchived = "is_archived"
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastMessagePreview = "last_message_preview"
    }
}

struct Pagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page, limit, total
        case totalPages = "totalPages"
    }
}

struct MessagesResponse: Codable {
    let messages: [ServerMessage]
}

struct ServerMessage: Codable, Identifiable {
    let id: String
    let conversationId: String?
    let senderType: String
    let content: String
    let metadata: MessageMetadata?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderType = "sender_type"
        case content
        case metadata
        case createdAt = "created_at"
    }

    var isUser: Bool {
        senderType == "human"
    }
}

struct MessageMetadata: Codable {
    let characterId: String?
    let model: String?
    let characterName: String?

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case model
        case characterName = "character_name"
    }
}

// MARK: - Settings Model

struct AppSettings: Codable {
    var defaultModel: AIModel
    var responseLength: ResponseLength
    var autoScroll: Bool
    var soundNotifications: Bool
    var saveConversations: Bool
    var analyticsOptOut: Bool
    var serverURL: String
    var temperature: Double
    var topP: Double
    var maxTokens: Int
    var systemPrompt: String?

    enum ResponseLength: String, Codable, CaseIterable {
        case short = "short"
        case medium = "medium"
        case long = "long"

        var maxTokens: Int {
            switch self {
            case .short: return 200
            case .medium: return 500
            case .long: return 1000
            }
        }
    }

    static var `default`: AppSettings {
        AppSettings(
            defaultModel: .laymeV1,
            responseLength: .medium,
            autoScroll: true,
            soundNotifications: false,
            saveConversations: true,
            analyticsOptOut: false,
            serverURL: "https://justlay.me",
            temperature: 0.8,
            topP: 0.9,
            maxTokens: 500,
            systemPrompt: nil
        )
    }
}

// MARK: - Connection Status

enum ConnectionStatus: Equatable {
    case connected
    case connecting
    case disconnected
    case error(String)

    var statusText: String {
        switch self {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        case .error(let message): return "Error: \(message)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
