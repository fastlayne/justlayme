import Foundation

// MARK: - Import Options

public struct ImportOptions {
    public var mergeStrategy: MergeStrategy = .skipExisting
    public var importConversations: Bool = true
    public var importCharacters: Bool = true
    public var importSettings: Bool = false

    public enum MergeStrategy {
        case skipExisting      // Skip if entity with same ID exists
        case overwriteExisting // Overwrite existing entities
        case createNew         // Always create new with new IDs
    }

    public init() {}
}

// MARK: - Import Result

public struct ImportResult {
    public var success: Bool
    public var conversationsImported: Int = 0
    public var messagesImported: Int = 0
    public var charactersImported: Int = 0
    public var memoriesImported: Int = 0
    public var learningPatternsImported: Int = 0
    public var skipped: Int = 0
    public var errors: [String] = []
}

// MARK: - Data Importer

public final class DataImporter {

    // MARK: - Singleton

    public static let shared = DataImporter()

    // MARK: - Dependencies

    private let userRepository = UserRepository.shared
    private let conversationRepository = ConversationRepository.shared
    private let messageRepository = MessageRepository.shared
    private let characterRepository = CharacterRepository.shared
    private let characterMemoryRepository = CharacterMemoryRepository.shared
    private let characterLearningRepository = CharacterLearningRepository.shared
    private let settingsManager = SettingsManager.shared
    private let validator = DataValidator.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Import

