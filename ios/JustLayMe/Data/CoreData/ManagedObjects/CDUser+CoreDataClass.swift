import Foundation
import CoreData

@objc(CDUser)
public class CDUser: NSManagedObject {

    // MARK: - Fetch Requests

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDUser> {
        return NSFetchRequest<CDUser>(entityName: "CDUser")
    }

    @nonobjc public class func fetchRequest(byId id: UUID) -> NSFetchRequest<CDUser> {
        let request = NSFetchRequest<CDUser>(entityName: "CDUser")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchRequest(byEmail email: String) -> NSFetchRequest<CDUser> {
        let request = NSFetchRequest<CDUser>(entityName: "CDUser")
        request.predicate = NSPredicate(format: "email == %@", email)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchRequest(unsynced: Bool) -> NSFetchRequest<CDUser> {
        let request = NSFetchRequest<CDUser>(entityName: "CDUser")
        request.predicate = NSPredicate(format: "syncStatus != %d", SyncStatus.synced.rawValue)
        return request
    }

    // MARK: - Properties

    @NSManaged public var id: UUID?
    @NSManaged public var email: String?
    @NSManaged public var name: String?
    @NSManaged public var passwordHash: String?
    @NSManaged public var googleId: String?
    @NSManaged public var subscriptionStatus: String?
    @NSManaged public var subscriptionEnd: Date?
    @NSManaged public var messageCount: Int32
    @NSManaged public var emailVerified: Bool
    @NSManaged public var verificationToken: String?
    @NSManaged public var verificationExpires: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var lastLogin: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var avatarStyle: String?
    @NSManaged public var themePreference: String?
    @NSManaged public var syncStatus: Int16
    @NSManaged public var lastSyncedAt: Date?

    // MARK: - Relationships

    @NSManaged public var characters: NSSet?
    @NSManaged public var conversations: NSSet?
    @NSManaged public var verificationLogs: NSSet?

    // MARK: - Computed Properties

    public var subscriptionStatusEnum: SubscriptionStatus {
        get { SubscriptionStatus(rawValue: subscriptionStatus ?? "free") ?? .free }
        set { subscriptionStatus = newValue.rawValue }
    }

    public var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }

    public var isPremium: Bool {
        guard let status = subscriptionStatus else { return false }
        return status != "free"
    }

    public var isSubscriptionActive: Bool {
        guard isPremium else { return false }
        if subscriptionStatus == "lifetime" { return true }
        guard let endDate = subscriptionEnd else { return false }
        return endDate > Date()
    }

    public var charactersArray: [CDCharacter] {
        (characters?.allObjects as? [CDCharacter]) ?? []
    }

    public var conversationsArray: [CDConversation] {
        (conversations?.allObjects as? [CDConversation]) ?? []
    }

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        subscriptionStatus = "free"
        messageCount = 0
        emailVerified = false
        syncStatus = SyncStatus.pending.rawValue
    }

    public override func willSave() {
        super.willSave()
        if !isDeleted {
            updatedAt = Date()
        }
    }
}

// MARK: - Generated Accessors

extension CDUser {
    @objc(addCharactersObject:)
    @NSManaged public func addToCharacters(_ value: CDCharacter)

    @objc(removeCharactersObject:)
    @NSManaged public func removeFromCharacters(_ value: CDCharacter)

    @objc(addCharacters:)
    @NSManaged public func addToCharacters(_ values: NSSet)

    @objc(removeCharacters:)
    @NSManaged public func removeFromCharacters(_ values: NSSet)

    @objc(addConversationsObject:)
    @NSManaged public func addToConversations(_ value: CDConversation)

    @objc(removeConversationsObject:)
    @NSManaged public func removeFromConversations(_ value: CDConversation)

    @objc(addConversations:)
    @NSManaged public func addToConversations(_ values: NSSet)

    @objc(removeConversations:)
    @NSManaged public func removeFromConversations(_ values: NSSet)

    @objc(addVerificationLogsObject:)
    @NSManaged public func addToVerificationLogs(_ value: CDEmailVerificationLog)

    @objc(removeVerificationLogsObject:)
    @NSManaged public func removeFromVerificationLogs(_ value: CDEmailVerificationLog)
}
