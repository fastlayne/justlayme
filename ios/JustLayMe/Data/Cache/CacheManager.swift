import Foundation
import CoreData

// MARK: - Cache Configuration

public struct CacheConfiguration {
    /// Default time-to-live in seconds (15 minutes)
    public var defaultTTL: TimeInterval = 900

    /// Maximum cache size in bytes (50 MB)
    public var maxCacheSize: Int64 = 50 * 1024 * 1024

    /// Maximum number of entries
    public var maxEntries: Int = 1000

    /// TTL by entity type
    public var ttlByEntityType: [String: TimeInterval] = [
        "User": 3600,           // 1 hour
        "Conversation": 1800,   // 30 minutes
        "Message": 900,         // 15 minutes
        "Character": 3600,      // 1 hour
        "CharacterMemory": 1800,// 30 minutes
        "CharacterLearning": 1800 // 30 minutes
    ]

    /// Whether to auto-clean expired entries
    public var autoCleanEnabled: Bool = true

    /// Clean interval in seconds
    public var cleanInterval: TimeInterval = 300 // 5 minutes

    public init() {}

    public func ttl(for entityType: String) -> TimeInterval {
        ttlByEntityType[entityType] ?? defaultTTL
    }
}

// MARK: - Cache Manager

public final class CacheManager {

    // MARK: - Singleton

    public static let shared = CacheManager()

    // MARK: - Properties

    private let coreDataStack: CoreDataStack
    public var configuration: CacheConfiguration

    private var cleanTimer: Timer?
    private let memoryCache = NSCache<NSString, CacheWrapper>()

    // MARK: - Initialization

    private init(coreDataStack: CoreDataStack = .shared, configuration: CacheConfiguration = CacheConfiguration()) {
        self.coreDataStack = coreDataStack
        self.configuration = configuration

        setupMemoryCache()
        setupAutoClean()
        setupMemoryWarningObserver()
    }

