import Foundation
import CoreData

@objc(CDCharacter)
public class CDCharacter: NSManagedObject {

    // MARK: - Fetch Requests

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDCharacter> {
        return NSFetchRequest<CDCharacter>(entityName: "CDCharacter")
    }

    @nonobjc public class func fetchRequest(byId id: UUID) -> NSFetchRequest<CDCharacter> {
        let request = NSFetchRequest<CDCharacter>(entityName: "CDCharacter")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchRequest(byUserId userId: UUID) -> NSFetchRequest<CDCharacter> {
        let request = NSFetchRequest<CDCharacter>(entityName: "CDCharacter")
        request.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return request
    }

    @nonobjc public class func fetchRequest(publicOnly: Bool) -> NSFetchRequest<CDCharacter> {
        let request = NSFetchRequest<CDCharacter>(entityName: "CDCharacter")
        if publicOnly {
            request.predicate = NSPredicate(format: "isPublic == YES")
        }
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return request
    }

    // MARK: - Properties

    @NSManaged public var id: UUID?
    @NSManaged public var userId: UUID?
    @NSManaged public var name: String?
    @NSManaged public var backstory: String?
    @NSManaged public var personalityTraitsData: Data?
    @NSManaged public var speechPatternsData: Data?
    @NSManaged public var avatarUrl: String?
    @NSManaged public var isPublic: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var syncStatus: Int16
    @NSManaged public var lastSyncedAt: Date?

    // MARK: - Relationships

    @NSManaged public var user: CDUser?
    @NSManaged public var memories: NSSet?
    @NSManaged public var learningPatterns: NSSet?

    // MARK: - Computed Properties

    public var personalityTraits: [String: Any] {
        get {
            guard let data = personalityTraitsData else { return [:] }
            return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
        set {
            personalityTraitsData = try? JSONSerialization.data(withJSONObject: newValue)
        }
    }

    public var speechPatterns: [String] {
        get {
            guard let data = speechPatternsData else { return [] }
            return (try? JSONSerialization.jsonObject(with: data) as? [String]) ?? []
        }
        set {
            speechPatternsData = try? JSONSerialization.data(withJSONObject: newValue)
        }
    }

    public var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }

    public var memoriesArray: [CDCharacterMemory] {
        (memories?.allObjects as? [CDCharacterMemory]) ?? []
    }

    public var learningPatternsArray: [CDCharacterLearning] {
        (learningPatterns?.allObjects as? [CDCharacterLearning]) ?? []
    }

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        isPublic = false
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

extension CDCharacter {
    @objc(addMemoriesObject:)
    @NSManaged public func addToMemories(_ value: CDCharacterMemory)

    @objc(removeMemoriesObject:)
    @NSManaged public func removeFromMemories(_ value: CDCharacterMemory)

    @objc(addMemories:)
    @NSManaged public func addToMemories(_ values: NSSet)

    @objc(removeMemories:)
    @NSManaged public func removeFromMemories(_ values: NSSet)

    @objc(addLearningPatternsObject:)
    @NSManaged public func addToLearningPatterns(_ value: CDCharacterLearning)

    @objc(removeLearningPatternsObject:)
    @NSManaged public func removeFromLearningPatterns(_ value: CDCharacterLearning)

    @objc(addLearningPatterns:)
    @NSManaged public func addToLearningPatterns(_ values: NSSet)

    @objc(removeLearningPatterns:)
    @NSManaged public func removeFromLearningPatterns(_ values: NSSet)
}
