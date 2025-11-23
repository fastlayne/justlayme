import Foundation
import Combine

// MARK: - Data Manager

/// Main facade for all data operations
/// Provides a unified interface for persistence, caching, sync, and settings
public final class DataManager {

    // MARK: - Singleton

    public static let shared = DataManager()

    // MARK: - Core Components

    public let coreData: CoreDataStack
    public let cache: CacheManager
    public let sync: SyncManager
    public let offline: OfflineManager
    public let settings: SettingsManager
    public let migration: MigrationManager
    public let exporter: DataExporter
    public let importer: DataImporter
    public let validator: DataValidator

    // MARK: - Repositories

    public let users: UserRepository
    public let conversations: ConversationRepository
    public let messages: MessageRepository
    public let characters: CharacterRepository
    public let characterMemories: CharacterMemoryRepository
    public let characterLearning: CharacterLearningRepository

    // MARK: - Publishers

    @Published public private(set) var isInitialized: Bool = false
    @Published public private(set) var initializationError: Error?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Initialize core components
        coreData = CoreDataStack.shared
        cache = CacheManager.shared
        sync = SyncManager.shared
        offline = OfflineManager.shared
        settings = SettingsManager.shared
        migration = MigrationManager.shared
        exporter = DataExporter.shared
        importer = DataImporter.shared
        validator = DataValidator.shared

        // Initialize repositories
        users = UserRepository.shared
        conversations = ConversationRepository.shared
        messages = MessageRepository.shared
        characters = CharacterRepository.shared
        characterMemories = CharacterMemoryRepository.shared
        characterLearning = CharacterLearningRepository.shared
    }

    // MARK: - Setup

    /// Initialize the data layer (call on app startup)
    public func initialize() async {
        do {
            // Run migrations if needed
            try await migration.migrateIfNeeded()

            // Clean expired cache
            try await cache.cleanExpiredEntries()

            // Record app launch
            settings.recordAppLaunch()

            isInitialized = true
            initializationError = nil

            // Start auto-sync if enabled
            if settings.autoSyncEnabled {
                await sync.syncAll()
            }
        } catch {
            initializationError = error
            print("Data initialization failed: \(error)")
        }
    }

    // MARK: - Current User

    /// Get currently logged in user
    public var currentUser: User? {
        get async {
            guard let userId = settings.currentUserId else { return nil }
            return try? await users.fetch(byId: userId)
        }
    }

    /// Check if user is logged in
    public var isLoggedIn: Bool {
        settings.isLoggedIn
    }

    // MARK: - Convenience Methods

    /// Get conversations for current user
    public func getConversations(includeArchived: Bool = false) async throws -> [Conversation] {
        guard let userId = settings.currentUserId else {
            throw DataManagerError.notLoggedIn
        }
        return try await conversations.fetch(byUserId: userId, includeArchived: includeArchived)
    }

    /// Get characters for current user
    public func getCharacters() async throws -> [Character] {
        guard let userId = settings.currentUserId else {
            throw DataManagerError.notLoggedIn
        }
        return try await characters.fetch(byUserId: userId)
    }

    /// Create a new conversation
    public func createConversation(modelType: ModelType, title: String? = nil) async throws -> Conversation {
        guard let userId = settings.currentUserId else {
            throw DataManagerError.notLoggedIn
        }

        let conversation = Conversation(
            userId: userId,
            modelType: modelType,
            title: title
        )

        return try await conversations.create(conversation)
    }

    /// Send a message in conversation
    public func sendMessage(
        conversationId: UUID,
        content: String,
        metadata: MessageMetadata = MessageMetadata()
    ) async throws -> Message {
        let message = Message(
            conversationId: conversationId,
            senderType: .human,
            content: content,
            metadata: metadata
        )

        // Validate
        let validation = validator.validate(message)
        guard validation.isValid else {
            throw DataManagerError.validationFailed(validation.errors.joined(separator: ", "))
        }

        // Save
        let savedMessage = try await messages.create(message)

        // Update conversation
        try await conversations.incrementMessageCount(conversationId: conversationId)

        return savedMessage
    }

    /// Create a new character
    public func createCharacter(
        name: String,
        backstory: String? = nil,
        personalityTraits: [String: Any] = [:],
        speechPatterns: [String] = []
    ) async throws -> Character {
        guard let userId = settings.currentUserId else {
            throw DataManagerError.notLoggedIn
        }

        let character = Character(
            userId: userId,
            name: name,
            backstory: backstory,
            personalityTraits: personalityTraits,
            speechPatterns: speechPatterns
        )

        // Validate
        let validation = validator.validate(character)
        guard validation.isValid else {
            throw DataManagerError.validationFailed(validation.errors.joined(separator: ", "))
        }

        return try await characters.create(character)
    }

    // MARK: - Export/Import

    /// Export all user data
    public func exportAllData(format: ExportFormat = .json) async throws -> Data {
        guard let userId = settings.currentUserId else {
            throw DataManagerError.notLoggedIn
        }

        var options = ExportOptions()
        options.format = format
        options.includeCharacterMemories = true
        options.includeCharacterLearning = true

        return try await exporter.exportUserData(userId: userId, options: options)
    }

    /// Import data from file
    public func importData(from data: Data, options: ImportOptions = ImportOptions()) async throws -> ImportResult {
        guard let userId = settings.currentUserId else {
            throw DataManagerError.notLoggedIn
        }

        return try await importer.importData(from: data, userId: userId, options: options)
    }

    // MARK: - Cleanup

    /// Clear all local data
    public func clearAllData() async throws {
        try await cache.clearAll()
        try await sync.clearQueue()
        try coreData.resetStore()
        settings.clearAllData()
    }

    /// Clear cache only
    public func clearCache() async throws {
        try await cache.clearAll()
    }

    /// Delete user account data
    public func deleteAccountData() async throws {
        guard let userId = settings.currentUserId else {
            throw DataManagerError.notLoggedIn
        }

        // Delete all user data
        try await conversations.deleteAll(forUserId: userId)
        try await characters.deleteAll(forUserId: userId)
        try await users.delete(byId: userId)

        // Clear local data
        settings.clearAuth()
        try await cache.clearAll()
    }
}

// MARK: - Data Manager Error

public enum DataManagerError: LocalizedError {
    case notLoggedIn
    case notInitialized
    case validationFailed(String)
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "User is not logged in"
        case .notInitialized:
            return "Data manager is not initialized"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        }
    }
}

// MARK: - App Lifecycle Integration

extension DataManager {

    /// Call when app becomes active
    public func applicationDidBecomeActive() {
        Task {
            if settings.autoSyncEnabled && sync.statePublisher.value != .syncing(progress: 0) {
                await sync.syncAll()
            }
        }
    }

    /// Call when app enters background
    public func applicationDidEnterBackground() {
        Task {
            try? await coreData.saveMainContext()
        }
    }

    /// Call when app will terminate
    public func applicationWillTerminate() {
        try? coreData.saveMainContext()
    }
}
