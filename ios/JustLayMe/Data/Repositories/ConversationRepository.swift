import Foundation
import CoreData

// MARK: - Conversation Repository

public final class ConversationRepository: BaseRepository<Conversation, CDConversation> {

    // MARK: - Singleton

    public static let shared = ConversationRepository()

    // MARK: - Initialization

    private init() {
        super.init(entityName: "CDConversation")
    }

    // MARK: - Domain Conversion

    public override func toDomain(_ managedObject: CDConversation) -> Conversation {
        var tags: [String] = []
        if let data = managedObject.tagsData,
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String] {
            tags = decoded
        }

        var metadata: [String: String] = [:]
        if let data = managedObject.metadataData,
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            metadata = decoded
        }

        return Conversation(
            id: managedObject.id ?? UUID(),
            userId: managedObject.userId ?? UUID(),
            modelType: ModelType(rawValue: managedObject.modelType ?? "") ?? .layme_v1,
            title: managedObject.title,
            messageCount: Int(managedObject.messageCount),
            isArchived: managedObject.isArchived,
            tags: tags,
            metadata: metadata,
            createdAt: managedObject.createdAt ?? Date(),
            updatedAt: managedObject.updatedAt,
            lastMessageAt: managedObject.lastMessageAt
        )
    }

    public override func toManagedObject(_ entity: Conversation, managedObject: CDConversation) {
        managedObject.id = entity.id
        managedObject.userId = entity.userId
        managedObject.modelType = entity.modelType.rawValue
        managedObject.title = entity.title
        managedObject.messageCount = Int32(entity.messageCount)
        managedObject.isArchived = entity.isArchived
        managedObject.tagsData = try? JSONSerialization.data(withJSONObject: entity.tags)
        managedObject.metadataData = try? JSONSerialization.data(withJSONObject: entity.metadata)
        managedObject.createdAt = entity.createdAt
        managedObject.updatedAt = entity.updatedAt
        managedObject.lastMessageAt = entity.lastMessageAt
        managedObject.syncStatus = SyncStatus.pendingSync.rawValue
    }

    public override func createManagedObject(from entity: Conversation, in context: NSManagedObjectContext) -> CDConversation {
        let managedObject = CDConversation(context: context)
        toManagedObject(entity, managedObject: managedObject)
        managedObject.syncStatus = SyncStatus.pending.rawValue
        return managedObject
    }

    // MARK: - Custom Queries

    /// Fetch conversations for user
    public func fetch(byUserId userId: UUID, includeArchived: Bool = false) async throws -> [Conversation] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDConversation.fetchRequest(byUserId: userId, includeArchived: includeArchived)
            let managedObjects = try context.fetch(request)
            return managedObjects.map { self.toDomain($0) }
        }
    }

    /// Fetch conversations by model type
    public func fetch(byModelType modelType: ModelType) async throws -> [Conversation] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDConversation.fetchRequest(byModelType: modelType.rawValue)
            let managedObjects = try context.fetch(request)
            return managedObjects.map { self.toDomain($0) }
        }
    }

    /// Fetch recent conversations (limited for free users)
    public func fetchRecent(userId: UUID, limit: Int) async throws -> [Conversation] {
        let options = FetchOptions(
            sortDescriptors: [NSSortDescriptor(key: "lastMessageAt", ascending: false)],
            predicate: NSPredicate(format: "userId == %@ AND isArchived == NO", userId as CVarArg),
            fetchLimit: limit
        )
        return try await fetchAll(options: options)
    }

    /// Search conversations by title
    public func search(query: String, userId: UUID) async throws -> [Conversation] {
        let predicate = NSPredicate(
            format: "userId == %@ AND title CONTAINS[cd] %@",
            userId as CVarArg, query
        )
        return try await fetchAll(options: FetchOptions(predicate: predicate))
    }

    /// Archive a conversation
    public func archive(conversationId: UUID) async throws -> Conversation {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDConversation.fetchRequest(byId: conversationId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(conversationId)
            }

            managedObject.isArchived = true
            managedObject.syncStatus = SyncStatus.pendingSync.rawValue

            return self.toDomain(managedObject)
        }
    }

    /// Unarchive a conversation
    public func unarchive(conversationId: UUID) async throws -> Conversation {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDConversation.fetchRequest(byId: conversationId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(conversationId)
            }

            managedObject.isArchived = false
            managedObject.syncStatus = SyncStatus.pendingSync.rawValue

            return self.toDomain(managedObject)
        }
    }

    /// Update conversation title
    public func updateTitle(conversationId: UUID, title: String) async throws -> Conversation {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDConversation.fetchRequest(byId: conversationId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(conversationId)
            }

            managedObject.title = title
            managedObject.syncStatus = SyncStatus.pendingSync.rawValue

            return self.toDomain(managedObject)
        }
    }

    /// Increment message count and update last message time
    public func incrementMessageCount(conversationId: UUID) async throws {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard self != nil else { throw RepositoryError.contextNotAvailable }

            let request = CDConversation.fetchRequest(byId: conversationId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(conversationId)
            }

            managedObject.messageCount += 1
            managedObject.lastMessageAt = Date()
            managedObject.syncStatus = SyncStatus.pendingSync.rawValue
        }
    }

    /// Add tag to conversation
    public func addTag(conversationId: UUID, tag: String) async throws -> Conversation {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDConversation.fetchRequest(byId: conversationId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(conversationId)
            }

            var tags = managedObject.tags
            if !tags.contains(tag) {
                tags.append(tag)
                managedObject.tags = tags
                managedObject.syncStatus = SyncStatus.pendingSync.rawValue
            }

            return self.toDomain(managedObject)
        }
    }

    /// Remove tag from conversation
    public func removeTag(conversationId: UUID, tag: String) async throws -> Conversation {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDConversation.fetchRequest(byId: conversationId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(conversationId)
            }

            var tags = managedObject.tags
            tags.removeAll { $0 == tag }
            managedObject.tags = tags
            managedObject.syncStatus = SyncStatus.pendingSync.rawValue

            return self.toDomain(managedObject)
        }
    }

    /// Delete all conversations for user
    public func deleteAll(forUserId userId: UUID) async throws {
        let predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        try await deleteWhere(predicate: predicate)
    }
}
