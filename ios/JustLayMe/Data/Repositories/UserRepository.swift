import Foundation
import CoreData

// MARK: - User Repository

public final class UserRepository: BaseRepository<User, CDUser> {

    // MARK: - Singleton

    public static let shared = UserRepository()

    // MARK: - Initialization

    private init() {
        super.init(entityName: "CDUser")
    }

    // MARK: - Domain Conversion

    public override func toDomain(_ managedObject: CDUser) -> User {
        User(
            id: managedObject.id ?? UUID(),
            email: managedObject.email ?? "",
            name: managedObject.name,
            googleId: managedObject.googleId,
            subscriptionStatus: SubscriptionStatus(rawValue: managedObject.subscriptionStatus ?? "free") ?? .free,
            subscriptionEnd: managedObject.subscriptionEnd,
            messageCount: Int(managedObject.messageCount),
            emailVerified: managedObject.emailVerified,
            verificationToken: managedObject.verificationToken,
            verificationExpires: managedObject.verificationExpires,
            createdAt: managedObject.createdAt ?? Date(),
            lastLogin: managedObject.lastLogin,
            updatedAt: managedObject.updatedAt,
            avatarStyle: managedObject.avatarStyle,
            themePreference: managedObject.themePreference
        )
    }

    public override func toManagedObject(_ entity: User, managedObject: CDUser) {
        managedObject.id = entity.id
        managedObject.email = entity.email
        managedObject.name = entity.name
        managedObject.googleId = entity.googleId
        managedObject.subscriptionStatus = entity.subscriptionStatus.rawValue
        managedObject.subscriptionEnd = entity.subscriptionEnd
        managedObject.messageCount = Int32(entity.messageCount)
        managedObject.emailVerified = entity.emailVerified
        managedObject.verificationToken = entity.verificationToken
        managedObject.verificationExpires = entity.verificationExpires
        managedObject.createdAt = entity.createdAt
        managedObject.lastLogin = entity.lastLogin
        managedObject.updatedAt = entity.updatedAt
        managedObject.avatarStyle = entity.avatarStyle
        managedObject.themePreference = entity.themePreference
        managedObject.syncStatus = SyncStatus.pendingSync.rawValue
    }

    public override func createManagedObject(from entity: User, in context: NSManagedObjectContext) -> CDUser {
        let managedObject = CDUser(context: context)
        toManagedObject(entity, managedObject: managedObject)
        managedObject.syncStatus = SyncStatus.pending.rawValue
        return managedObject
    }

    // MARK: - Custom Queries

    /// Fetch user by email
    public func fetch(byEmail email: String) async throws -> User? {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDUser.fetchRequest(byEmail: email)
            guard let managedObject = try context.fetch(request).first else {
                return nil
            }
            return self.toDomain(managedObject)
        }
    }

    /// Fetch user by Google ID
    public func fetch(byGoogleId googleId: String) async throws -> User? {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = NSFetchRequest<CDUser>(entityName: "CDUser")
            request.predicate = NSPredicate(format: "googleId == %@", googleId)
            request.fetchLimit = 1

            guard let managedObject = try context.fetch(request).first else {
                return nil
            }
            return self.toDomain(managedObject)
        }
    }

    /// Fetch premium users
    public func fetchPremiumUsers() async throws -> [User] {
        let predicate = NSPredicate(format: "subscriptionStatus != %@", "free")
        return try await fetchAll(options: FetchOptions(predicate: predicate))
    }

    /// Update subscription status
    public func updateSubscription(
        userId: UUID,
        status: SubscriptionStatus,
        endDate: Date?
    ) async throws -> User {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDUser.fetchRequest(byId: userId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(userId)
            }

            managedObject.subscriptionStatus = status.rawValue
            managedObject.subscriptionEnd = endDate
            managedObject.syncStatus = SyncStatus.pendingSync.rawValue

            return self.toDomain(managedObject)
        }
    }

    /// Increment message count
    public func incrementMessageCount(userId: UUID) async throws -> Int {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard self != nil else { throw RepositoryError.contextNotAvailable }

            let request = CDUser.fetchRequest(byId: userId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(userId)
            }

            managedObject.messageCount += 1
            managedObject.syncStatus = SyncStatus.pendingSync.rawValue

            return Int(managedObject.messageCount)
        }
    }

    /// Update last login
    public func updateLastLogin(userId: UUID) async throws {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard self != nil else { throw RepositoryError.contextNotAvailable }

            let request = CDUser.fetchRequest(byId: userId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(userId)
            }

            managedObject.lastLogin = Date()
            managedObject.syncStatus = SyncStatus.pendingSync.rawValue
        }
    }

    /// Verify email
    public func verifyEmail(userId: UUID) async throws -> User {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDUser.fetchRequest(byId: userId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(userId)
            }

            managedObject.emailVerified = true
            managedObject.verificationToken = nil
            managedObject.verificationExpires = nil
            managedObject.syncStatus = SyncStatus.pendingSync.rawValue

            return self.toDomain(managedObject)
        }
    }

    /// Create or update user (upsert)
    public func upsert(_ user: User) async throws -> User {
        if let _ = try await fetch(byId: user.id) {
            return try await update(user)
        } else {
            return try await create(user)
        }
    }
}