    private func setupMemoryCache() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 10 * 1024 * 1024 // 10 MB in-memory limit
    }

    private func setupAutoClean() {
        guard configuration.autoCleanEnabled else { return }

        cleanTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.cleanInterval,
            repeats: true
        ) { [weak self] _ in
            Task {
                try? await self?.cleanExpiredEntries()
            }
        }
    }

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
    }

    deinit {
        cleanTimer?.invalidate()
    }

    // MARK: - Cache Operations

    /// Get cached data for key
    public func get<T: Codable>(key: String, type: T.Type) async throws -> T? {
        // Check memory cache first
        if let wrapper = memoryCache.object(forKey: key as NSString),
           !wrapper.isExpired,
           let data = wrapper.data {
            return try JSONDecoder().decode(T.self, from: data)
        }

        // Check disk cache
        return try await coreDataStack.performBackgroundTask { [weak self] context in
            guard self != nil else { return nil }

            let request = CDCacheEntry.fetchRequest(byKey: key)
            guard let entry = try context.fetch(request).first else {
                return nil
            }

            // Check expiration
            guard !entry.isExpired, let data = entry.data else {
                context.delete(entry)
                return nil
            }

            // Record access
            entry.recordAccess()

            // Update memory cache
            let decoder = JSONDecoder()
            guard let decoded = try? decoder.decode(T.self, from: data) else {
                return nil
            }

            await MainActor.run { [weak self] in
                let wrapper = CacheWrapper(data: data, expiresAt: entry.expiresAt ?? Date())
                self?.memoryCache.setObject(wrapper, forKey: key as NSString, cost: data.count)
            }

            return decoded
        }
    }

    /// Set cached data for key
    public func set<T: Codable>(_ value: T, key: String, entityType: String, ttl: TimeInterval? = nil) async throws {
        let data = try JSONEncoder().encode(value)
        let expiresAt = Date().addingTimeInterval(ttl ?? configuration.ttl(for: entityType))

        // Update memory cache
        let wrapper = CacheWrapper(data: data, expiresAt: expiresAt)
        memoryCache.setObject(wrapper, forKey: key as NSString, cost: data.count)

        // Update disk cache
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard self != nil else { return }

            let request = CDCacheEntry.fetchRequest(byKey: key)

            let entry: CDCacheEntry
            if let existing = try context.fetch(request).first {
                entry = existing
            } else {
                entry = CDCacheEntry(context: context)
                entry.key = key
                entry.entityType = entityType
            }

            entry.updateData(data, expiresIn: ttl ?? self!.configuration.ttl(for: entityType))
        }
    }

    /// Remove cached data for key
    public func remove(key: String) async throws {
        memoryCache.removeObject(forKey: key as NSString)

        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard self != nil else { return }

            let request = CDCacheEntry.fetchRequest(byKey: key)
            if let entry = try context.fetch(request).first {
                context.delete(entry)
            }
        }
    }

    /// Remove all cached data for entity type
    public func removeAll(forEntityType entityType: String) async throws {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard self != nil else { return }

            let request = CDCacheEntry.fetchRequest(byEntityType: entityType)
            let entries = try context.fetch(request)
            for entry in entries {
                if let key = entry.key {
                    await MainActor.run { [weak self] in
                        self?.memoryCache.removeObject(forKey: key as NSString)
                    }
                }
                context.delete(entry)
            }
        }
    }

    /// Clear all cache
    public func clearAll() async throws {
        memoryCache.removeAllObjects()

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CDCacheEntry")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
        try coreDataStack.batchDelete(request: batchDelete)
    }

    // MARK: - Expiration Management

    /// Clean expired entries
    public func cleanExpiredEntries() async throws {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard self != nil else { return }

            let request = CDCacheEntry.fetchRequest(expired: true)
            let entries = try context.fetch(request)

            for entry in entries {
                if let key = entry.key {
                    await MainActor.run { [weak self] in
                        self?.memoryCache.removeObject(forKey: key as NSString)
                    }
                }
                context.delete(entry)
            }
        }
    }

    /// Enforce cache size limits
    public func enforceSizeLimits() async throws {
        let stats = try await getStatistics()

        // Check entry count
        if stats.entryCount > configuration.maxEntries {
            let toRemove = stats.entryCount - configuration.maxEntries
            try await removeLeastRecentlyUsed(count: toRemove)
        }

        // Check total size
        if stats.totalSize > configuration.maxCacheSize {
            try await evictToSize(targetSize: Int64(Double(configuration.maxCacheSize) * 0.8))
        }
    }

    /// Remove least recently used entries
    private func removeLeastRecentlyUsed(count: Int) async throws {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard self != nil else { return }

            let request = CDCacheEntry.fetchRequest(leastRecentlyUsed: count)
            let entries = try context.fetch(request)

            for entry in entries {
                if let key = entry.key {
                    await MainActor.run { [weak self] in
                        self?.memoryCache.removeObject(forKey: key as NSString)
                    }
                }
                context.delete(entry)
            }
        }
    }

    /// Evict entries until target size is reached
    private func evictToSize(targetSize: Int64) async throws {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard self != nil else { return }

            let request = NSFetchRequest<CDCacheEntry>(entityName: "CDCacheEntry")
            request.sortDescriptors = [NSSortDescriptor(key: "lastAccessedAt", ascending: true)]

            let entries = try context.fetch(request)
            var currentSize = entries.reduce(0) { $0 + $1.sizeBytes }

            for entry in entries {
                guard currentSize > targetSize else { break }

                currentSize -= entry.sizeBytes
                if let key = entry.key {
                    await MainActor.run { [weak self] in
                        self?.memoryCache.removeObject(forKey: key as NSString)
                    }
                }
                context.delete(entry)
            }
        }
    }

    // MARK: - Statistics

    public struct CacheStatistics {
        public let entryCount: Int
        public let totalSize: Int64
        public let oldestEntry: Date?
        public let newestEntry: Date?
        public let hitRate: Double
        public let entriesByType: [String: Int]
    }

    public func getStatistics() async throws -> CacheStatistics {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard self != nil else { throw RepositoryError.contextNotAvailable }

            let request = NSFetchRequest<CDCacheEntry>(entityName: "CDCacheEntry")
            let entries = try context.fetch(request)

            let totalSize = entries.reduce(0) { $0 + $1.sizeBytes }
            let dates = entries.compactMap { $0.createdAt }
            var entriesByType: [String: Int] = [:]

            for entry in entries {
                let type = entry.entityType ?? "Unknown"
                entriesByType[type, default: 0] += 1
            }

            return CacheStatistics(
                entryCount: entries.count,
                totalSize: totalSize,
                oldestEntry: dates.min(),
                newestEntry: dates.max(),
                hitRate: 0.0, // Would need tracking
                entriesByType: entriesByType
            )
        }
    }

    // MARK: - Cache Key Helpers

    public static func key(for entityType: String, id: UUID) -> String {
        "\(entityType):\(id.uuidString)"
    }

    public static func key(for entityType: String, query: String) -> String {
        "\(entityType):query:\(query.hashValue)"
    }

    public static func listKey(for entityType: String, userId: UUID? = nil) -> String {
        if let userId = userId {
            return "\(entityType):list:\(userId.uuidString)"
        }
        return "\(entityType):list:all"
    }
}

// MARK: - Cache Wrapper (for NSCache)

private final class CacheWrapper {
    let data: Data?
    let expiresAt: Date

    var isExpired: Bool {
        expiresAt < Date()
    }

    init(data: Data?, expiresAt: Date) {
        self.data = data
        self.expiresAt = expiresAt
    }
}

// MARK: - UIApplication Notification (for iOS)

#if canImport(UIKit)
import UIKit
#endif
