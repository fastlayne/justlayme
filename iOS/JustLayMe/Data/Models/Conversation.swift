import Foundation

// MARK: - Conversation Model
/// Represents a chat conversation between user and AI
/// Matches backend: character-api.js conversations table

struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    var modelType: ModelType
    var title: String?
    var messageCount: Int
    var isArchived: Bool
    var tags: [String]?
    var createdAt: Date
    var updatedAt: Date

    // Computed from joined query
    var lastMessagePreview: String?
    var lastMessageTime: Date?
    var totalMessages: Int?

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
        case lastMessageTime = "last_message_time"
        case totalMessages = "total_messages"
    }

    init(
        id: String = UUID().uuidString,
        userId: String,
        modelType: ModelType,
        title: String? = nil,
        messageCount: Int = 0,
        isArchived: Bool = false,
        tags: [String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastMessagePreview: String? = nil,
        lastMessageTime: Date? = nil,
        totalMessages: Int? = nil
    ) {
        self.id = id
        self.userId = userId
        self.modelType = modelType
        self.title = title
        self.messageCount = messageCount
        self.isArchived = isArchived
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMessagePreview = lastMessagePreview
        self.lastMessageTime = lastMessageTime
        self.totalMessages = totalMessages
    }

    /// Display title, falling back to model name if no title set
    var displayTitle: String {
        title ?? modelType.displayName
    }

    /// Formatted last message time
    var formattedLastActivity: String {
        let date = lastMessageTime ?? updatedAt
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Conversations List Response
struct ConversationsListResponse: Codable {
    let conversations: [Conversation]
    let pagination: Pagination
}

// MARK: - Pagination
struct Pagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page
        case limit
        case total
        case totalPages = "totalPages"
    }

    var hasNextPage: Bool {
        return page < totalPages
    }

    var hasPreviousPage: Bool {
        return page > 1
    }
}

// MARK: - Conversation Query Options
struct ConversationQueryOptions {
    var page: Int = 1
    var limit: Int = 20
    var modelType: ModelType?
    var isArchived: Bool = false
    var searchQuery: String?
    var orderBy: String = "updated_at"
    var orderDirection: String = "DESC"

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "archived", value: "\(isArchived)"),
            URLQueryItem(name: "order_by", value: orderBy),
            URLQueryItem(name: "order_dir", value: orderDirection)
        ]

        if let modelType = modelType {
            items.append(URLQueryItem(name: "model_type", value: modelType.rawValue))
        }

        if let searchQuery = searchQuery, !searchQuery.isEmpty {
            items.append(URLQueryItem(name: "search", value: searchQuery))
        }

        return items
    }
}

// MARK: - Conversation Search Result
struct ConversationSearchResult: Codable, Identifiable {
    let id: String
    let conversation: Conversation
    let matchingMessage: String?
    let messageTime: Date?
    let relevance: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case conversation
        case matchingMessage = "matching_message"
        case messageTime = "message_time"
        case relevance
    }
}

// MARK: - Conversation Tag
struct ConversationTag: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    var tagName: String
    var color: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case tagName = "tag_name"
        case color
        case createdAt = "created_at"
    }

    init(
        id: String = UUID().uuidString,
        userId: String,
        tagName: String,
        color: String = "#6B46FF",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.tagName = tagName
        self.color = color
        self.createdAt = createdAt
    }
}

// MARK: - Archive Request
struct ArchiveRequest: Codable {
    let archive: Bool
}

// MARK: - Tag Request
struct TagRequest: Codable {
    let tagId: String

    enum CodingKeys: String, CodingKey {
        case tagId = "tag_id"
    }
}

// MARK: - Create Tag Request
struct CreateTagRequest: Codable {
    let tagName: String
    let color: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case color
    }
}
