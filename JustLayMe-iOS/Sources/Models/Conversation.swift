import Foundation

// MARK: - Conversation Model
struct Conversation: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    var modelType: String
    var title: String?
    var messageCount: Int
    var isArchived: Bool
    var tags: [String]?
    var createdAt: Date?
    var updatedAt: Date?

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
    }

    var displayTitle: String {
        title ?? "Conversation"
    }

    var lastActivityFormatted: String {
        guard let date = updatedAt ?? createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Message Model
struct Message: Codable, Identifiable, Equatable {
    let id: String
    let conversationId: String?
    let senderType: SenderType
    var content: String
    var metadata: MessageMetadata?
    var createdAt: Date?

    // Local-only properties
    var isLoading: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderType = "sender_type"
        case content, metadata
        case createdAt = "created_at"
    }

    var isUser: Bool {
        senderType == .human
    }

    var isAI: Bool {
        senderType == .ai
    }
}

enum SenderType: String, Codable {
    case human
    case ai
}

struct MessageMetadata: Codable, Equatable {
    var model: String?
    var characterId: String?
    var responseTime: Double?

    enum CodingKeys: String, CodingKey {
        case model
        case characterId = "character_id"
        case responseTime = "response_time"
    }
}

// MARK: - Chat API Models
struct ChatRequest: Codable {
    let message: String
    let characterId: String
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case message
        case characterId = "character_id"
        case userId = "user_id"
    }
}

struct ChatResponse: Codable {
    let response: String
    let character: String?
    let model: String?
    let customized: Bool?
    let modelInfo: ModelInfo?
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case response, character, model, customized
        case modelInfo = "model_info"
        case sessionId
    }
}

struct ModelInfo: Codable {
    let name: String?
    let displayName: String?
    let isPremium: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case isPremium = "is_premium"
    }
}

// MARK: - Conversation History API
struct ConversationsResponse: Codable {
    let conversations: [Conversation]
    let page: Int?
    let limit: Int?
    let total: Int?
}

struct MessagesResponse: Codable {
    let messages: [Message]
}

// MARK: - Export Data
struct ExportedData: Codable {
    let user: User?
    let conversations: [Conversation]
    let characters: [AICharacter]
    let exportedAt: Date

    enum CodingKeys: String, CodingKey {
        case user, conversations, characters
        case exportedAt = "exported_at"
    }
}
