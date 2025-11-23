import Foundation
import CoreData

@objc(CDCharacterMemory)
public class CDCharacterMemory: NSManagedObject {

    // MARK: - Fetch Requests

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDCharacterMemory> {
        return NSFetchRequest<CDCharacterMemory>(entityName: "CDCharacterMemory")
    }

    @nonobjc public class func fetchRequest(byId id: UUID) -> NSFetchRequest<CDCharacterMemory> {
        let request = NSFetchRequest<CDCharacterMemory>(entityName: "CDCharacterMemory")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchRequest(byCharacterId characterId: UUID) -> NSFetchRequest<CDCharacterMemory> {
        let request = NSFetchRequest<CDCharacterMemory>(entityName: "CDCharacterMemory")
        request.predicate = NSPredicate(format: "characterId == %@", characterId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return request
    }

    @nonobjc public class func fetchRequest(highImportance threshold: Double, characterId: UUID) -> NSFetchRequest<CDCharacterMemory> {
        let request = NSFetchRequest<CDCharacterMemory>(entityName: "CDCharacterMemory")
        request.predicate = NSPredicate(format: "characterId == %@ AND importanceScore >= %f", characterId as CVarArg, threshold)
        request.sortDescriptors = [NSSortDescriptor(key: "importanceScore", ascending: false)]
        return request
    }

    @nonobjc public class func fetchRequest(withFeedback characterId: UUID) -> NSFetchRequest<CDCharacterMemory> {
        let request = NSFetchRequest<CDCharacterMemory>(entityName: "CDCharacterMemory")
        request.predicate = NSPredicate(format: "characterId == %@ AND feedbackScore != nil", characterId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return request
    }

    // MARK: - Properties

    @NSManaged public var id: UUID?
    @NSManaged public var characterId: UUID?
    @NSManaged public var userMessage: String?
    @NSManaged public var aiResponse: String?
    @NSManaged public var feedbackScore: NSNumber?
    @NSManaged public var correctedResponse: String?
    @NSManaged public var importanceScore: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var syncStatus: Int16

    // MARK: - Relationships

    @NSManaged public var character: CDCharacter?

    // MARK: - Computed Properties

    public var feedbackScoreValue: Int? {
        get { feedbackScore?.intValue }
        set { feedbackScore = newValue.map { NSNumber(value: $0) } }
    }

    public var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }

    public var hasFeedback: Bool {
        feedbackScore != nil
    }

    public var hasCorrection: Bool {
        correctedResponse != nil && !correctedResponse!.isEmpty
    }

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        importanceScore = 0.5
        syncStatus = SyncStatus.pending.rawValue
    }

    // MARK: - Methods

    public func applyFeedback(score: Int, correctedResponse: String? = nil) {
        feedbackScoreValue = max(1, min(5, score)) // Clamp to 1-5
        self.correctedResponse = correctedResponse

        // Adjust importance based on feedback
        if score >= 4 {
            importanceScore = min(1.0, importanceScore + 0.1)
        } else if score <= 2 {
            importanceScore = max(0.0, importanceScore - 0.1)
        }

        syncStatus = SyncStatus.pendingSync.rawValue
    }
}
