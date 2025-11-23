import Foundation

// MARK: - Cached Repository

/// A wrapper that adds caching to any repository
public final class CachedRepository<Entity: Identifiable & Codable, ManagedObject: NSManagedObject> {

    // MARK: - Properties

    private let repository: BaseRepository<Entity, ManagedObject>
    private let cache: CacheManager
    private let entityType: String
    private let ttl: TimeInterval?

    // MARK: - Initialization

    public init(
        repository: BaseRepository<Entity, ManagedObject>,
        entityType: String,
        ttl: TimeInterval? = nil,
        cache: CacheManager = .shared
    ) {
        self.repository = repository
        self.entityType = entityType
        self.ttl = ttl
        self.cache = cache
    }

    // MARK: - Cached Operations

    /// Fetch by ID with caching
    public func fetch(byId id: UUID, forceRefresh: Bool = false) async throws -> Entity? {
        let cacheKey = CacheManager.key(for: entityType, id: id)

        // Check cache first (unless force refresh)
        if !forceRefresh {
            if let cached: Entity = try await cache.get(key: cacheKey, type: Entity.self) {
                return cached
            }
        }

        // Fetch from repository
        guard let entity = try await repository.fetch(byId: id) else {
            return nil
        }

        // Cache the result
        try await cache.set(entity, key: cacheKey, entityType: entityType, ttl: ttl)

        return entity
    }

    /// Fetch all with caching
    public func fetchAll(options: FetchOptions = .default, forceRefresh: Bool = false) async throws -> [Entity] {
        let cacheKey = CacheManager.listKey(for: entityType)

        // Check cache first (unless force refresh)
        if !forceRefresh {
            if let cached: [Entity] = try await cache.get(key: cacheKey, type: [Entity].self) {
                return cached
            }
        }

        // Fetch from repository
        let entities = try await repository.fetchAll(options: options)

        // Cache the result
        try await cache.set(entities, key: cacheKey, entityType: entityType, ttl: ttl)

        // Also cache individual entities
        for entity in entities {
            if let id = entity.id as? UUID {
                let key = CacheManager.key(for: entityType, id: id)
                try await cache.set(entity, key: key, entityType: entityType, ttl: ttl)
            }
        }

        return entities
    }

    /// Create with cache invalidation
    public func create(_ entity: Entity) async throws -> Entity {
        let created = try await repository.create(entity)

        // Invalidate list cache
        try await cache.removeAll(forEntityType: entityType)

        // Cache the new entity
        if let id = created.id as? UUID {
            let key = CacheManager.key(for: entityType, id: id)
            try await cache.set(created, key: key, entityType: entityType, ttl: ttl)
        }

        return created
    }

    /// Update with cache invalidation
    public func update(_ entity: Entity) async throws -> Entity {
        let updated = try await repository.update(entity)

        // Update cache
        if let id = updated.id as? UUID {
            let key = CacheManager.key(for: entityType, id: id)
            try await cache.set(updated, key: key, entityType: entityType, ttl: ttl)
        }

        // Invalidate list cache
        let listKey = CacheManager.listKey(for: entityType)
        try await cache.remove(key: listKey)

        return updated
    }

    /// Delete with cache invalidation
    public func delete(byId id: UUID) async throws {
        try await repository.delete(byId: id)

        // Remove from cache
        let key = CacheManager.key(for: entityType, id: id)
        try await cache.remove(key: key)

        // Invalidate list cache
        let listKey = CacheManager.listKey(for: entityType)
        try await cache.remove(key: listKey)
    }

    /// Invalidate all cache for this entity type
    public func invalidateCache() async throws {
        try await cache.removeAll(forEntityType: entityType)
    }

    /// Prefetch and cache entities
    public func prefetch(ids: [UUID]) async throws {
        for id in ids {
            let key = CacheManager.key(for: entityType, id: id)

            // Skip if already cached
            if let _: Entity = try await cache.get(key: key, type: Entity.self) {
                continue
            }

            // Fetch and cache
            if let entity = try await repository.fetch(byId: id) {
                try await cache.set(entity, key: key, entityType: entityType, ttl: ttl)
            }
        }
    }
}

// MARK: - Repository Extensions for Cached Access

extension UserRepository {
    public var cached: CachedRepository<User, CDUser> {
        CachedRepository(repository: self, entityType: "User")
    }
}

extension ConversationRepository {
    public var cached: CachedRepository<Conversation, CDConversation> {
        CachedRepository(repository: self, entityType: "Conversation")
    }
}

extension MessageRepository {
    public var cached: CachedRepository<Message, CDMessage> {
        CachedRepository(repository: self, entityType: "Message")
    }
}

extension CharacterRepository {
    public var cached: CachedRepository<Character, CDCharacter> {
        CachedRepository(repository: self, entityType: "Character")
    }
}

extension CharacterMemoryRepository {
    public var cached: CachedRepository<CharacterMemory, CDCharacterMemory> {
        CachedRepository(repository: self, entityType: "CharacterMemory")
    }
}

extension CharacterLearningRepository {
    public var cached: CachedRepository<CharacterLearning, CDCharacterLearning> {
        CachedRepository(repository: self, entityType: "CharacterLearning")
    }
}

import CoreData
