import Foundation
import CoreData
import Combine
import Network

// MARK: - Sync Configuration

public struct SyncConfiguration {
    /// Maximum concurrent sync operations
    public var maxConcurrentOperations: Int = 3

    /// Retry delay in seconds
    public var retryDelay: TimeInterval = 60

    /// Maximum retries per item
    public var maxRetries: Int = 3

    /// Batch size for sync operations
    public var batchSize: Int = 50

    /// Whether to sync automatically when online
    public var autoSyncEnabled: Bool = true

    /// Sync interval when online (in seconds)
    public var syncInterval: TimeInterval = 300 // 5 minutes

    public init() {}
}

// MARK: - Sync State

public enum SyncState: Equatable {
    case idle
    case syncing(progress: Double)
    case completed(Date)
    case failed(String)
    case offline
}

// MARK: - Sync Manager

public final class SyncManager {

    // MARK: - Singleton

    public static let shared = SyncManager()

    // MARK: - Properties

    private let coreDataStack: CoreDataStack
    public var configuration: SyncConfiguration

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.justlayme.networkmonitor")

    private var isOnline = true
    private var syncTimer: Timer?
    private var currentSyncTask: Task<Void, Never>?

    // MARK: - Publishers

    private let stateSubject = CurrentValueSubject<SyncState, Never>(.idle)
    public var statePublisher: AnyPublisher<SyncState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    private let connectivitySubject = CurrentValueSubject<Bool, Never>(true)
    public var connectivityPublisher: AnyPublisher<Bool, Never> {
        connectivitySubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private init(coreDataStack: CoreDataStack = .shared, configuration: SyncConfiguration = SyncConfiguration()) {
        self.coreDataStack = coreDataStack
        self.configuration = configuration

        setupNetworkMonitoring()
        setupAutoSync()
    }

    deinit {
        networkMonitor.cancel()
        syncTimer?.invalidate()
        currentSyncTask?.cancel()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            self?.isOnline = isOnline
            self?.connectivitySubject.send(isOnline)

            if isOnline {
                self?.stateSubject.send(.idle)
                if self?.configuration.autoSyncEnabled == true {
                    Task {
                        await self?.syncAll()
                    }
                }
            } else {
                self?.stateSubject.send(.offline)
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    private func setupAutoSync() {
        guard configuration.autoSyncEnabled else { return }

        syncTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.syncInterval,
            repeats: true
        ) { [weak self] _ in
            guard self?.isOnline == true else { return }
            Task {
                await self?.syncAll()
            }
        }
    }

    // MARK: - Sync Queue Operations

    /// Add item to sync queue
    public func enqueue(
        entityType: String,
        entityId: UUID,
        operation: SyncOperation,
        payload: [String: Any]? = nil,
        priority: Int = 0
    ) async throws {
        try await coreDataStack.performBackgroundTask { context in
            let item = CDSyncQueueItem(context: context)
            item.id = UUID()
            item.entityType = entityType
            item.entityId = entityId
            item.operation = operation.rawValue
            item.payload = payload ?? [:]
            item.priority = Int16(priority)
            item.status = QueueItemStatus.pending.rawValue
            item.createdAt = Date()
            item.maxRetries = Int16(self.configuration.maxRetries)
        }
    }

    /// Get pending sync items count
    public func pendingCount() async throws -> Int {
        try await coreDataStack.performBackgroundTask { context in
            let request = CDSyncQueueItem.fetchRequest(pending: true)
            return try context.count(for: request)
        }
    }

    /// Get failed sync items
    public func failedItems() async throws -> [(entityType: String, entityId: UUID, error: String)] {
        try await coreDataStack.performBackgroundTask { context in
            let request = CDSyncQueueItem.fetchRequest(failed: true)
            let items = try context.fetch(request)

            return items.compactMap { item in
                guard let type = item.entityType,
                      let id = item.entityId,
                      let error = item.errorMessage else { return nil }
                return (type, id, error)
            }
        }
    }

    // MARK: - Sync Execution

    /// Sync all pending items
    public func syncAll() async {
        guard isOnline else {
            stateSubject.send(.offline)
            return
        }

        // Cancel any existing sync
        currentSyncTask?.cancel()

        currentSyncTask = Task {
            stateSubject.send(.syncing(progress: 0))

            do {
                let totalItems = try await pendingCount()
                guard totalItems > 0 else {
                    stateSubject.send(.completed(Date()))
                    return
                }

                var processedItems = 0

                while !Task.isCancelled {
                    let batch = try await fetchNextBatch()
                    guard !batch.isEmpty else { break }

                    for item in batch {
                        guard !Task.isCancelled else { break }

                        do {
                            try await processItem(item)
                            processedItems += 1
                            let progress = Double(processedItems) / Double(totalItems)
                            stateSubject.send(.syncing(progress: progress))
                        } catch {
                            await handleItemError(item, error: error)
                        }
                    }
                }

                if !Task.isCancelled {
                    stateSubject.send(.completed(Date()))
                }
            } catch {
                stateSubject.send(.failed(error.localizedDescription))
            }
        }

        await currentSyncTask?.value
    }

    private func fetchNextBatch() async throws -> [CDSyncQueueItem] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { return [] }

            let request = CDSyncQueueItem.fetchRequest(pending: true)
            request.fetchLimit = self.configuration.batchSize

            return try context.fetch(request)
        }
    }

