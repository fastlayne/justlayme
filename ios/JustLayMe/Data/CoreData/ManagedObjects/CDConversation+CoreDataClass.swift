import Foundation
import CoreData

@objc(CDConversation)
public class CDConversation: NSManagedObject {

    // MARK: - Fetch Requests

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDConversation> {
        return NSFetchRequest<CDConversation>(entityName: "CDConversation")
    }

    @nonobjc public class func fetchRequest(byId id: UUID) -> NSFetchRequest<CDConversation> {
        let request = NSFetchRequest<CDConversation>(entityName: "CDConversation")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchRequest(byUserId userId: UUID, includeArchived: Bool = false) -> NSFetchRequest<CDConversation> {
        let request = NSFetchRequest<CDConversation>(entityName: "CDConversation")
        var predicates = [NSPredicate(format: "userId == %@", userId as CVarArg)]
        if !includeArchived {
            predicates.append(NSPredicate(format: "isArchived == NO"))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "lastMessageAt", ascending: false)]
        return request
    }

    @nonobjc public class func fetchRequest(byModelType modelType: String) -> NSFetchRequest<CDConversation> {
        let request = NSFetchRequest<CDConversation>(entityName: "CDConversation")
        request.predicate = NSPredicate(format: "modelType == %@", modelType)
        request.sortDescriptors = [NSSortDescriptor(key: "lastMessageAt", ascending: false)]
        return request
    }

    @nonobjc public class func fetchRequest(withTag tag: String) -> NSFetchRequest<CDConversation> {
        let request = NSFetchRequest<CDConversation>(entityName: "CDConversation")
        request.predicate = NSPredicate(format: "ANY tags == %@", tag)
        return request
    }

    // MARK: - Properties

    @NSManaged public var id: UUID?
    @NSManaged public var userId: UUID?
    @NSManaged public var modelType: String?
    @NSManaged public var title: String?
    @NSManaged public var messageCount: Int32
    @NSManaged public var isArchived: Bool
    @NSManaged public var tagsData: Data?
    @NSManaged public var metadataData: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var lastMessageAt: Date?
    @NSManaged public var syncStatus: Int16
    @NSManaged public var lastSyncedAt: Date?

    // MARK: - Relationships

    @NSManaged public var user: CDUser?
    @NSManaged public var messages: NSSet?

    // MARK: - Computed Properties

    public var tags: [String] {
        get {
            guard let data = tagsData else { return [] }
            return (try? JSONSerialization.jsonObject(with: data) as? [String]) ?? []
        }
        set {
            tagsData = try? JSONSerialization.data(withJSONObject: newValue)
        }
    }

    public var metadata: [String: Any] {
        get {
            guard let data = metadataData else { return [:] }
            return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
        set {
            metadataData = try? JSONSerialization.data(withJSONObject: newValue)
        }
    }

    public var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }

    public var modelTypeEnum: ModelType {
        get { ModelType(rawValue: modelType ?? "") ?? .layme_v1 }
        set { modelType = newValue.rawValue }
    }

    public var messagesArray: [CDMessage] {
        let array = (messages?.allObjects as? [CDMessage]) ?? []
        return array.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    public var lastMessage: CDMessage? {
        messagesArray.last
    }

    public var lastMessagePreview: String? {
        guard let content = lastMessage?.content else { return nil }
        return String(content.prefix(100))
    }

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        lastMessageAt = Date()
        messageCount = 0
        isArchived = false
        syncStatus = SyncStatus.pending.rawValue
    }

    public override func willSave() {
        super.willSave()
        if !isDeleted {
            updatedAt = Date()
        }
    }

    // MARK: - Helper Methods

    public func incrementMessageCount() {
        messageCount += 1
        lastMessageAt = Date()
    }

    public func generateTitle(from firstMessage: String) {
        let maxLength = 50
        if firstMessage.count > maxLength {
            title = String(firstMessage.prefix(maxLength)) + "..."
        } else {
            title = firstMessage
        }
    }
}

// MARK: - Generated Accessors

extension CDConversation {
    @objc(addMessagesObject:)
    @NSManaged public func addToMessages(_ value: CDMessage)

    @objc(removeMessagesObject:)
    @NSManaged public func removeFromMessages(_ value: CDMessage)

    @objc(addMessages:)
    @NSManaged public func addToMessages(_ values: NSSet)

    @objc(removeMessages:)
    @NSManaged public func removeFromMessages(_ values: NSSet)
}
