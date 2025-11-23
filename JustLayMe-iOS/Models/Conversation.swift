import Foundation

// MARK: - Conversation Model

struct Conversation: Codable, Identifiable, Equatable {
    let id: Int
    let userId: Int
    var modelType: String?
    var title: String?
    var messageCount: Int
    var isArchived: Bool
    var tags: String?
    let createdAt: Date
    var updatedAt: Date

    // MARK: - Coding Keys

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

    // MARK: - Computed Properties

    var displayTitle: String {
        title ?? "Conversation #\(id)"
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }

    var tagList: [String] {
        tags?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }
}

// MARK: - Conversations Response

struct ConversationsResponse: Codable {
    let conversations: [Conversation]
    let total: Int
    let page: Int
    let limit: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case conversations
        case total
        case page
        case limit
        case hasMore = "has_more"
    }
}

// MARK: - Conversation Messages Response

struct ConversationMessagesResponse: Codable {
    let messages: [Message]
    let conversation: Conversation
}

// MARK: - Search Response

struct ConversationSearchResponse: Codable {
    let results: [SearchResult]
    let total: Int

    struct SearchResult: Codable, Identifiable {
        let id: Int
        let conversationId: Int
        let content: String
        let senderType: String
        let createdAt: Date
        let matchHighlight: String?

        enum CodingKeys: String, CodingKey {
            case id
            case conversationId = "conversation_id"
            case content
            case senderType = "sender_type"
            case createdAt = "created_at"
            case matchHighlight = "match_highlight"
        }
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case json = "json"
    case txt = "txt"
    case markdown = "markdown"

    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .txt: return "Plain Text"
        case .markdown: return "Markdown"
        }
    }

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .txt: return "txt"
        case .markdown: return "md"
        }
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .txt: return "text/plain"
        case .markdown: return "text/markdown"
        }
    }
}
