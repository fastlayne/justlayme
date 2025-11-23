import Foundation

// MARK: - Export Data
/// Complete user data export
/// Matches backend: character-api.js GET /api/export-data

struct ExportData: Codable {
    let user: User?
    let conversations: [Conversation]
    let characters: [Character]
    let exportedAt: Date

    enum CodingKeys: String, CodingKey {
        case user
        case conversations
        case characters
        case exportedAt = "exported_at"
    }

    init(
        user: User?,
        conversations: [Conversation],
        characters: [Character],
        exportedAt: Date = Date()
    ) {
        self.user = user
        self.conversations = conversations
        self.characters = characters
        self.exportedAt = exportedAt
    }

    /// Creates an empty export data structure
    static var empty: ExportData {
        return ExportData(
            user: nil,
            conversations: [],
            characters: []
        )
    }
}

// MARK: - Conversation Export
/// Exported conversation with messages
/// Matches backend: chat-history-implementation.js exportConversation()

struct ConversationExport: Codable {
    let conversation: Conversation
    let messages: [Message]
    let exportedAt: Date

    enum CodingKeys: String, CodingKey {
        case conversation
        case messages
        case exportedAt = "exportedAt"
    }

    init(conversation: Conversation, messages: [Message], exportedAt: Date = Date()) {
        self.conversation = conversation
        self.messages = messages
        self.exportedAt = exportedAt
    }

    /// Convert to JSON string
    func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Convert to plain text
    func toText() -> String {
        var text = "Conversation: \(conversation.displayTitle)\n"
        text += "Date: \(formatDate(conversation.createdAt))\n"
        text += "Model: \(conversation.modelType.displayName)\n"
        text += String(repeating: "=", count: 50) + "\n\n"

        for message in messages {
            let sender = message.senderType == .human ? "You" : (message.senderName ?? "AI")
            let time = formatDateTime(message.createdAt)
            text += "[\(time)] \(sender):\n\(message.content)\n\n"
        }

        return text
    }

    /// Convert to Markdown
    func toMarkdown() -> String {
        var md = "# \(conversation.displayTitle)\n\n"
        md += "**Date:** \(formatDate(conversation.createdAt))\n"
        md += "**Model:** \(conversation.modelType.displayName)\n\n"
        md += "---\n\n"

        for message in messages {
            let sender = message.senderType == .human ? "**You**" : "**\(message.senderName ?? "AI")**"
            let time = formatTime(message.createdAt)
            md += "\(sender) _[\(time)]_\n\n\(message.content)\n\n---\n\n"
        }

        return md
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Export Format
enum ExportFormat: String, CaseIterable, Identifiable {
    case json = "json"
    case txt = "txt"
    case markdown = "markdown"
    case pdf = "pdf"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .txt: return "Plain Text"
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        }
    }

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .txt: return "txt"
        case .markdown: return "md"
        case .pdf: return "pdf"
        }
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .txt: return "text/plain"
        case .markdown: return "text/markdown"
        case .pdf: return "application/pdf"
        }
    }
}

// MARK: - Chat Export
/// Represents a pending or completed export job
/// Matches backend: database-schema-recommendations.sql chat_exports table

struct ChatExport: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let conversationId: String
    var exportFormat: ExportFormat
    var fileUrl: String?
    var status: ExportStatus
    var createdAt: Date
    var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case conversationId = "conversation_id"
        case exportFormat = "export_format"
        case fileUrl = "file_url"
        case status
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
}

// MARK: - Export Status
enum ExportStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }
}

// MARK: - Import Result
struct ImportResult: Codable {
    let success: Bool
    let message: String
    let importedConversations: Int
    let importedMessages: Int
    let importedCharacters: Int
    let errors: [String]

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case importedConversations = "imported_conversations"
        case importedMessages = "imported_messages"
        case importedCharacters = "imported_characters"
        case errors
    }

    init(
        success: Bool,
        message: String,
        importedConversations: Int = 0,
        importedMessages: Int = 0,
        importedCharacters: Int = 0,
        errors: [String] = []
    ) {
        self.success = success
        self.message = message
        self.importedConversations = importedConversations
        self.importedMessages = importedMessages
        self.importedCharacters = importedCharacters
        self.errors = errors
    }

    static func success(conversations: Int, messages: Int, characters: Int) -> ImportResult {
        return ImportResult(
            success: true,
            message: "Import completed successfully",
            importedConversations: conversations,
            importedMessages: messages,
            importedCharacters: characters
        )
    }

    static func failure(_ error: String) -> ImportResult {
        return ImportResult(
            success: false,
            message: error,
            errors: [error]
        )
    }
}

// MARK: - Backup Metadata
struct BackupMetadata: Codable {
    let version: String
    let createdAt: Date
    let deviceName: String
    let appVersion: String
    let dataStats: DataStats

    enum CodingKeys: String, CodingKey {
        case version
        case createdAt = "created_at"
        case deviceName = "device_name"
        case appVersion = "app_version"
        case dataStats = "data_stats"
    }

    init(
        version: String = "1.0",
        deviceName: String = "",
        appVersion: String = "",
        dataStats: DataStats = DataStats()
    ) {
        self.version = version
        self.createdAt = Date()
        self.deviceName = deviceName
        self.appVersion = appVersion
        self.dataStats = dataStats
    }
}

// MARK: - Data Stats
struct DataStats: Codable {
    var conversationCount: Int
    var messageCount: Int
    var characterCount: Int
    var totalSize: Int64

    enum CodingKeys: String, CodingKey {
        case conversationCount = "conversation_count"
        case messageCount = "message_count"
        case characterCount = "character_count"
        case totalSize = "total_size"
    }

    init(
        conversationCount: Int = 0,
        messageCount: Int = 0,
        characterCount: Int = 0,
        totalSize: Int64 = 0
    ) {
        self.conversationCount = conversationCount
        self.messageCount = messageCount
        self.characterCount = characterCount
        self.totalSize = totalSize
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}
