import Foundation
import SwiftData

// MARK: - Data Container
/// SwiftData container configuration for JustLayMe iOS app

@MainActor
final class DataContainer {
    /// Shared singleton instance
    static let shared = DataContainer()

    /// The SwiftData model container
    let container: ModelContainer

    /// Main model context
    var mainContext: ModelContext {
        container.mainContext
    }

    private init() {
        let schema = Schema([
            UserEntity.self,
            ConversationEntity.self,
            MessageEntity.self,
            CharacterEntity.self,
            CharacterMemoryEntity.self,
            CharacterLearningEntity.self,
            ConversationTagEntity.self,
            CachedModelInfo.self,
            UserPreferencesEntity.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            print("SwiftData container initialized successfully")
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    // MARK: - Context Management

    /// Create a new background context
    func newBackgroundContext() -> ModelContext {
        return ModelContext(container)
    }

    /// Perform work on a background context
    func performBackgroundTask<T>(_ block: @escaping (ModelContext) async throws -> T) async throws -> T {
        let context = ModelContext(container)
        return try await block(context)
    }

    // MARK: - Data Management

    /// Delete all data from the container
    func deleteAllData() async throws {
        let context = mainContext

        try context.delete(model: MessageEntity.self)
        try context.delete(model: ConversationEntity.self)
        try context.delete(model: CharacterMemoryEntity.self)
        try context.delete(model: CharacterLearningEntity.self)
        try context.delete(model: CharacterEntity.self)
        try context.delete(model: ConversationTagEntity.self)
        try context.delete(model: CachedModelInfo.self)

        try context.save()
    }

    /// Get storage statistics
    func getStorageStats() async throws -> DataStats {
        let context = mainContext

        let conversationCount = try context.fetchCount(FetchDescriptor<ConversationEntity>())
        let messageCount = try context.fetchCount(FetchDescriptor<MessageEntity>())
        let characterCount = try context.fetchCount(FetchDescriptor<CharacterEntity>())

        return DataStats(
            conversationCount: conversationCount,
            messageCount: messageCount,
            characterCount: characterCount,
            totalSize: 0 // Would need to calculate actual file size
        )
    }
}

// MARK: - Schema Version
enum SchemaVersion: Int, Hashable {
    case v1 = 1
    case v2 = 2

    static var current: SchemaVersion { .v1 }
}

// MARK: - Migration Plans
enum JustLayMeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

// MARK: - Schema V1
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            UserEntity.self,
            ConversationEntity.self,
            MessageEntity.self,
            CharacterEntity.self,
            CharacterMemoryEntity.self,
            CharacterLearningEntity.self,
            ConversationTagEntity.self,
            CachedModelInfo.self,
            UserPreferencesEntity.self
        ]
    }
}
