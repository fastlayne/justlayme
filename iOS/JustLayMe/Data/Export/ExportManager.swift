import Foundation
import SwiftData
import Combine
import UniformTypeIdentifiers

// MARK: - Export Manager
/// Manages export and import of analyses, conversations, and backups

@MainActor
final class ExportManager: ObservableObject {
    // MARK: - Singleton

    static let shared = ExportManager()

    // MARK: - Published Properties

    @Published private(set) var isExporting = false
    @Published private(set) var isImporting = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var error: Error?

    // MARK: - Private Properties

    private let modelContext: ModelContext
    private let fileManager = FileManager.default

    // MARK: - Initialization

    private init(modelContext: ModelContext = DataContainer.shared.mainContext) {
        self.modelContext = modelContext
    }

    // MARK: - Export Conversations

    /// Export a single conversation with messages
    func exportConversation(
        conversationId: String,
        format: ExportFormat
    ) async throws -> URL {
        isExporting = true
        progress = 0
        defer {
            isExporting = false
            progress = 1.0
        }

        // Fetch conversation
        let convPredicate = #Predicate<ConversationEntity> { $0.id == conversationId }
        var convDescriptor = FetchDescriptor<ConversationEntity>(predicate: convPredicate)
        convDescriptor.fetchLimit = 1

        guard let conversationEntity = try modelContext.fetch(convDescriptor).first else {
            throw ExportError.conversationNotFound
        }

        progress = 0.2

        // Fetch messages
        let msgPredicate = #Predicate<MessageEntity> { $0.conversationId == conversationId && $0.isDeleted == false }
        var msgDescriptor = FetchDescriptor<MessageEntity>(predicate: msgPredicate)
        msgDescriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]

        let messageEntities = try modelContext.fetch(msgDescriptor)

        progress = 0.5

        // Convert to export model
        let conversation = conversationEntity.toModel()
        let messages = messageEntities.map { $0.toModel() }
        let export = ConversationExport(conversation: conversation, messages: messages)

        progress = 0.7

        // Generate content based on format
        let content: String
        let filename: String

        switch format {
        case .json:
            content = try export.toJSON()
            filename = "conversation-\(conversationId).\(format.fileExtension)"
        case .txt:
            content = export.toText()
            filename = "conversation-\(conversationId).\(format.fileExtension)"
        case .markdown:
            content = export.toMarkdown()
            filename = "conversation-\(conversationId).\(format.fileExtension)"
        case .pdf:
            // PDF export would require PDFKit implementation
            throw ExportError.formatNotSupported
        }

        progress = 0.9