    /// Import data from JSON
    public func importData(
        from data: Data,
        userId: UUID,
        options: ImportOptions = ImportOptions()
    ) async throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exportData = try decoder.decode(ExportData.self, from: data)
        return try await importExportData(exportData, userId: userId, options: options)
    }

    /// Import from URL
    public func importData(
        from url: URL,
        userId: UUID,
        options: ImportOptions = ImportOptions()
    ) async throws -> ImportResult {
        let data = try Data(contentsOf: url)
        return try await importData(from: data, userId: userId, options: options)
    }

    /// Import export data structure
    private func importExportData(
        _ exportData: ExportData,
        userId: UUID,
        options: ImportOptions
    ) async throws -> ImportResult {
        var result = ImportResult(success: true)

        // Import conversations
        if options.importConversations, let conversations = exportData.conversations {
            for conversationExport in conversations {
                do {
                    let imported = try await importConversation(
                        conversationExport,
                        userId: userId,
                        options: options
                    )
                    if imported {
                        result.conversationsImported += 1
                        result.messagesImported += conversationExport.messages.count
                    } else {
                        result.skipped += 1
                    }
                } catch {
                    result.errors.append("Conversation import failed: \(error.localizedDescription)")
                }
            }
        }

        // Import characters
        if options.importCharacters, let characters = exportData.characters {
            for characterExport in characters {
                do {
                    let imported = try await importCharacter(
                        characterExport,
                        userId: userId,
                        options: options
                    )
                    if imported {
                        result.charactersImported += 1
                        result.memoriesImported += characterExport.memories?.count ?? 0
                        result.learningPatternsImported += characterExport.learningPatterns?.count ?? 0
                    } else {
                        result.skipped += 1
                    }
                } catch {
                    result.errors.append("Character import failed: \(error.localizedDescription)")
                }
            }
        }

        // Import settings
        if options.importSettings, let settings = exportData.settings {
            importSettings(settings)
        }

        result.success = result.errors.isEmpty
        return result
    }

    // MARK: - Import Conversation

    private func importConversation(
        _ export: ExportData.ConversationExport,
        userId: UUID,
        options: ImportOptions
    ) async throws -> Bool {
        let conversation = export.conversation

        // Check if exists
        let existing = try await conversationRepository.fetch(byId: conversation.id)

        switch options.mergeStrategy {
        case .skipExisting:
            if existing != nil { return false }

        case .overwriteExisting:
            if existing != nil {
                try await conversationRepository.delete(byId: conversation.id)
            }

        case .createNew:
            // Will create with new ID
            break
        }

        // Validate conversation
        let validationResult = validator.validate(conversation)
        if !validationResult.isValid {
            throw ImportError.validationFailed(validationResult.errors.joined(separator: ", "))
        }

        // Create conversation with correct user ID
        var newConversation = conversation
        if options.mergeStrategy == .createNew {
            newConversation = Conversation(
                id: UUID(),
                userId: userId,
                modelType: conversation.modelType,
                title: conversation.title,
                messageCount: conversation.messageCount,
                isArchived: conversation.isArchived,
                tags: conversation.tags,
                metadata: conversation.metadata,
                createdAt: conversation.createdAt,
                updatedAt: conversation.updatedAt,
                lastMessageAt: conversation.lastMessageAt
            )
        }

        let created = try await conversationRepository.create(newConversation)

        // Import messages
        for message in export.messages {
            var newMessage = message
            if options.mergeStrategy == .createNew {
                newMessage = Message(
                    id: UUID(),
                    conversationId: created.id,
                    legacyConversationId: message.legacyConversationId,
                    senderType: message.senderType,
                    content: message.content,
                    metadata: message.metadata,
                    isDeleted: message.isDeleted,
                    deletedAt: message.deletedAt,
                    isEdited: message.isEdited,
                    editedAt: message.editedAt,
                    tokensUsed: message.tokensUsed,
                    modelUsed: message.modelUsed,
                    responseTimeMs: message.responseTimeMs,
                    createdAt: message.createdAt
                )
            }

            _ = try await messageRepository.create(newMessage)
        }

        return true
    }

    // MARK: - Import Character

    private func importCharacter(
        _ export: ExportData.CharacterExport,
        userId: UUID,
        options: ImportOptions
    ) async throws -> Bool {
        let character = export.character

        // Check if exists
        let existing = try await characterRepository.fetch(byId: character.id)

        switch options.mergeStrategy {
        case .skipExisting:
            if existing != nil { return false }

        case .overwriteExisting:
            if existing != nil {
                try await characterRepository.delete(byId: character.id)
            }

        case .createNew:
            break
        }

        // Validate character
        let validationResult = validator.validate(character)
        if !validationResult.isValid {
            throw ImportError.validationFailed(validationResult.errors.joined(separator: ", "))
        }

        // Create character with correct user ID
        var newCharacter = character
        if options.mergeStrategy == .createNew {
            newCharacter = Character(
                id: UUID(),
                userId: userId,
                name: character.name,
                backstory: character.backstory,
                personalityTraits: character.personalityTraits,
                speechPatterns: character.speechPatterns,
                avatarUrl: character.avatarUrl,
                isPublic: character.isPublic,
                createdAt: character.createdAt,
                updatedAt: character.updatedAt
            )
        }

        let created = try await characterRepository.create(newCharacter)

        // Import memories
        if let memories = export.memories {
            for memory in memories {
                var newMemory = memory
                if options.mergeStrategy == .createNew {
                    newMemory = CharacterMemory(
                        id: UUID(),
                        characterId: created.id,
                        userMessage: memory.userMessage,
                        aiResponse: memory.aiResponse,
                        feedbackScore: memory.feedbackScore,
                        correctedResponse: memory.correctedResponse,
                        importanceScore: memory.importanceScore,
                        createdAt: memory.createdAt
                    )
                }
                _ = try await characterMemoryRepository.create(newMemory)
            }
        }

        // Import learning patterns
        if let patterns = export.learningPatterns {
            for pattern in patterns {
                var newPattern = pattern
                if options.mergeStrategy == .createNew {
                    newPattern = CharacterLearning(
                        id: UUID(),
                        characterId: created.id,
                        patternType: pattern.patternType,
                        userInput: pattern.userInput,
                        expectedOutput: pattern.expectedOutput,
                        confidence: pattern.confidence,
                        createdAt: pattern.createdAt
                    )
                }
                _ = try await characterLearningRepository.create(newPattern)
            }
        }

        return true
    }

    // MARK: - Import Settings

    private func importSettings(_ settings: [String: String]) {
        var settingsDict: [String: Any] = [:]
        for (key, value) in settings {
            // Try to convert to appropriate types
            if let boolValue = Bool(value) {
                settingsDict[key] = boolValue
            } else if let intValue = Int(value) {
                settingsDict[key] = intValue
            } else if let doubleValue = Double(value) {
                settingsDict[key] = doubleValue
            } else {
                settingsDict[key] = value
            }
        }
        settingsManager.importSettings(settingsDict)
    }

    // MARK: - Validation

    /// Validate import data before importing
    public func validateImportData(_ data: Data) throws -> (isValid: Bool, preview: ImportPreview) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exportData = try decoder.decode(ExportData.self, from: data)

        var preview = ImportPreview()
        preview.version = exportData.version
        preview.exportedAt = exportData.exportedAt
        preview.conversationCount = exportData.conversations?.count ?? 0
        preview.messageCount = exportData.conversations?.reduce(0) { $0 + $1.messages.count } ?? 0
        preview.characterCount = exportData.characters?.count ?? 0

        // Validate data
        var errors: [String] = []

        if let conversations = exportData.conversations {
            for (index, conv) in conversations.enumerated() {
                let result = validator.validate(conv.conversation)
                if !result.isValid {
                    errors.append("Conversation \(index): \(result.errors.joined(separator: ", "))")
                }
            }
        }

        if let characters = exportData.characters {
            for (index, char) in characters.enumerated() {
                let result = validator.validate(char.character)
                if !result.isValid {
                    errors.append("Character \(index): \(result.errors.joined(separator: ", "))")
                }
            }
        }

        preview.validationErrors = errors

        return (errors.isEmpty, preview)
    }
}

// MARK: - Import Preview

public struct ImportPreview {
    public var version: String = ""
    public var exportedAt: Date = Date()
    public var conversationCount: Int = 0
    public var messageCount: Int = 0
    public var characterCount: Int = 0
    public var validationErrors: [String] = []

    public var isValid: Bool {
        validationErrors.isEmpty
    }
}

// MARK: - Import Error

public enum ImportError: LocalizedError {
    case invalidFormat
    case validationFailed(String)
    case duplicateEntry(String)
    case unsupportedVersion(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid import file format"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .duplicateEntry(let entry):
            return "Duplicate entry: \(entry)"
        case .unsupportedVersion(let version):
            return "Unsupported export version: \(version)"
        }
    }
}
