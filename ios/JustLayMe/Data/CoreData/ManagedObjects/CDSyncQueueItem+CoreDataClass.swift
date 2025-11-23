import Foundation
import CoreData

@objc(CDSyncQueueItem)
public class CDSyncQueueItem: NSManagedObject {

    // MARK: - Fetch Requests

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDSyncQueueItem> {
        return NSFetchRequest<CDSyncQueueItem>(entityName: "CDSyncQueueItem")
    }

    @nonobjc public class func fetchRequest(pending: Bool) -> NSFetchRequest<CDSyncQueueItem> {
        let request = NSFetchRequest<CDSyncQueueItem>(entityName: "CDSyncQueueItem")
        request.predicate = NSPredicate(format: "status == %@", QueueItemStatus.pending.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        return request
    }

    @nonobjc public class func fetchRequest(byEntityType type: String) -> NSFetchRequest<CDSyncQueueItem> {
        let request = NSFetchRequest<CDSyncQueueItem>(entityName: "CDSyncQueueItem")
        request.predicate = NSPredicate(format: "entityType == %@", type)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }

    @nonobjc public class func fetchRequest(failed: Bool) -> NSFetchRequest<CDSyncQueueItem> {
        let request = NSFetchRequest<CDSyncQueueItem>(entityName: "CDSyncQueueItem")
        request.predicate = NSPredicate(format: "status == %@", QueueItemStatus.failed.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }

    @nonobjc public class func fetchRequest(retryable: Bool) -> NSFetchRequest<CDSyncQueueItem> {
        let request = NSFetchRequest<CDSyncQueueItem>(entityName: "CDSyncQueueItem")
        request.predicate = NSPredicate(format: "status == %@ AND retryCount < maxRetries", QueueItemStatus.failed.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }

    // MARK: - Properties

    @NSManaged public var id: UUID?
    @NSManaged public var entityType: String?
    @NSManaged public var entityId: UUID?
    @NSManaged public var operation: String?
    @NSManaged public var payloadData: Data?
    @NSManaged public var retryCount: Int16
    @NSManaged public var maxRetries: Int16
    @NSManaged public var priority: Int16
    @NSManaged public var status: String?
    @NSManaged public var errorMessage: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var scheduledAt: Date?
    @NSManaged public var processedAt: Date?

    // MARK: - Computed Properties

    public var payload: [String: Any] {
        get {
            guard let data = payloadData else { return [:] }
            return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
        set {
            payloadData = try? JSONSerialization.data(withJSONObject: newValue)
        }
    }

    public var operationEnum: SyncOperation {
        get { SyncOperation(rawValue: operation ?? "") ?? .create }
        set { operation = newValue.rawValue }
    }

    public var statusEnum: QueueItemStatus {
        get { QueueItemStatus(rawValue: status ?? "") ?? .pending }
        set { status = newValue.rawValue }
    }

    public var canRetry: Bool {
        retryCount < maxRetries
    }

    public var isScheduledForFuture: Bool {
        guard let scheduled = scheduledAt else { return false }
        return scheduled > Date()
    }

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        retryCount = 0
        maxRetries = 3
        priority = 0
        status = QueueItemStatus.pending.rawValue
    }

    // MARK: - Methods

    public func markAsProcessing() {
        statusEnum = .processing
    }

    public func markAsCompleted() {
        statusEnum = .completed
        processedAt = Date()
    }

    public func markAsFailed(error: String) {
        statusEnum = .failed
        errorMessage = error
        retryCount += 1

        // Calculate exponential backoff for retry
        if canRetry {
            let backoffSeconds = pow(2.0, Double(retryCount)) * 60 // 2, 4, 8 minutes
            scheduledAt = Date().addingTimeInterval(backoffSeconds)
        }
    }

    public func resetForRetry() {
        statusEnum = .pending
        scheduledAt = nil
        errorMessage = nil
    }
}

// MARK: - Sync Operation

public enum SyncOperation: String, Codable, CaseIterable {
    case create
    case update
    case delete

    public var httpMethod: String {
        switch self {
        case .create: return "POST"
        case .update: return "PUT"
        case .delete: return "DELETE"
        }
    }
}

// MARK: - Queue Item Status

public enum QueueItemStatus: String, Codable, CaseIterable {
    case pending
    case processing
    case completed
    case failed

    public var displayName: String {
        rawValue.capitalized
    }
}
