import Foundation
import Combine

// MARK: - Repository Protocol

/// Base protocol for all repositories
public protocol RepositoryProtocol {
    associatedtype Entity: Identifiable
    associatedtype ManagedObject

    /// Fetch all entities
    func fetchAll() async throws -> [Entity]

    /// Fetch entity by ID
    func fetch(byId id: UUID) async throws -> Entity?

    /// Create a new entity
    func create(_ entity: Entity) async throws -> Entity

    /// Update an existing entity
    func update(_ entity: Entity) async throws -> Entity

    /// Delete an entity by ID
    func delete(byId id: UUID) async throws

    /// Delete all entities
    func deleteAll() async throws

    /// Count all entities
    func count() async throws -> Int

    /// Convert managed object to domain entity
    func toDomain(_ managedObject: ManagedObject) -> Entity

    /// Update managed object from domain entity
    func toManagedObject(_ entity: Entity, managedObject: ManagedObject)
}

// MARK: - Syncable Repository Protocol

/// Protocol for repositories that support syncing
public protocol SyncableRepositoryProtocol: RepositoryProtocol {
    /// Fetch entities that need syncing
    func fetchUnsyncedEntities() async throws -> [Entity]

    /// Mark entity as synced
    func markAsSynced(id: UUID) async throws

    /// Mark entity as pending sync
    func markAsPendingSync(id: UUID) async throws
}

// MARK: - Observable Repository Protocol

/// Protocol for repositories that publish changes
public protocol ObservableRepositoryProtocol: RepositoryProtocol {
    /// Publisher for entity changes
    var changesPublisher: AnyPublisher<RepositoryChange<Entity>, Never> { get }
}

// MARK: - Repository Change

/// Represents a change in the repository
public enum RepositoryChange<Entity> {
    case inserted(Entity)
    case updated(Entity)
    case deleted(UUID)
    case reloaded([Entity])
}

// MARK: - Repository Error

public enum RepositoryError: LocalizedError {
    case notFound(UUID)
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case invalidData(String)
    case duplicateEntry(String)
    case contextNotAvailable

    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Entity not found: \(id)"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete: \(error.localizedDescription)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .duplicateEntry(let field):
            return "Duplicate entry for: \(field)"
        case .contextNotAvailable:
            return "Core Data context not available"
        }
    }
}

// MARK: - Fetch Options

public struct FetchOptions {
    public var sortDescriptors: [NSSortDescriptor]
    public var predicate: NSPredicate?
    public var fetchLimit: Int?
    public var fetchOffset: Int?
    public var includeDeleted: Bool

    public init(
        sortDescriptors: [NSSortDescriptor] = [],
        predicate: NSPredicate? = nil,
        fetchLimit: Int? = nil,
        fetchOffset: Int? = nil,
        includeDeleted: Bool = false
    ) {
        self.sortDescriptors = sortDescriptors
        self.predicate = predicate
        self.fetchLimit = fetchLimit
        self.fetchOffset = fetchOffset
        self.includeDeleted = includeDeleted
    }

    public static var `default`: FetchOptions {
        FetchOptions()
    }
}

// MARK: - Paginated Result

public struct PaginatedResult<T> {
    public let items: [T]
    public let page: Int
    public let pageSize: Int
    public let totalCount: Int

    public var totalPages: Int {
        (totalCount + pageSize - 1) / pageSize
    }

    public var hasNextPage: Bool {
        page < totalPages
    }

    public var hasPreviousPage: Bool {
        page > 1
    }

    public init(items: [T], page: Int, pageSize: Int, totalCount: Int) {
        self.items = items
        self.page = page
        self.pageSize = pageSize
        self.totalCount = totalCount
    }
}
