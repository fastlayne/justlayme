import Foundation
import CoreData

@objc(CDMessage)
public class CDMessage: NSManagedObject {

    // MARK: - Fetch Requests

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDMessage> {
        return NSFetchRequest<CDMessage>(entityName: "CDMessage")
    }

    @nonobjc public class func fetchRequest(byId id: UUID) -> NSFetchRequest<CDMessage> {
        let request = NSFetchRequest<CDMessage>(entityName: "CDMessage")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchRequest(byConversationId conversationId: UUID, excludeDeleted: Bool = true) -> NSFetchRequest<CDMessage> {
        let request = NSFetchRequest<CDMessage>(entityName: "CDMessage")
        var predicates = [NSPredicate(format: "conversationId == %@", conversationId as CVarArg)]
        if excludeDeleted {
            predicates.append(NSPredicate(format: "isDeleted == NO"))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }

    @nonobjc public class func fetchRequest(recentMessages limit: Int, conversationId: UUID) -> NSFetchRequest<CDMessage> {
        let request = NSFetchRequest<CDMessage>(entityName: "CDMessage")
        request.predicate = NSPredicate(format: "conversationId == %@ AND isDeleted == NO", conversationId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = limit
        return request
    }

    // MARK: - Properties

    @NSManaged public var id: UUID?
    @NSManaged public var conversationId: UUID?
    @NSManaged public var legacyConversationId: String?
    @NSManaged public var senderType: String?
    @NSManaged public var content: String?
    @NSManaged public var metadataData: Data?
    @NSManaged public var isDeleted: Bool
    @NSManaged public var deletedAt: Date?
    @NSManaged public var isEdited: Bool
    @NSManaged public var editedAt: Date?
    @NSManaged public var tokensUsed: Int32
    @NSManaged public var modelUsed: String?
    @NSManaged public var responseTimeMs: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var syncStatus: Int16

    // MARK: - Relationships

    @NSManaged public var conversation: CDConversation?

    // MARK: - Computed Properties

    public var metadata: MessageMetadata {
        get {
            guard let data = metadataData else { return MessageMetadata() }
            return (try? JSONDecoder().decode(MessageMetadata.self, from: data)) ?? MessageMetadata()
        }
        set {
            metadataData = try? JSONEncoder().encode(newValue)
        }
    }

    public var senderTypeEnum: SenderType {
        get { SenderType(rawValue: senderType ?? "") ?? .human }
        set { senderType = newValue.rawValue }
    }

    public var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }

    public var isFromUser: Bool {
        senderTypeEnum == .human
    }

    public var senderName: String {
        if isFromUser {
            return "You"
        }
        return metadata.characterName ?? modelUsed ?? "AI"
    }

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        isDeleted = false
        isEdited = false
        syncStatus = SyncStatus.pending.rawValue
    }

    // MARK: - Methods

    public func softDelete() {
        isDeleted = true
        deletedAt = Date()
        syncStatus = SyncStatus.pendingSync.rawValue
    }

    public func edit(newContent: String) {
        content = newContent
        isEdited = true
        editedAt = Date()
        syncStatus = SyncStatus.pendingSync.rawValue
    }
}

// MARK: - Message Metadata

public struct MessageMetadata: Codable {
    public var characterId: String?
    public var model: String?
    public var customized: Bool?
    public var modelType: String?
    public var characterName: String?

    public init(
        characterId: String? = nil,
        model: String? = nil,
        customized: Bool? = nil,
        modelType: String? = nil,
        characterName: String? = nil
    ) {
        self.characterId = characterId
        self.model = model
        self.customized = customized
        self.modelType = modelType
        self.characterName = characterName
    }
}

// MARK: - Sender Type

public enum SenderType: String, Codable {
    case human
    case ai
}
