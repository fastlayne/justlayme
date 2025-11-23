import Foundation

// MARK: - Chat Models

struct ChatMessage: Codable, Equatable, Identifiable {
    let id: String
    let conversationId: String?
    let senderType: SenderType
    let content: String
    let metadata: MessageMetadata?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderType = "sender_type"
        case content, metadata
        case createdAt = "created_at"
    }
}

enum SenderType: String, Codable, Equatable {
    case human
    case ai
}

struct MessageMetadata: Codable, Equatable {
    let characterId: String?
    let model: String?
    let customized: Bool?
    let characterName: String?

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case model, customized
        case characterName = "character_name"
    }
}

struct Conversation: Codable, Equatable, Identifiable {
    let id: String
    let userId: String?
    let modelType: String
    var title: String?
    var messageCount: Int
    var isArchived: Bool
    var tags: [String]?
    let createdAt: Date
    var updatedAt: Date

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
}

struct ChatRequest: Codable, Equatable {
    let message: String
    let characterId: String
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case message
        case characterId = "character_id"
        case userId = "user_id"
    }
}

struct ChatResponse: Codable, Equatable {
    let response: String
    let character: String
    let model: String
    let customized: Bool?
    let modelInfo: ModelInfo?
    let sessionId: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case response, character, model, customized
        case modelInfo = "model_info"
        case sessionId = "sessionId"
        case error
    }
}

struct ModelInfo: Codable, Equatable {
    let name: String
    let size: Int?
    let capabilities: ModelCapabilities?
    let recommendedFor: [String]?

    enum CodingKeys: String, CodingKey {
        case name, size, capabilities
        case recommendedFor = "recommended_for"
    }
}

struct ModelCapabilities: Codable, Equatable {
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

struct ChatSession {
    let id: String
    var messages: [ChatMessage]
    var characterType: CharacterType
    var isActive: Bool
    var startedAt: Date
    var lastActivityAt: Date

    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        lastActivityAt = Date()
    }

    var messageCountForType: Int {
        messages.filter { $0.senderType == .human }.count
    }
}
