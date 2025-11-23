import Foundation
import CoreData

// MARK: - Migration Version

public struct MigrationVersion: Comparable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public var string: String {
        "\(major).\(minor).\(patch)"
    }

    public init(_ string: String) {
        let components = string.split(separator: ".").compactMap { Int($0) }
        major = components.count > 0 ? components[0] : 0
        minor = components.count > 1 ? components[1] : 0
        patch = components.count > 2 ? components[2] : 0
    }

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static func < (lhs: MigrationVersion, rhs: MigrationVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

// MARK: - Migration Step

public protocol MigrationStep {
    var fromVersion: MigrationVersion { get }
    var toVersion: MigrationVersion { get }
    var description: String { get }

    func migrate(context: NSManagedObjectContext) async throws
}

// MARK: - Migration Manager

public final class MigrationManager {

    // MARK: - Singleton

    public static let shared = MigrationManager()

    // MARK: - Properties

    private let coreDataStack: CoreDataStack
    private let userDefaults: UserDefaults
    private let versionKey = "dataModelVersion"

    public private(set) var currentVersion: MigrationVersion {
        get {
            let string = userDefaults.string(forKey: versionKey) ?? "1.0.0"
            return MigrationVersion(string)
        }
        set {
            userDefaults.set(newValue.string, forKey: versionKey)
        }
    }

    public let targetVersion = MigrationVersion(major: 1, minor: 0, patch: 0)

    private var migrationSteps: [MigrationStep] = []

    // MARK: - Initialization

    private init(coreDataStack: CoreDataStack = .shared, userDefaults: UserDefaults = .standard) {
        self.coreDataStack = coreDataStack
        self.userDefaults = userDefaults
        registerMigrationSteps()
    }

    // MARK: - Registration

    private func registerMigrationSteps() {
        // Register migration steps in order
        // migrationSteps.append(Migration_1_0_to_1_1())
        // migrationSteps.append(Migration_1_1_to_1_2())
    }

    public func register(step: MigrationStep) {
        migrationSteps.append(step)
        migrationSteps.sort { $0.fromVersion < $1.fromVersion }
    }

    // MARK: - Migration

    public var needsMigration: Bool {
        currentVersion < targetVersion
    }

    public func migrateIfNeeded() async throws {
        guard needsMigration else { return }

        let applicableSteps = migrationSteps.filter { step in
            step.fromVersion >= currentVersion && step.toVersion <= targetVersion
        }

        for step in applicableSteps {
            try await performMigration(step)
        }

        currentVersion = targetVersion
    }

    private func performMigration(_ step: MigrationStep) async throws {
        print("Migrating from \(step.fromVersion.string) to \(step.toVersion.string): \(step.description)")

        try await coreDataStack.performBackgroundTask { context in
            try await step.migrate(context: context)
        }
    }

    // MARK: - Core Data Migration

    /// Check if Core Data store needs migration
    public func checkCoreDataMigration() throws -> Bool {
        let storeURL = getStoreURL()
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return false
        }

        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL
        )

        guard let model = NSManagedObjectModel.mergedModel(from: nil) else {
            throw MigrationError.modelNotFound
        }

        return !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
    }

    /// Perform lightweight migration
    public func performLightweightMigration() throws {
        let storeURL = getStoreURL()

        let options: [String: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: getCurrentModel())

        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: options
        )
    }

    /// Perform manual migration with mapping model
    public func performManualMigration(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel,
        mappingModel: NSMappingModel
    ) throws {
        let storeURL = getStoreURL()
        let tempURL = storeURL.deletingLastPathComponent().appendingPathComponent("Migration.sqlite")

        let migrationManager = NSMigrationManager(
            sourceModel: sourceModel,
            destinationModel: destinationModel
        )

        try migrationManager.migrateStore(
            from: storeURL,
            sourceType: NSSQLiteStoreType,
            options: nil,
            with: mappingModel,
            toDestinationURL: tempURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: nil
        )

        // Replace old store with migrated store
        let fileManager = FileManager.default
        try fileManager.removeItem(at: storeURL)
        try fileManager.moveItem(at: tempURL, to: storeURL)
    }

    // MARK: - Helpers

    private func getStoreURL() -> URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("JustLayMe").appendingPathComponent("JustLayMe.sqlite")
    }

    private func getCurrentModel() -> NSManagedObjectModel {
        guard let model = NSManagedObjectModel.mergedModel(from: nil) else {
            fatalError("Could not load Core Data model")
        }
        return model
    }

    // MARK: - Backup & Restore

    /// Create backup before migration
    public func createBackup() throws -> URL {
        let storeURL = getStoreURL()
        let backupURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("Backup_\(Date().timeIntervalSince1970).sqlite")

        try FileManager.default.copyItem(at: storeURL, to: backupURL)

        // Also copy WAL and SHM files if they exist
        let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")

        if FileManager.default.fileExists(atPath: walURL.path) {
            try FileManager.default.copyItem(
                at: walURL,
                to: backupURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            )
        }

        if FileManager.default.fileExists(atPath: shmURL.path) {
            try FileManager.default.copyItem(
                at: shmURL,
                to: backupURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            )
        }

        return backupURL
    }

    /// Restore from backup
    public func restoreFromBackup(_ backupURL: URL) throws {
        let storeURL = getStoreURL()
        let fileManager = FileManager.default

        // Remove current store
        try? fileManager.removeItem(at: storeURL)
        try? fileManager.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
        try? fileManager.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))

        // Restore backup
        try fileManager.copyItem(at: backupURL, to: storeURL)

        let walBackup = backupURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let shmBackup = backupURL.deletingPathExtension().appendingPathExtension("sqlite-shm")

        if fileManager.fileExists(atPath: walBackup.path) {
            try fileManager.copyItem(
                at: walBackup,
                to: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            )
        }

        if fileManager.fileExists(atPath: shmBackup.path) {
            try fileManager.copyItem(
                at: shmBackup,
                to: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            )
        }
    }

    /// List available backups
    public func listBackups() throws -> [URL] {
        let storeDirectory = getStoreURL().deletingLastPathComponent()
        let contents = try FileManager.default.contentsOfDirectory(
            at: storeDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )

        return contents.filter { $0.lastPathComponent.hasPrefix("Backup_") && $0.pathExtension == "sqlite" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
    }

    /// Delete old backups (keep last N)
    public func cleanupBackups(keepLast: Int = 3) throws {
        let backups = try listBackups()
        let toDelete = backups.dropFirst(keepLast)

        for url in toDelete {
            try FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-wal"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-shm"))
        }
    }
}

// MARK: - Migration Error

public enum MigrationError: LocalizedError {
    case modelNotFound
    case mappingModelNotFound
    case migrationFailed(Error)
    case backupFailed
    case restoreFailed

    public var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Core Data model not found"
        case .mappingModelNotFound:
            return "Mapping model not found for migration"
        case .migrationFailed(let error):
            return "Migration failed: \(error.localizedDescription)"
        case .backupFailed:
            return "Failed to create backup"
        case .restoreFailed:
            return "Failed to restore from backup"
        }
    }
}

// MARK: - Example Migration Steps

/*
public struct Migration_1_0_to_1_1: MigrationStep {
    public var fromVersion = MigrationVersion(major: 1, minor: 0, patch: 0)
    public var toVersion = MigrationVersion(major: 1, minor: 1, patch: 0)
    public var description = "Add new field to User entity"

    public func migrate(context: NSManagedObjectContext) async throws {
        let request = NSFetchRequest<CDUser>(entityName: "CDUser")
        let users = try context.fetch(request)

        for user in users {
            // Perform data transformation
            user.someNewField = "default value"
        }

        try context.save()
    }
}
*/
