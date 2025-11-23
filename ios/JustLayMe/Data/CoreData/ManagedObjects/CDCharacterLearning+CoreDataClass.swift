import Foundation
import CoreData

@objc(CDCharacterLearning)
public class CDCharacterLearning: NSManagedObject {

    // MARK: - Fetch Requests

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDCharacterLearning> {
        return NSFetchRequest<CDCharacterLearning>(entityName: "CDCharacterLearning")
    }

    @nonobjc public class func fetchRequest(byId id: UUID) -> NSFetchRequest<CDCharacterLearning> {
        let request = NSFetchRequest<CDCharacterLearning>(entityName: "CDCharacterLearning")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchRequest(byCharacterId characterId: UUID) -> NSFetchRequest<CDCharacterLearning> {
        let request = NSFetchRequest<CDCharacterLearning>(entityName: "CDCharacterLearning")
        request.predicate = NSPredicate(format: "characterId == %@", characterId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "confidence", ascending: false)]
        return request
    }

    @nonobjc public class func fetchRequest(byPatternType type: PatternType, characterId: UUID) -> NSFetchRequest<CDCharacterLearning> {
        let request = NSFetchRequest<CDCharacterLearning>(entityName: "CDCharacterLearning")
        request.predicate = NSPredicate(format: "characterId == %@ AND patternType == %@", characterId as CVarArg, type.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "confidence", ascending: false)]
        return request
    }

    @nonobjc public class func fetchRequest(highConfidence threshold: Double, characterId: UUID) -> NSFetchRequest<CDCharacterLearning> {
        let request = NSFetchRequest<CDCharacterLearning>(entityName: "CDCharacterLearning")
        request.predicate = NSPredicate(format: "characterId == %@ AND confidence >= %f", characterId as CVarArg, threshold)
        request.sortDescriptors = [NSSortDescriptor(key: "confidence", ascending: false)]
        return request
    }

    // MARK: - Properties

    @NSManaged public var id: UUID?
    @NSManaged public var characterId: UUID?
    @NSManaged public var patternType: String?
    @NSManaged public var userInput: String?
    @NSManaged public var expectedOutput: String?
    @NSManaged public var confidence: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var syncStatus: Int16

    // MARK: - Relationships

    @NSManaged public var character: CDCharacter?

    // MARK: - Computed Properties

    public var patternTypeEnum: PatternType {
        get { PatternType(rawValue: patternType ?? "") ?? .speech }
        set { patternType = newValue.rawValue }
    }

    public var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }

    public var isHighConfidence: Bool {
        confidence >= 0.8
    }

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        confidence = 1.0
        patternType = PatternType.speech.rawValue
        syncStatus = SyncStatus.pending.rawValue
    }

    // MARK: - Methods

    public func adjustConfidence(by delta: Double) {
        confidence = max(0.0, min(1.0, confidence + delta))
        syncStatus = SyncStatus.pendingSync.rawValue
    }

    public func reinforce() {
        adjustConfidence(by: 0.05)
    }

    public func weaken() {
        adjustConfidence(by: -0.1)
    }
}

// MARK: - Pattern Type

public enum PatternType: String, Codable, CaseIterable {
    case speech
    case behavior
    case personality

    public var displayName: String {
        switch self {
        case .speech: return "Speech Pattern"
        case .behavior: return "Behavior"
        case .personality: return "Personality Trait"
        }
    }
}
