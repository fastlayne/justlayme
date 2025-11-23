import Foundation

// MARK: - Export Format

public enum ExportFormat: String, CaseIterable {
    case json
    case csv
    case markdown

    public var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .markdown: return "md"
        }
    }

    public var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .markdown: return "text/markdown"
        }
    }
}

// MARK: - Export Options

public struct ExportOptions {
    public var includeUser: Bool = true
    public var includeConversations: Bool = true
    public var includeMessages: Bool = true
    public var includeCharacters: Bool = true
    public var includeCharacterMemories: Bool = false
    public var includeCharacterLearning: Bool = false
    public var includeSettings: Bool = true

    public var conversationIds: [UUID]? // nil = all
    public var characterIds: [UUID]? // nil = all

    public var format: ExportFormat = .json
    public var prettyPrint: Bool = true

    public init() {}
}

// MARK: - Export Data Structure

public struct ExportData: Codable {
    public var version: String = "1.0"
    public var exportedAt: Date = Date()
    public var user: User?
    public var conversations: [ConversationExport]?
    public var characters: [CharacterExport]?
    public var settings: [String: String]?

    public struct ConversationExport: Codable {
        public let conversation: Conversation
        public let messages: [Message]
    }

    public struct CharacterExport: Codable {
        public let character: Character
        public let memories: [CharacterMemory]?
        public let learningPatterns: [CharacterLearning]?
    }
}

// MARK: - Data Exporter

public final class DataExporter {

    // MARK: - Singleton

    public static let shared = DataExporter()

    // MARK: - Dependencies

    private let userRepository = UserRepository.shared
    private let conversationRepository = ConversationRepository.shared
    private let messageRepository = MessageRepository.shared
    private let characterRepository = CharacterRepository.shared
    private let characterMemoryRepository = CharacterMemoryRepository.shared
    private let characterLearningRepository = CharacterLearningRepository.shared
    private let settingsManager = SettingsManager.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Export

    /// Export all user data
    public func exportUserData(userId: UUID, options: ExportOptions = ExportOptions()) async throws -> Data {
        var exportData = ExportData()

        // Export user
        if options.includeUser {
            exportData.user = try await userRepository.fetch(byId: userId)
        }

        // Export conversations
        if options.includeConversations {
            var conversationExports: [ExportData.ConversationExport] = []

            let conversations: [Conversation]
            if let ids = options.conversationIds {
                conversations = try await fetchConversations(ids: ids)
            } else {
                conversations = try await conversationRepository.fetch(byUserId: userId)
            }

            for conversation in conversations {
                var messages: [Message] = []
                if options.includeMessages {
                    messages = try await messageRepository.fetch(byConversationId: conversation.id)
                }
                conversationExports.append(ExportData.ConversationExport(
                    conversation: conversation,
                    messages: messages
                ))
            }

            exportData.conversations = conversationExports
        }

        // Export characters
        if options.includeCharacters {
            var characterExports: [ExportData.CharacterExport] = []

            let characters: [Character]
            if let ids = options.characterIds {
                characters = try await fetchCharacters(ids: ids)
            } else {
                characters = try await characterRepository.fetch(byUserId: userId)
            }

            for character in characters {
                var memories: [CharacterMemory]?
                var learning: [CharacterLearning]?

                if options.includeCharacterMemories {
                    memories = try await characterMemoryRepository.fetch(byCharacterId: character.id)
                }

                if options.includeCharacterLearning {
                    learning = try await characterLearningRepository.fetch(byCharacterId: character.id)
                }

                characterExports.append(ExportData.CharacterExport(
                    character: character,
                    memories: memories,
                    learningPatterns: learning
                ))
            }

            exportData.characters = characterExports
        }

        // Export settings
        if options.includeSettings {
            exportData.settings = settingsManager.exportSettings().mapValues { String(describing: $0) }
        }

        // Convert to requested format
        return try encode(exportData, format: options.format, prettyPrint: options.prettyPrint)
    }

