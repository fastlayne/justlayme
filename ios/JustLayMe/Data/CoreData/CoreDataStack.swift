import Foundation
import CoreData

// MARK: - Core Data Stack

/// Production-ready Core Data stack with support for background operations,
/// migrations, and error handling
public final class CoreDataStack {

    // MARK: - Singleton

    public static let shared = CoreDataStack()

    // MARK: - Properties

    private let modelName = "JustLayMe"
    private let storeFileName = "JustLayMe.sqlite"

    /// Main context for UI operations (main thread)
    public private(set) lazy var mainContext: NSManagedObjectContext = {
        let context = persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        return context
    }()

    /// Background context for heavy operations
    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        return context
    }

    // MARK: - Persistent Container

    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: modelName)

        // Configure store description
        let storeURL = storeDirectory.appendingPathComponent(storeFileName)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { [weak self] (storeDescription, error) in
            if let error = error as NSError? {
                self?.handlePersistentStoreError(error)
            }
        }

        return container
    }()

    // MARK: - Store Directory

    private var storeDirectory: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[0]
        let storeDirectory = appSupportURL.appendingPathComponent("JustLayMe")

        if !FileManager.default.fileExists(atPath: storeDirectory.path) {
            try? FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        }

        return storeDirectory
    }

    // MARK: - Initialization

    private init() {
        setupNotificationHandling()
    }

    // MARK: - Setup

    private func setupNotificationHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator
        )
    }

    @objc private func handleRemoteChange(_ notification: Notification) {
        // Handle remote changes for sync
        mainContext.perform { [weak self] in
            self?.mainContext.mergeChanges(fromContextDidSave: notification)
        }
    }

    // MARK: - Error Handling

    private func handlePersistentStoreError(_ error: NSError) {
        // Log the error
        print("Core Data Error: \(error), \(error.userInfo)")

        // Attempt recovery based on error type
        if error.domain == NSCocoaErrorDomain {
            switch error.code {
            case NSPersistentStoreIncompatibleVersionHashError,
                 NSMigrationMissingMappingModelError:
                // Migration failed - attempt to delete and recreate store
                attemptStoreRecovery()
            default:
                break
            }
        }
    }

    private func attemptStoreRecovery() {
        let storeURL = storeDirectory.appendingPathComponent(storeFileName)
        let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")

        for url in [storeURL, walURL, shmURL] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Save Operations

    /// Save the main context
    public func saveMainContext() throws {
        guard mainContext.hasChanges else { return }

        do {
            try mainContext.save()
        } catch {
            mainContext.rollback()
            throw CoreDataError.saveFailed(error)
        }
    }

    /// Save a background context
    public func save(context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }

        var saveError: Error?

        context.performAndWait {
            do {
                try context.save()
            } catch {
                context.rollback()
                saveError = error
            }
        }

        if let error = saveError {
            throw CoreDataError.saveFailed(error)
        }
    }

    /// Perform work on background context and save
    public func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

                do {
                    let result = try block(context)
                    if context.hasChanges {
                        try context.save()
                    }
                    continuation.resume(returning: result)
                } catch {
                    context.rollback()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Batch Operations

    /// Execute batch delete request
    public func batchDelete(request: NSBatchDeleteRequest) throws {
        request.resultType = .resultTypeObjectIDs

        let result = try mainContext.execute(request) as? NSBatchDeleteResult
        let objectIDs = result?.result as? [NSManagedObjectID] ?? []

        let changes = [NSDeletedObjectsKey: objectIDs]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [mainContext])
    }

    /// Execute batch update request
    public func batchUpdate(request: NSBatchUpdateRequest) throws -> Int {
        request.resultType = .updatedObjectsCountResultType

        let result = try mainContext.execute(request) as? NSBatchUpdateResult
        return result?.result as? Int ?? 0
    }

    // MARK: - Reset

    /// Reset the entire Core Data stack (use with caution)
    public func resetStore() throws {
        let storeURL = storeDirectory.appendingPathComponent(storeFileName)

        // Remove persistent store
        if let store = persistentContainer.persistentStoreCoordinator.persistentStores.first {
            try persistentContainer.persistentStoreCoordinator.remove(store)
        }

        // Delete files
        let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")

        for url in [storeURL, walURL, shmURL] {
            try? FileManager.default.removeItem(at: url)
        }

        // Reload store
        try persistentContainer.persistentStoreCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true
            ]
        )
    }
}

// MARK: - Core Data Error

public enum CoreDataError: LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case entityNotFound(String)
    case invalidData(String)
    case migrationFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        case .entityNotFound(let name):
            return "Entity not found: \(name)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .migrationFailed(let error):
            return "Migration failed: \(error.localizedDescription)"
        }
    }
}
