import Foundation
import CoreData

@objc(CDCacheEntry)
public class CDCacheEntry: NSManagedObject {

    // MARK: - Fetch Requests

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDCacheEntry> {
        return NSFetchRequest<CDCacheEntry>(entityName: "CDCacheEntry")
    }

    @nonobjc public class func fetchRequest(byKey key: String) -> NSFetchRequest<CDCacheEntry> {
        let request = NSFetchRequest<CDCacheEntry>(entityName: "CDCacheEntry")
        request.predicate = NSPredicate(format: "key == %@", key)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchRequest(byEntityType type: String) -> NSFetchRequest<CDCacheEntry> {
        let request = NSFetchRequest<CDCacheEntry>(entityName: "CDCacheEntry")
        request.predicate = NSPredicate(format: "entityType == %@", type)
        request.sortDescriptors = [NSSortDescriptor(key: "lastAccessedAt", ascending: false)]
        return request
    }

    @nonobjc public class func fetchRequest(expired: Bool) -> NSFetchRequest<CDCacheEntry> {
        let request = NSFetchRequest<CDCacheEntry>(entityName: "CDCacheEntry")
        request.predicate = NSPredicate(format: "expiresAt < %@", Date() as NSDate)
        return request
    }

    @nonobjc public class func fetchRequest(leastRecentlyUsed limit: Int) -> NSFetchRequest<CDCacheEntry> {
        let request = NSFetchRequest<CDCacheEntry>(entityName: "CDCacheEntry")
        request.sortDescriptors = [NSSortDescriptor(key: "lastAccessedAt", ascending: true)]
        request.fetchLimit = limit
        return request
    }

    // MARK: - Properties

    @NSManaged public var key: String?
    @NSManaged public var data: Data?
    @NSManaged public var entityType: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var expiresAt: Date?
    @NSManaged public var lastAccessedAt: Date?
    @NSManaged public var accessCount: Int32
    @NSManaged public var sizeBytes: Int64

    // MARK: - Computed Properties

    public var isExpired: Bool {
        guard let expires = expiresAt else { return true }
        return expires < Date()
    }

    public var isValid: Bool {
        !isExpired && data != nil
    }

    public var age: TimeInterval {
        guard let created = createdAt else { return 0 }
        return Date().timeIntervalSince(created)
    }

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        createdAt = Date()
        lastAccessedAt = Date()
        accessCount = 0
        sizeBytes = 0
    }

    // MARK: - Methods

    public func recordAccess() {
        lastAccessedAt = Date()
        accessCount += 1
    }

    public func updateData(_ newData: Data, expiresIn duration: TimeInterval) {
        data = newData
        sizeBytes = Int64(newData.count)
        expiresAt = Date().addingTimeInterval(duration)
        lastAccessedAt = Date()
    }

    public func extendExpiration(by duration: TimeInterval) {
        guard let currentExpiry = expiresAt else {
            expiresAt = Date().addingTimeInterval(duration)
            return
        }
        expiresAt = currentExpiry.addingTimeInterval(duration)
    }
}
