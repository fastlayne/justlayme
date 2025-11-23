import Foundation
import SwiftData

// MARK: - Conversation Entity
/// SwiftData persistent model for Conversation

@Model
final class ConversationEntity {
    // MARK: - Properties

    @Attribute(.unique)
    var id: String

    var userId: String
    var modelType: String
    var title: String?
    var messageCount: Int
    var isArchived: Bool
    var tags: [String]?
    var createdAt: Date
    var updatedAt: Date
    var lastSyncedAt: Date?

    // Local-only flags
    var needsSync: Bool
    var isLocalOnly: Bool

    // MARK: - Relationships

    var user: UserEntity?

    @Relationship(deleteRule: .cascade, inverse: \MessageEntity.conversation)
    var messages: [MessageEntity]?

    @Relationship(inverse: \ConversationTagEntity.conversations)
    var tagEntities: [ConversationTagEntity]?

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        userId: String,
        modelType: String,
        title: String? = nil,
        messageCount: Int = 0,
        isArchived: Bool = false,
        tags: [String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        needsSync: Bool = true,
        isLocalOnly: Bool = false
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
        self.needsSync = needsSync
        self.isLocalOnly = isLocalOnly
        self.lastSyncedAt = Date()
    }

    // MARK: - Conversion

    /// Convert from API model
    convenience init(from conversation: Conversation) {
        self.init(
            id: conversation.id,
            userId: conversation.userId,
            modelType: conversation.modelType.rawValue,
            title: conversation.title,
            messageCount: conversation.messageCount,
            isArchived: conversation.isArchived,
            tags: conversation.tags,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            needsSync: false,
            isLocalOnly: false
        )
    }

    /// Convert to API model
    func toModel() -> Conversation {
        return Conversation(
            id: id,
            userId: userId,
            modelType: ModelType(rawValue: modelType) ?? .laymeV1,
            title: title,
            messageCount: messageCount,
            isArchived: isArchived,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastMessagePreview: lastMessagePreview,
            lastMessageTime: lastMessageTime
        )
    }

    // MARK: - Computed Properties

    /// Get the last message preview
    var lastMessagePreview: String? {
        return messages?.sorted(by: { $0.createdAt > $1.createdAt }).first?.content
    }

    /// Get the last message time
    var lastMessageTime: Date? {
        return messages?.sorted(by: { $0.createdAt > $1.createdAt }).first?.createdAt
    }

    /// Display title with fallback
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        return ModelType(rawValue: modelType)?.displayName ?? "Chat"
    }

    /// Sorted messages
    var sortedMessages: [MessageEntity] {
        return (messages ?? []).sorted(by: { $0.createdAt < $1.createdAt })
    }

    /// Total message count from actual messages
    var actualMessageCount: Int {
        return messages?.count ?? 0
    }

    // MARK: - Methods

    /// Update the message count and updated timestamp
    func updateStats() {
        self.messageCount = actualMessageCount
        self.updatedAt = Date()
        self.needsSync = true
    }

    /// Mark as needing sync
    func markForSync() {
        self.needsSync = true
        self.updatedAt = Date()
    }

    /// Mark as synced
    func markAsSynced() {
        self.needsSync = false
        self.lastSyncedAt = Date()
    }
}

// MARK: - Fetch Descriptors
extension ConversationEntity {

    /// Fetch descriptor for all conversations for a user
    static func fetchDescriptor(
        userId: String,
        isArchived: Bool = false,
        modelType: ModelType? = nil
    ) -> FetchDescriptor<ConversationEntity> {
        var predicates: [Predicate<ConversationEntity>] = [
            #Predicate { $0.userId == userId },
            #Predicate { $0.isArchived == isArchived }
        ]

        if let modelType = modelType {
            let modelTypeString = modelType.rawValue
            predicates.append(#Predicate { $0.modelType == modelTypeString })
        }

        let combinedPredicate = predicates.reduce(#Predicate<ConversationEntity> { _ in true }) { result, next in
            #Predicate { entity in
                result.evaluate(entity) && next.evaluate(entity)
            }
        }

        var descriptor = FetchDescriptor<ConversationEntity>(predicate: combinedPredicate)
        descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        return descriptor
    }

    /// Fetch descriptor for conversations needing sync
    static func needsSyncDescriptor() -> FetchDescriptor<ConversationEntity> {
        let predicate = #Predicate<ConversationEntity> { $0.needsSync == true }
        return FetchDescriptor<ConversationEntity>(predicate: predicate)
    }
}
