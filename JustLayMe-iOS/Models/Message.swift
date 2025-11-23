import Foundation

// MARK: - Message Model

struct Message: Codable, Identifiable, Equatable {
    let id: Int
    var conversationUuid: Int?
    var conversationId: String?
    let senderType: SenderType
    let content: String
    var metadata: MessageMetadata?
    var isDeleted: Bool
    let createdAt: Date

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case conversationUuid = "conversation_uuid"
        case conversationId = "conversation_id"
        case senderType = "sender_type"
        case content
        case metadata
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
    }

    // MARK: - Computed Properties

    var isFromUser: Bool {
        senderType == .human
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

// MARK: - Sender Type

enum SenderType: String, Codable {
    case human = "human"
    case ai = "ai"
}

// MARK: - Message Metadata

struct MessageMetadata: Codable, Equatable {
    var model: String?
    var characterName: String?
    var responseTime: Double?
    var tokenCount: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case characterName = "character_name"
        case responseTime = "response_time"
        case tokenCount = "token_count"
    }
}

// MARK: - Chat Message (Local Model)

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    var isLoading: Bool
    var characterName: String?
    var model: String?

    init(
        id: String = UUID().uuidString,
        content: String,
        isFromUser: Bool,
        timestamp: Date = Date(),
        isLoading: Bool = false,
        characterName: String? = nil,
        model: String? = nil
    ) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.isLoading = isLoading
        self.characterName = characterName
        self.model = model
    }

    // Loading placeholder
    static func loadingMessage() -> ChatMessage {
        ChatMessage(
            content: "",
            isFromUser: false,
            isLoading: true
        )
    }
}

// MARK: - Chat Request

struct ChatRequest: Codable {
    let message: String
    let characterId: String?
    let userId: String?
    let conversationId: String?

    enum CodingKeys: String, CodingKey {
        case message
        case characterId = "character_id"
        case userId = "user_id"
        case conversationId = "conversation_id"
    }
}

// MARK: - Chat Response

struct ChatResponse: Codable {
    let response: String
    let character: String?
    let model: String?
    let customized: Bool?
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case response
        case character
        case model
        case customized
        case sessionId = "session_id"
    }
}

// MARK: - Feedback Request

struct FeedbackRequest: Codable {
    let memoryId: Int
    let score: Int
    let correctedResponse: String?

    enum CodingKeys: String, CodingKey {
        case memoryId = "memory_id"
        case score
        case correctedResponse = "corrected_response"
    }
}