    private func processItem(_ item: CDSyncQueueItem) async throws {
        guard let entityType = item.entityType,
              let entityId = item.entityId,
              let operation = SyncOperation(rawValue: item.operation ?? "") else {
            throw SyncError.invalidItem
        }

        // Mark as processing
        try await updateItemStatus(item.id ?? UUID(), status: .processing)

        // Perform the sync operation (this would call your API)
        try await performSyncOperation(
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: item.payload
        )

        // Mark as completed
        try await updateItemStatus(item.id ?? UUID(), status: .completed)
    }

    private func performSyncOperation(
        entityType: String,
        entityId: UUID,
        operation: SyncOperation,
        payload: [String: Any]
    ) async throws {
        // This is where you'd implement the actual API calls
        // For now, simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // In a real implementation:
        // - Build the API request based on operation type
        // - Send to server
        // - Handle response
        // - Update local entity with server response

        // Example structure:
        /*
        let endpoint = buildEndpoint(entityType: entityType, entityId: entityId, operation: operation)
        let request = buildRequest(endpoint: endpoint, method: operation.httpMethod, payload: payload)
        let response = try await networkService.send(request)
        try await updateLocalEntity(entityType: entityType, entityId: entityId, response: response)
        */
    }

    private func handleItemError(_ item: CDSyncQueueItem, error: Error) async {
        guard let itemId = item.id else { return }

        do {
            try await coreDataStack.performBackgroundTask { context in
                let request = NSFetchRequest<CDSyncQueueItem>(entityName: "CDSyncQueueItem")
                request.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)

                if let fetchedItem = try context.fetch(request).first {
                    fetchedItem.markAsFailed(error: error.localizedDescription)
                }
            }
        } catch {
            print("Failed to update item status: \(error)")
        }
    }

    private func updateItemStatus(_ itemId: UUID, status: QueueItemStatus) async throws {
        try await coreDataStack.performBackgroundTask { context in
            let request = NSFetchRequest<CDSyncQueueItem>(entityName: "CDSyncQueueItem")
            request.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)

            if let item = try context.fetch(request).first {
                switch status {
                case .processing:
                    item.markAsProcessing()
                case .completed:
                    item.markAsCompleted()
                default:
                    item.status = status.rawValue
                }
            }
        }
    }

    // MARK: - Retry Management

    /// Retry failed items
    public func retryFailed() async throws {
        try await coreDataStack.performBackgroundTask { context in
            let request = CDSyncQueueItem.fetchRequest(retryable: true)
            let items = try context.fetch(request)

            for item in items {
                item.resetForRetry()
            }
        }

        await syncAll()
    }

    /// Clear failed items
    public func clearFailed() async throws {
        try await coreDataStack.performBackgroundTask { context in
            let request = CDSyncQueueItem.fetchRequest(failed: true)
            let items = try context.fetch(request)

            for item in items {
                context.delete(item)
            }
        }
    }

    /// Clear all sync queue
    public func clearQueue() async throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CDSyncQueueItem")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
        try coreDataStack.batchDelete(request: batchDelete)
    }

    // MARK: - Conflict Resolution

    public enum ConflictResolution {
        case useLocal
        case useServer
        case merge
    }

    /// Handle sync conflict
    public func resolveConflict(
        entityType: String,
        entityId: UUID,
        resolution: ConflictResolution
    ) async throws {
        // Implementation depends on your conflict resolution strategy
        switch resolution {
        case .useLocal:
            // Re-enqueue with high priority
            try await enqueue(
                entityType: entityType,
                entityId: entityId,
                operation: .update,
                priority: 10
            )
        case .useServer:
            // Fetch from server and update local
            // try await fetchFromServer(entityType: entityType, entityId: entityId)
            break
        case .merge:
            // Implement merge logic
            break
        }
    }
}

// MARK: - Sync Error

public enum SyncError: LocalizedError {
    case offline
    case invalidItem
    case serverError(Int)
    case conflict
    case timeout

    public var errorDescription: String? {
        switch self {
        case .offline:
            return "Device is offline"
        case .invalidItem:
            return "Invalid sync queue item"
        case .serverError(let code):
            return "Server error: \(code)"
        case .conflict:
            return "Sync conflict detected"
        case .timeout:
            return "Sync operation timed out"
        }
    }
}
