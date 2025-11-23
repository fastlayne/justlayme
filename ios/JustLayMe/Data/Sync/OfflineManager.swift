import Foundation
import Combine
import Network

// MARK: - Offline Manager

/// Manages offline data operations and queuing
public final class OfflineManager {

    // MARK: - Singleton

    public static let shared = OfflineManager()

    // MARK: - Properties

    private let syncManager: SyncManager
    private let cacheManager: CacheManager
    private var cancellables = Set<AnyCancellable>()

    @Published public private(set) var isOnline: Bool = true
    @Published public private(set) var pendingOperationsCount: Int = 0

    // MARK: - Initialization

    private init(
        syncManager: SyncManager = .shared,
        cacheManager: CacheManager = .shared
    ) {
        self.syncManager = syncManager
        self.cacheManager = cacheManager

        setupObservers()
    }

    private func setupObservers() {
        syncManager.connectivityPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOnline in
                self?.isOnline = isOnline
                if isOnline {
                    self?.processPendingOperations()
                }
            }
            .store(in: &cancellables)

        // Periodically update pending count
        Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.updatePendingCount()
                }
            }
            .store(in: &cancellables)
    }

    private func updatePendingCount() async {
        let count = (try? await syncManager.pendingCount()) ?? 0
        await MainActor.run {
            self.pendingOperationsCount = count
        }
    }

    // MARK: - Offline Operations

    /// Execute an operation with offline support
    public func execute<T>(
        operation: @escaping () async throws -> T,
        offlineFallback: @escaping () async throws -> T?,
        syncPayload: OfflineSyncPayload? = nil
    ) async throws -> T {
        if isOnline {
            do {
                return try await operation()
            } catch {
                // If online operation fails, try offline
                if let fallback = try await offlineFallback() {
                    if let payload = syncPayload {
                        try await queueForSync(payload: payload)
                    }
                    return fallback
                }
                throw error
            }
        } else {
            // Offline mode
            if let fallback = try await offlineFallback() {
                if let payload = syncPayload {
                    try await queueForSync(payload: payload)
                }
                return fallback
            }
            throw OfflineError.operationNotAvailableOffline
        }
    }

    /// Queue an operation for sync when online
    public func queueForSync(payload: OfflineSyncPayload) async throws {
        try await syncManager.enqueue(
            entityType: payload.entityType,
            entityId: payload.entityId,
            operation: payload.operation,
            payload: payload.data,
            priority: payload.priority
        )
        await updatePendingCount()
    }

    /// Process pending operations when coming online
    private func processPendingOperations() {
        Task {
            await syncManager.syncAll()
            await updatePendingCount()
        }
    }

    // MARK: - Offline Data Access

    /// Get data with offline support
    public func getData<T: Codable>(
        key: String,
        type: T.Type,
        onlineFetch: @escaping () async throws -> T
    ) async throws -> T {
        // Try online first if available
        if isOnline {
            do {
                let data = try await onlineFetch()
                // Cache for offline access
                try await cacheManager.set(data, key: key, entityType: String(describing: T.self))
                return data
            } catch {
                // Fall back to cache
            }
        }

        // Try cache
        if let cached: T = try await cacheManager.get(key: key, type: T.self) {
            return cached
        }

        throw OfflineError.dataNotAvailable
    }

    // MARK: - Offline Write Operations

    /// Create entity with offline support
    public func create<Entity: Identifiable & Codable>(
        entity: Entity,
        repository: @escaping () async throws -> Entity,
        entityType: String
    ) async throws -> Entity where Entity.ID == UUID {
        if isOnline {
            return try await repository()
        }

        // Store locally and queue for sync
        let cacheKey = CacheManager.key(for: entityType, id: entity.id)
        try await cacheManager.set(entity, key: cacheKey, entityType: entityType)

        try await queueForSync(payload: OfflineSyncPayload(
            entityType: entityType,
            entityId: entity.id,
            operation: .create,
            data: try entity.toDictionary(),
            priority: 1
        ))

        return entity
    }

    /// Update entity with offline support
    public func update<Entity: Identifiable & Codable>(
        entity: Entity,
        repository: @escaping () async throws -> Entity,
        entityType: String
    ) async throws -> Entity where Entity.ID == UUID {
        if isOnline {
            return try await repository()
        }

        // Store locally and queue for sync
        let cacheKey = CacheManager.key(for: entityType, id: entity.id)
        try await cacheManager.set(entity, key: cacheKey, entityType: entityType)

        try await queueForSync(payload: OfflineSyncPayload(
            entityType: entityType,
            entityId: entity.id,
            operation: .update,
            data: try entity.toDictionary(),
            priority: 0
        ))

        return entity
    }

    /// Delete entity with offline support
    public func delete(
        entityType: String,
        entityId: UUID,
        repository: @escaping () async throws -> Void
    ) async throws {
        if isOnline {
            try await repository()
            return
        }

        // Remove from cache and queue for sync
        let cacheKey = CacheManager.key(for: entityType, id: entityId)
        try await cacheManager.remove(key: cacheKey)

        try await queueForSync(payload: OfflineSyncPayload(
            entityType: entityType,
            entityId: entityId,
            operation: .delete,
            priority: 0
        ))
    }

    // MARK: - Status

    /// Get offline status summary
    public func getStatus() async -> OfflineStatus {
        let pending = (try? await syncManager.pendingCount()) ?? 0
        let failed = (try? await syncManager.failedItems().count) ?? 0

        return OfflineStatus(
            isOnline: isOnline,
            pendingOperations: pending,
            failedOperations: failed,
            lastSyncDate: UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        )
    }
}

// MARK: - Offline Sync Payload

public struct OfflineSyncPayload {
    public let entityType: String
    public let entityId: UUID
    public let operation: SyncOperation
    public var data: [String: Any]
    public var priority: Int

    public init(
        entityType: String,
        entityId: UUID,
        operation: SyncOperation,
        data: [String: Any] = [:],
        priority: Int = 0
    ) {
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.data = data
        self.priority = priority
    }
}

// MARK: - Offline Status

public struct OfflineStatus {
    public let isOnline: Bool
    public let pendingOperations: Int
    public let failedOperations: Int
    public let lastSyncDate: Date?

    public var needsSync: Bool {
        pendingOperations > 0 || failedOperations > 0
    }
}

// MARK: - Offline Error

public enum OfflineError: LocalizedError {
    case operationNotAvailableOffline
    case dataNotAvailable
    case syncQueueFull

    public var errorDescription: String? {
        switch self {
        case .operationNotAvailableOffline:
            return "This operation is not available offline"
        case .dataNotAvailable:
            return "Data is not available offline"
        case .syncQueueFull:
            return "Offline sync queue is full"
        }
    }
}

// MARK: - Codable Extension

extension Encodable {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return dictionary ?? [:]
    }
}
