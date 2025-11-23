import Foundation
import CoreData
import Combine

// MARK: - Base Repository

/// Base class providing common repository functionality
open class BaseRepository<Entity: Identifiable, ManagedObject: NSManagedObject> {

    // MARK: - Properties

    protected let coreDataStack: CoreDataStack
    protected let entityName: String
    private let changesSubject = PassthroughSubject<RepositoryChange<Entity>, Never>()

    public var changesPublisher: AnyPublisher<RepositoryChange<Entity>, Never> {
        changesSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public init(coreDataStack: CoreDataStack = .shared, entityName: String) {
        self.coreDataStack = coreDataStack
        self.entityName = entityName
    }

    // MARK: - Core Data Helpers

    protected var mainContext: NSManagedObjectContext {
        coreDataStack.mainContext
    }

    protected func newBackgroundContext() -> NSManagedObjectContext {
        coreDataStack.newBackgroundContext()
    }

    // MARK: - Abstract Methods (Override in subclasses)

    open func toDomain(_ managedObject: ManagedObject) -> Entity {
        fatalError("Subclasses must override toDomain(_:)")
    }

    open func toManagedObject(_ entity: Entity, managedObject: ManagedObject) {
        fatalError("Subclasses must override toManagedObject(_:managedObject:)")
    }

    open func createManagedObject(from entity: Entity, in context: NSManagedObjectContext) -> ManagedObject {
        fatalError("Subclasses must override createManagedObject(from:in:)")
    }

    // MARK: - Fetch Operations

    public func fetchAll(options: FetchOptions = .default) async throws -> [Entity] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = NSFetchRequest<ManagedObject>(entityName: self.entityName)
            request.sortDescriptors = options.sortDescriptors

            if let predicate = options.predicate {
                request.predicate = predicate
            }

            if let limit = options.fetchLimit {
                request.fetchLimit = limit
            }

            if let offset = options.fetchOffset {
                request.fetchOffset = offset
            }

            let managedObjects = try context.fetch(request)
            return managedObjects.map { self.toDomain($0) }
        }
    }

    public func fetch(byId id: UUID) async throws -> Entity? {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = NSFetchRequest<ManagedObject>(entityName: self.entityName)
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let managedObject = try context.fetch(request).first else {
                return nil
            }

            return self.toDomain(managedObject)
        }
    }

    public func fetchPaginated(page: Int, pageSize: Int, options: FetchOptions = .default) async throws -> PaginatedResult<Entity> {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            // Get total count
            let countRequest = NSFetchRequest<ManagedObject>(entityName: self.entityName)
            countRequest.predicate = options.predicate
            let totalCount = try context.count(for: countRequest)

            // Fetch page
            let request = NSFetchRequest<ManagedObject>(entityName: self.entityName)
            request.sortDescriptors = options.sortDescriptors
            request.predicate = options.predicate
            request.fetchLimit = pageSize
            request.fetchOffset = (page - 1) * pageSize

            let managedObjects = try context.fetch(request)
            let items = managedObjects.map { self.toDomain($0) }

            return PaginatedResult(
                items: items,
                page: page,
                pageSize: pageSize,
                totalCount: totalCount
            )
        }
    }

    // MARK: - Create Operations

    public func create(_ entity: Entity) async throws -> Entity {
        let created = try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let managedObject = self.createManagedObject(from: entity, in: context)
            return self.toDomain(managedObject)
        }

        changesSubject.send(.inserted(created))
        return created
    }

    public func createBatch(_ entities: [Entity]) async throws -> [Entity] {
        let created = try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            return entities.map { entity in
                let managedObject = self.createManagedObject(from: entity, in: context)
                return self.toDomain(managedObject)
            }
        }

        for entity in created {
            changesSubject.send(.inserted(entity))
        }

        return created
    }

    // MARK: - Update Operations

    public func update(_ entity: Entity) async throws -> Entity {
        guard let entityId = entity.id as? UUID else {
            throw RepositoryError.invalidData("Entity ID must be UUID")
        }

        let updated = try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = NSFetchRequest<ManagedObject>(entityName: self.entityName)
            request.predicate = NSPredicate(format: "id == %@", entityId as CVarArg)
            request.fetchLimit = 1

            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(entityId)
            }

            self.toManagedObject(entity, managedObject: managedObject)
            return self.toDomain(managedObject)
        }

        changesSubject.send(.updated(updated))
        return updated
    }

    // MARK: - Delete Operations

    public func delete(byId id: UUID) async throws {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = NSFetchRequest<ManagedObject>(entityName: self.entityName)
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(id)
            }

            context.delete(managedObject)
        }

        changesSubject.send(.deleted(id))
    }

    public func deleteAll() async throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
        try coreDataStack.batchDelete(request: batchDelete)
    }

    public func deleteWhere(predicate: NSPredicate) async throws {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = NSFetchRequest<ManagedObject>(entityName: self.entityName)
            request.predicate = predicate

            let managedObjects = try context.fetch(request)
            for object in managedObjects {
                context.delete(object)
            }
        }
    }

    // MARK: - Count Operations

    public func count(predicate: NSPredicate? = nil) async throws -> Int {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = NSFetchRequest<ManagedObject>(entityName: self.entityName)
            request.predicate = predicate
            return try context.count(for: request)
        }
    }

    // MARK: - Sync Support

    public func fetchUnsynced() async throws -> [Entity] {
        let predicate = NSPredicate(format: "syncStatus != %d", SyncStatus.synced.rawValue)
        return try await fetchAll(options: FetchOptions(predicate: predicate))
    }

    public func markAsSynced(id: UUID) async throws {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = NSFetchRequest<ManagedObject>(entityName: self.entityName)
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(id)
            }

            managedObject.setValue(SyncStatus.synced.rawValue, forKey: "syncStatus")
            managedObject.setValue(Date(), forKey: "lastSyncedAt")
        }
    }

    public func markAsPendingSync(id: UUID) async throws {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = NSFetchRequest<ManagedObject>(entityName: self.entityName)
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(id)
            }

            managedObject.setValue(SyncStatus.pendingSync.rawValue, forKey: "syncStatus")
        }
    }

    // MARK: - Notification

    protected func notifyReload(_ entities: [Entity]) {
        changesSubject.send(.reloaded(entities))
    }
}
