import Foundation
import CoreData

// MARK: - Message Repository

public final class MessageRepository: BaseRepository<Message, CDMessage> {

    // MARK: - Singleton

    public static let shared = MessageRepository()

    // MARK: - Initialization

    private init() {
        super.init(entityName: "CDMessage")
    }

    // MARK: - Domain Conversion

    public override func toDomain(_ managedObject: CDMessage) -> Message {
        var metadata = MessageMetadata()
        if let data = managedObject.metadataData {
            metadata = (try? JSONDecoder().decode(MessageMetadata.self, from: data)) ?? MessageMetadata()
        }

        return Message(
            id: managedObject.id ?? UUID(),
            conversationId: managedObject.conversationId ?? UUID(),
            legacyConversationId: managedObject.legacyConversationId,
            senderType: SenderType(rawValue: managedObject.senderType ?? "") ?? .human,
            content: managedObject.content ?? "",
            metadata: metadata,
            isDeleted: managedObject.isDeleted,
            deletedAt: managedObject.deletedAt,
            isEdited: managedObject.isEdited,
            editedAt: managedObject.editedAt,
            tokensUsed: managedObject.tokensUsed > 0 ? Int(managedObject.tokensUsed) : nil,
            modelUsed: managedObject.modelUsed,
            responseTimeMs: managedObject.responseTimeMs > 0 ? Int(managedObject.responseTimeMs) : nil,
            createdAt: managedObject.createdAt ?? Date()
        )
    }

    public override func toManagedObject(_ entity: Message, managedObject: CDMessage) {
        managedObject.id = entity.id
        managedObject.conversationId = entity.conversationId
        managedObject.legacyConversationId = entity.legacyConversationId
        managedObject.senderType = entity.senderType.rawValue
        managedObject.content = entity.content
        managedObject.metadataData = try? JSONEncoder().encode(entity.metadata)
        managedObject.isDeleted = entity.isDeleted
        managedObject.deletedAt = entity.deletedAt
        managedObject.isEdited = entity.isEdited
        managedObject.editedAt = entity.editedAt
        managedObject.tokensUsed = Int32(entity.tokensUsed ?? 0)
        managedObject.modelUsed = entity.modelUsed
        managedObject.responseTimeMs = Int32(entity.responseTimeMs ?? 0)
        managedObject.createdAt = entity.createdAt
        managedObject.syncStatus = SyncStatus.pendingSync.rawValue
    }

    public override func createManagedObject(from entity: Message, in context: NSManagedObjectContext) -> CDMessage {
        let managedObject = CDMessage(context: context)
        toManagedObject(entity, managedObject: managedObject)
        managedObject.syncStatus = SyncStatus.pending.rawValue
        return managedObject
    }

    // MARK: - Custom Queries

    /// Fetch messages for conversation
    public func fetch(byConversationId conversationId: UUID, excludeDeleted: Bool = true) async throws -> [Message] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDMessage.fetchRequest(byConversationId: conversationId, excludeDeleted: excludeDeleted)
            let managedObjects = try context.fetch(request)
            return managedObjects.map { self.toDomain($0) }
        }
    }

    /// Fetch recent messages for conversation
    public func fetchRecent(conversationId: UUID, limit: Int) async throws -> [Message] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDMessage.fetchRequest(recentMessages: limit, conversationId: conversationId)
            let managedObjects = try context.fetch(request)
            // Reverse to get chronological order
            return managedObjects.reversed().map { self.toDomain($0) }
        }
    }

    /// Soft delete message
    public func softDelete(messageId: UUID) async throws -> Message {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDMessage.fetchRequest(byId: messageId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(messageId)
            }

            managedObject.softDelete()
            return self.toDomain(managedObject)
        }
    }

    /// Edit message content
    public func edit(messageId: UUID, newContent: String) async throws -> Message {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDMessage.fetchRequest(byId: messageId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(messageId)
            }

            managedObject.edit(newContent: newContent)
            return self.toDomain(managedObject)
        }
    }

    /// Search messages by content
    public func search(query: String, conversationId: UUID? = nil) async throws -> [Message] {
        var predicates: [NSPredicate] = [
            NSPredicate(format: "content CONTAINS[cd] %@", query),
            NSPredicate(format: "isDeleted == NO")
        ]

        if let conversationId = conversationId {
            predicates.append(NSPredicate(format: "conversationId == %@", conversationId as CVarArg))
        }

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        return try await fetchAll(options: FetchOptions(
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
            predicate: predicate
        ))
    }

    /// Count messages in conversation
    public func count(conversationId: UUID) async throws -> Int {
        let predicate = NSPredicate(
            format: "conversationId == %@ AND isDeleted == NO",
            conversationId as CVarArg
        )
        return try await count(predicate: predicate)
    }

    /// Delete all messages for conversation
    public func deleteAll(forConversationId conversationId: UUID) async throws {
        let predicate = NSPredicate(format: "conversationId == %@", conversationId as CVarArg)
        try await deleteWhere(predicate: predicate)
    }

    /// Fetch messages by sender type
    public func fetch(bySenderType senderType: SenderType, conversationId: UUID) async throws -> [Message] {
        let predicate = NSPredicate(
            format: "conversationId == %@ AND senderType == %@ AND isDeleted == NO",
            conversationId as CVarArg, senderType.rawValue
        )
        return try await fetchAll(options: FetchOptions(
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)],
            predicate: predicate
        ))
    }

    /// Get total tokens used in conversation
    public func totalTokensUsed(conversationId: UUID) async throws -> Int {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard self != nil else { throw RepositoryError.contextNotAvailable }

            let request = NSFetchRequest<CDMessage>(entityName: "CDMessage")
            request.predicate = NSPredicate(
                format: "conversationId == %@ AND isDeleted == NO",
                conversationId as CVarArg
            )

            let messages = try context.fetch(request)
            return messages.reduce(0) { $0 + Int($1.tokensUsed) }
        }
    }
}