    /// Export single conversation
    public func exportConversation(
        conversationId: UUID,
        format: ExportFormat = .json
    ) async throws -> Data {
        guard let conversation = try await conversationRepository.fetch(byId: conversationId) else {
            throw ExportError.conversationNotFound
        }

        let messages = try await messageRepository.fetch(byConversationId: conversationId)

        let export = ExportData.ConversationExport(
            conversation: conversation,
            messages: messages
        )

        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(export)

        case .csv:
            return try exportConversationToCSV(conversation: conversation, messages: messages)

        case .markdown:
            return try exportConversationToMarkdown(conversation: conversation, messages: messages)
        }
    }

    // MARK: - Format Specific Exports

    private func encode(_ data: ExportData, format: ExportFormat, prettyPrint: Bool) throws -> Data {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            if prettyPrint {
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            }
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(data)

        case .csv:
            return try exportToCSV(data)

        case .markdown:
            return try exportToMarkdown(data)
        }
    }

    private func exportToCSV(_ data: ExportData) throws -> Data {
        var csv = "type,id,created_at,content\n"

        if let conversations = data.conversations {
            for conversationExport in conversations {
                let conv = conversationExport.conversation
                csv += "conversation,\(conv.id),\(conv.createdAt),\"\(conv.title ?? "")\"\n"

                for message in conversationExport.messages {
                    let content = message.content.replacingOccurrences(of: "\"", with: "\"\"")
                    csv += "message,\(message.id),\(message.createdAt),\"\(content)\"\n"
                }
            }
        }

        return csv.data(using: .utf8) ?? Data()
    }

    private func exportToMarkdown(_ data: ExportData) throws -> Data {
        var md = "# JustLayMe Data Export\n\n"
        md += "Exported: \(ISO8601DateFormatter().string(from: data.exportedAt))\n\n"

        if let user = data.user {
            md += "## User\n\n"
            md += "- Email: \(user.email)\n"
            md += "- Name: \(user.name ?? "N/A")\n"
            md += "- Subscription: \(user.subscriptionStatus.displayName)\n\n"
        }

        if let conversations = data.conversations {
            md += "## Conversations\n\n"

            for conversationExport in conversations {
                let conv = conversationExport.conversation
                md += "### \(conv.title ?? "Untitled")\n\n"
                md += "Model: \(conv.modelType.displayName)\n\n"

                for message in conversationExport.messages {
                    let sender = message.senderType == .human ? "**You**" : "**AI**"
                    md += "\(sender): \(message.content)\n\n"
                }

                md += "---\n\n"
            }
        }

        if let characters = data.characters {
            md += "## Characters\n\n"

            for characterExport in characters {
                let char = characterExport.character
                md += "### \(char.name)\n\n"
                if let backstory = char.backstory {
                    md += "**Backstory:** \(backstory)\n\n"
                }
                if !char.speechPatterns.isEmpty {
                    md += "**Speech Patterns:** \(char.speechPatterns.joined(separator: ", "))\n\n"
                }
            }
        }

        return md.data(using: .utf8) ?? Data()
    }

    private func exportConversationToCSV(conversation: Conversation, messages: [Message]) throws -> Data {
        var csv = "timestamp,sender,content\n"

        for message in messages {
            let timestamp = ISO8601DateFormatter().string(from: message.createdAt)
            let sender = message.senderType == .human ? "You" : "AI"
            let content = message.content.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(timestamp),\(sender),\"\(content)\"\n"
        }

        return csv.data(using: .utf8) ?? Data()
    }

    private func exportConversationToMarkdown(conversation: Conversation, messages: [Message]) throws -> Data {
        var md = "# \(conversation.title ?? "Conversation")\n\n"
        md += "Model: \(conversation.modelType.displayName)\n"
        md += "Created: \(ISO8601DateFormatter().string(from: conversation.createdAt))\n\n"
        md += "---\n\n"

        for message in messages {
            let sender = message.senderType == .human ? "**You**" : "**AI**"
            let time = DateFormatter.localizedString(from: message.createdAt, dateStyle: .none, timeStyle: .short)
            md += "\(sender) (\(time)):\n\n\(message.content)\n\n"
        }

        return md.data(using: .utf8) ?? Data()
    }

    // MARK: - Helpers

    private func fetchConversations(ids: [UUID]) async throws -> [Conversation] {
        var conversations: [Conversation] = []
        for id in ids {
            if let conversation = try await conversationRepository.fetch(byId: id) {
                conversations.append(conversation)
            }
        }
        return conversations
    }

    private func fetchCharacters(ids: [UUID]) async throws -> [Character] {
        var characters: [Character] = []
        for id in ids {
            if let character = try await characterRepository.fetch(byId: id) {
                characters.append(character)
            }
        }
        return characters
    }

    // MARK: - File Export

    /// Export to file and return URL
    public func exportToFile(
        userId: UUID,
        options: ExportOptions = ExportOptions(),
        filename: String? = nil
    ) async throws -> URL {
        let data = try await exportUserData(userId: userId, options: options)

        let name = filename ?? "justlayme_export_\(Int(Date().timeIntervalSince1970))"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension(options.format.fileExtension)

        try data.write(to: url)
        return url
    }
}

// MARK: - Export Error

public enum ExportError: LocalizedError {
    case conversationNotFound
    case characterNotFound
    case encodingFailed
    case fileSaveFailed

    public var errorDescription: String? {
        switch self {
        case .conversationNotFound:
            return "Conversation not found"
        case .characterNotFound:
            return "Character not found"
        case .encodingFailed:
            return "Failed to encode data"
        case .fileSaveFailed:
            return "Failed to save file"
        }
    }
}
