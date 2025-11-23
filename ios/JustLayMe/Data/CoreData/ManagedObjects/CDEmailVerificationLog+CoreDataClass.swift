import Foundation
import CoreData

@objc(CDEmailVerificationLog)
public class CDEmailVerificationLog: NSManagedObject {

    // MARK: - Fetch Requests

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDEmailVerificationLog> {
        return NSFetchRequest<CDEmailVerificationLog>(entityName: "CDEmailVerificationLog")
    }

    @nonobjc public class func fetchRequest(byUserId userId: UUID) -> NSFetchRequest<CDEmailVerificationLog> {
        let request = NSFetchRequest<CDEmailVerificationLog>(entityName: "CDEmailVerificationLog")
        request.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return request
    }

    @nonobjc public class func fetchRequest(byAction action: VerificationAction) -> NSFetchRequest<CDEmailVerificationLog> {
        let request = NSFetchRequest<CDEmailVerificationLog>(entityName: "CDEmailVerificationLog")
        request.predicate = NSPredicate(format: "action == %@", action.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return request
    }

    // MARK: - Properties

    @NSManaged public var id: UUID?
    @NSManaged public var userId: UUID?
    @NSManaged public var action: String?
    @NSManaged public var ipAddress: String?
    @NSManaged public var userAgent: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var syncStatus: Int16

    // MARK: - Relationships

    @NSManaged public var user: CDUser?

    // MARK: - Computed Properties

    public var actionEnum: VerificationAction {
        get { VerificationAction(rawValue: action ?? "") ?? .registration }
        set { action = newValue.rawValue }
    }

    public var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        syncStatus = SyncStatus.pending.rawValue
    }
}

// MARK: - Verification Action

public enum VerificationAction: String, Codable, CaseIterable {
    case registration
    case login
    case emailVerified = "email_verified"
    case sent
    case clicked
    case expired
    case resendVerification = "resend_verification"

    public var displayName: String {
        switch self {
        case .registration: return "Registration"
        case .login: return "Login"
        case .emailVerified: return "Email Verified"
        case .sent: return "Verification Sent"
        case .clicked: return "Link Clicked"
        case .expired: return "Link Expired"
        case .resendVerification: return "Resend Verification"
        }
    }
}