        // Write to temp file
        let tempDir = fileManager.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }

    /// Export all user data
    func exportAllData(userId: String) async throws -> URL {
        isExporting = true
        progress = 0
        defer {
            isExporting = false
            progress = 1.0
        }

        // Fetch user
        let userPredicate = #Predicate<UserEntity> { $0.id == userId }
        var userDescriptor = FetchDescriptor<UserEntity>(predicate: userPredicate)
        userDescriptor.fetchLimit = 1
        let userEntity = try modelContext.fetch(userDescriptor).first

        progress = 0.2

        // Fetch conversations
        let convPredicate = #Predicate<ConversationEntity> { $0.userId == userId }
        let convDescriptor = FetchDescriptor<ConversationEntity>(predicate: convPredicate)
        let conversationEntities = try modelContext.fetch(convDescriptor)

        progress = 0.4

        // Fetch characters
        let charPredicate = #Predicate<CharacterEntity> { $0.userId == userId }
        let charDescriptor = FetchDescriptor<CharacterEntity>(predicate: charPredicate)
        let characterEntities = try modelContext.fetch(charDescriptor)

        progress = 0.6

        // Convert to export model
        let exportData = ExportData(
            user: userEntity?.toModel(),
            conversations: conversationEntities.map { $0.toModel() },
            characters: characterEntities.map { $0.toModel() }
        )

        progress = 0.8

        // Generate JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)

        // Write to temp file
        let filename = "justlayme-export-\(formatDate(Date())).json"
        let tempDir = fileManager.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        try data.write(to: fileURL)

        return fileURL
    }

    /// Create a full backup
    func createBackup(userId: String) async throws -> URL {
        isExporting = true
        progress = 0
        defer {
            isExporting = false
            progress = 1.0
        }

        // Gather all data
        let exportURL = try await exportAllData(userId: userId)

        progress = 0.5

        // Gather all messages for each conversation
        let convPredicate = #Predicate<ConversationEntity> { $0.userId == userId }
        let conversations = try modelContext.fetch(FetchDescriptor<ConversationEntity>(predicate: convPredicate))

        var allMessages: [String: [Message]] = [:]

        for conversation in conversations {
            let msgPredicate = #Predicate<MessageEntity> { $0.conversationId == conversation.id }
            var msgDescriptor = FetchDescriptor<MessageEntity>(predicate: msgPredicate)
            msgDescriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]

            let messageEntities = try modelContext.fetch(msgDescriptor)
            allMessages[conversation.id] = messageEntities.map { $0.toModel() }
        }

        progress = 0.7

        // Create backup structure
        struct FullBackup: Codable {
            let metadata: BackupMetadata
            let data: ExportData
            let messages: [String: [Message]]
        }

        let stats = try await DataContainer.shared.getStorageStats()

        let backup = FullBackup(
            metadata: BackupMetadata(
                deviceName: getDeviceName(),
                appVersion: getAppVersion(),
                dataStats: stats
            ),
            data: try JSONDecoder().decode(ExportData.self, from: try Data(contentsOf: exportURL)),
            messages: allMessages
        )

        progress = 0.9

        // Write backup file
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let filename = "justlayme-backup-\(formatDate(Date())).json"
        let tempDir = fileManager.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        try data.write(to: fileURL)

        // Clean up export file
        try? fileManager.removeItem(at: exportURL)

        return fileURL
    }

    // MARK: - Import

    /// Import data from a file
    func importFromFile(_ url: URL) async throws -> ImportResult {
        isImporting = true
        progress = 0
        defer {
            isImporting = false
            progress = 1.0
        }

        // Read file
        let data = try Data(contentsOf: url)

        progress = 0.2

        // Try to decode as ExportData
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exportData: ExportData

        do {
            exportData = try decoder.decode(ExportData.self, from: data)
        } catch {
            // Try as full backup
            struct FullBackup: Codable {
                let metadata: BackupMetadata
                let data: ExportData
                let messages: [String: [Message]]?
            }

            let backup = try decoder.decode(FullBackup.self, from: data)
            exportData = backup.data

            // Import messages if present
            if let messages = backup.messages {
                progress = 0.5
                try await importMessages(messages)
            }
        }

        progress = 0.6

        // Import conversations
        var importedConversations = 0
        for conversation in exportData.conversations {
            let entity = ConversationEntity(from: conversation)
            entity.needsSync = true
            entity.isLocalOnly = true
            modelContext.insert(entity)
            importedConversations += 1
        }

        progress = 0.8

        // Import characters
        var importedCharacters = 0
        for character in exportData.characters {
            let entity = CharacterEntity(from: character)
            entity.needsSync = true
            entity.isLocalOnly = true
            modelContext.insert(entity)
            importedCharacters += 1
        }

        try modelContext.save()

        return ImportResult.success(
            conversations: importedConversations,
            messages: 0,
            characters: importedCharacters
        )
    }

    /// Import messages from backup
    private func importMessages(_ messages: [String: [Message]]) async throws {
        var totalMessages = 0

        for (conversationId, conversationMessages) in messages {
            for message in conversationMessages {
                // Check if message already exists
                let predicate = #Predicate<MessageEntity> { $0.id == message.id }
                let existing = try modelContext.fetchCount(FetchDescriptor<MessageEntity>(predicate: predicate))

                if existing == 0 {
                    let entity = MessageEntity(from: message)
                    entity.needsSync = true
                    entity.isLocalOnly = true
                    modelContext.insert(entity)
                    totalMessages += 1
                }
            }
        }

        try modelContext.save()
    }

    /// Import message files (txt, json)
    func importMessageFile(_ url: URL) async throws -> ImportResult {
        isImporting = true
        defer { isImporting = false }

        let data = try Data(contentsOf: url)

        // Try JSON first
        if let messages = try? JSONDecoder().decode([Message].self, from: data) {
            for message in messages {
                let entity = MessageEntity(from: message)
                entity.needsSync = true
                entity.isLocalOnly = true
                modelContext.insert(entity)
            }

            try modelContext.save()

            return ImportResult.success(
                conversations: 0,
                messages: messages.count,
                characters: 0
            )
        }

        // Try as conversation export
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let export = try? decoder.decode(ConversationExport.self, from: data) {
            // Import conversation
            let convEntity = ConversationEntity(from: export.conversation)
            convEntity.needsSync = true
            convEntity.isLocalOnly = true
            modelContext.insert(convEntity)

            // Import messages
            for message in export.messages {
                let msgEntity = MessageEntity(from: message)
                msgEntity.needsSync = true
                msgEntity.isLocalOnly = true
                msgEntity.conversation = convEntity
                modelContext.insert(msgEntity)
            }

            try modelContext.save()

            return ImportResult.success(
                conversations: 1,
                messages: export.messages.count,
                characters: 0
            )
        }

        throw ExportError.invalidFileFormat
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }

    private func getDeviceName() -> String {
        #if os(iOS)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? "Unknown"
        #endif
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Export Errors
enum ExportError: LocalizedError {
    case conversationNotFound
    case formatNotSupported
    case invalidFileFormat
    case exportFailed(String)
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .conversationNotFound:
            return "Conversation not found"
        case .formatNotSupported:
            return "Export format not supported"
        case .invalidFileFormat:
            return "Invalid file format"
        case .exportFailed(let message):
            return "Export failed: \(message)"
        case .importFailed(let message):
            return "Import failed: \(message)"
        }
    }
}

// MARK: - Shareable Export
/// Wrapper for sharing exported files

struct ShareableExport: Transferable {
    let url: URL
    let format: ExportFormat

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { export in
            SentTransferredFile(export.url)
        }
    }
}

// MARK: - UTType Extensions
extension UTType {
    static var justlaymeBackup: UTType {
        UTType(exportedAs: "me.justlay.backup")
    }

    static var justlaymeExport: UTType {
        UTType(exportedAs: "me.justlay.export")
    }
}
