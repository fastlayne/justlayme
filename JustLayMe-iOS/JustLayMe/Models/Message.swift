import Foundation

struct Message: Identifiable, Codable, Equatable {
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

    var isUser: Bool {
        senderType == .user
    }

    static func userMessage(_ content: String) -> Message {
        Message(
            id: UUID().uuidString,
            conversationId: nil,
            senderType: .user,
            content: content,
            metadata: nil,
            createdAt: Date()
        )
    }

    static func aiMessage(_ content: String, characterId: String) -> Message {
        Message(
            id: UUID().uuidString,
            conversationId: nil,
            senderType: .ai,
            content: content,
            metadata: MessageMetadata(characterId: characterId, model: nil),
            createdAt: Date()
        )
    }
}

enum SenderType: String, Codable {
    case user = "human"
    case ai = "ai"
}

struct MessageMetadata: Codable, Equatable {
    let characterId: String?
    let model: String?

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case model
    }
}

struct Conversation: Identifiable, Codable {
    let id: String
    let userId: String
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

struct ChatRequest: Codable {
    let message: String
    let characterId: String
    let userId: String

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
    let sessionId: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case response, character, model, customized
        case sessionId = "sessionId"
        case error
    }
}
