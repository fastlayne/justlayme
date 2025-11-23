import Foundation

// MARK: - Message Model
/// Represents a single message in a conversation
/// Matches backend: character-api.js messages table

struct Message: Codable, Identifiable, Hashable {
    let id: String
    let conversationId: String
    let senderType: SenderType
    var content: String
    var metadata: MessageMetadata?
    var isDeleted: Bool
    var createdAt: Date

    // Additional fields from joined queries
    var senderName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_uuid"
        case senderType = "sender_type"
        case content
        case metadata
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case senderName = "sender_name"
    }

    init(
        id: String = UUID().uuidString,
        conversationId: String,
        senderType: SenderType,
        content: String,
        metadata: MessageMetadata? = nil,
        isDeleted: Bool = false,
        createdAt: Date = Date(),
        senderName: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderType = senderType
        self.content = content
        self.metadata = metadata
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.senderName = senderName
    }

    /// Check if this is a user message
    var isUserMessage: Bool {
        return senderType == .human
    }

    /// Get display name for sender
    var displaySenderName: String {
        if let name = senderName {
            return name
        }
        return senderType == .human ? "You" : "AI"
    }

    /// Formatted timestamp
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Formatted date and time
    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

// MARK: - Sender Type
enum SenderType: String, Codable, CaseIterable {
    case human = "human"
    case ai = "ai"
    case system = "system"

    var displayName: String {
        switch self {
        case .human: return "You"
        case .ai: return "AI"
        case .system: return "System"
        }
    }
}

// MARK: - Message Metadata
struct MessageMetadata: Codable, Hashable {
    var characterId: String?
    var characterName: String?
    var model: String?
    var modelType: String?
    var customized: Bool?
    var tokensUsed: Int?
    var responseTimeMs: Int?

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case characterName = "character_name"
        case model
        case modelType = "model_type"
        case customized
        case tokensUsed = "tokens_used"
        case responseTimeMs = "response_time_ms"
    }

    init(
        characterId: String? = nil,
        characterName: String? = nil,
        model: String? = nil,
        modelType: String? = nil,
        customized: Bool? = nil,
        tokensUsed: Int? = nil,
        responseTimeMs: Int? = nil
    ) {
        self.characterId = characterId
        self.characterName = characterName
        self.model = model
        self.modelType = modelType
        self.customized = customized
        self.tokensUsed = tokensUsed
        self.responseTimeMs = responseTimeMs
    }
}

// MARK: - Messages List Response
struct MessagesListResponse: Codable {
    let messages: [Message]
}

// MARK: - Message Query Options
struct MessageQueryOptions {
    var page: Int = 1
    var limit: Int = 50
    var orderDirection: String = "ASC"

    var queryItems: [URLQueryItem] {
        return [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "order_dir", value: orderDirection)
        ]
    }
}

// MARK: - Chat Message (Local UI Model)
/// Simplified message model for real-time chat UI
struct ChatMessage: Identifiable, Hashable {
    let id: String
    let content: String
    let isUser: Bool
    let timestamp: Date
    var isLoading: Bool
    var error: String?

    init(
        id: String = UUID().uuidString,
        content: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isLoading: Bool = false,
        error: String? = nil
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.isLoading = isLoading
        self.error = error
    }

    /// Create a loading placeholder message
    static func loading() -> ChatMessage {
        return ChatMessage(
            content: "",
            isUser: false,
            isLoading: true
        )
    }

    /// Convert from API Message model
    static func from(_ message: Message) -> ChatMessage {
        return ChatMessage(
            id: message.id,
            content: message.content,
            isUser: message.senderType == .human,
            timestamp: message.createdAt
        )
    }
}

// MARK: - Message Attachment (Future Support)
struct MessageAttachment: Codable, Identifiable, Hashable {
    let id: String
    let messageId: String
    let attachmentType: AttachmentType
    let fileUrl: String
    var fileSize: Int?
    var mimeType: String?
    var metadata: [String: String]?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case messageId = "message_id"
        case attachmentType = "attachment_type"
        case fileUrl = "file_url"
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case metadata
        case createdAt = "created_at"
    }
}

// MARK: - Attachment Type
enum AttachmentType: String, Codable, CaseIterable {
    case image = "image"
    case audio = "audio"
    case file = "file"

    var icon: String {
        switch self {
        case .image: return "photo"
        case .audio: return "waveform"
        case .file: return "doc"
        }
    }
}
