import Foundation
import SwiftData

// MARK: - Message Entity
/// SwiftData persistent model for Message

@Model
final class MessageEntity {
    // MARK: - Properties

    @Attribute(.unique)
    var id: String

    var conversationId: String
    var senderType: String
    var content: String
    var isDeleted: Bool
    var createdAt: Date

    // Metadata stored as JSON
    var metadataJSON: Data?

    // Local-only flags
    var needsSync: Bool
    var isLocalOnly: Bool
    var isSending: Bool
    var sendError: String?

    // MARK: - Relationship

    var conversation: ConversationEntity?

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        conversationId: String,
        senderType: String,
        content: String,
        isDeleted: Bool = false,
        createdAt: Date = Date(),
        metadata: MessageMetadata? = nil,
        needsSync: Bool = true,
        isLocalOnly: Bool = false,
        isSending: Bool = false,
        sendError: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderType = senderType
        self.content = content
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.needsSync = needsSync
        self.isLocalOnly = isLocalOnly
        self.isSending = isSending
        self.sendError = sendError

        if let metadata = metadata {
            self.metadataJSON = try? JSONEncoder().encode(metadata)
        }
    }

    // MARK: - Conversion

    /// Convert from API model
    convenience init(from message: Message) {
        self.init(
            id: message.id,
            conversationId: message.conversationId,
            senderType: message.senderType.rawValue,
            content: message.content,
            isDeleted: message.isDeleted,
            createdAt: message.createdAt,
            metadata: message.metadata,
            needsSync: false,
            isLocalOnly: false
        )
    }

    /// Convert to API model
    func toModel() -> Message {
        return Message(
            id: id,
            conversationId: conversationId,
            senderType: SenderType(rawValue: senderType) ?? .human,
            content: content,
            metadata: metadata,
            isDeleted: isDeleted,
            createdAt: createdAt
        )
    }

    // MARK: - Computed Properties

    /// Decoded metadata
    var metadata: MessageMetadata? {
        guard let data = metadataJSON else { return nil }
        return try? JSONDecoder().decode(MessageMetadata.self, from: data)
    }

    /// Set metadata
    func setMetadata(_ metadata: MessageMetadata?) {
        if let metadata = metadata {
            self.metadataJSON = try? JSONEncoder().encode(metadata)
        } else {
            self.metadataJSON = nil
        }
    }

    /// Check if this is a user message
    var isUserMessage: Bool {
        return senderType == SenderType.human.rawValue
    }

    /// Get display name for sender
    var displaySenderName: String {
        if isUserMessage {
            return "You"
        }
        return metadata?.characterName ?? "AI"
    }

    /// Formatted timestamp
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Convert to ChatMessage for UI
    func toChatMessage() -> ChatMessage {
        return ChatMessage(
            id: id,
            content: content,
            isUser: isUserMessage,
            timestamp: createdAt,
            isLoading: isSending,
            error: sendError
        )
    }

    // MARK: - Methods

    /// Mark as synced
    func markAsSynced() {
        self.needsSync = false
        self.isSending = false
        self.sendError = nil
    }

    /// Mark send error
    func markSendError(_ error: String) {
        self.isSending = false
        self.sendError = error
        self.needsSync = true
    }
}

// MARK: - Fetch Descriptors
extension MessageEntity {

    /// Fetch descriptor for messages in a conversation
    static func fetchDescriptor(
        conversationId: String,
        includeDeleted: Bool = false
    ) -> FetchDescriptor<MessageEntity> {
        let predicate: Predicate<MessageEntity>

        if includeDeleted {
            predicate = #Predicate { $0.conversationId == conversationId }
        } else {
            predicate = #Predicate { $0.conversationId == conversationId && $0.isDeleted == false }
        }

        var descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
        return descriptor
    }

    /// Fetch descriptor for messages needing sync
    static func needsSyncDescriptor() -> FetchDescriptor<MessageEntity> {
        let predicate = #Predicate<MessageEntity> { $0.needsSync == true }
        return FetchDescriptor<MessageEntity>(predicate: predicate)
    }

    /// Fetch descriptor for messages with send errors
    static func withErrorsDescriptor() -> FetchDescriptor<MessageEntity> {
        let predicate = #Predicate<MessageEntity> { $0.sendError != nil }
        return FetchDescriptor<MessageEntity>(predicate: predicate)
    }
}
