import Foundation
import CoreData

// MARK: - Character Repository

public final class CharacterRepository: BaseRepository<Character, CDCharacter> {

    // MARK: - Singleton

    public static let shared = CharacterRepository()

    // MARK: - Initialization

    private init() {
        super.init(entityName: "CDCharacter")
    }

    // MARK: - Domain Conversion

    public override func toDomain(_ managedObject: CDCharacter) -> Character {
        Character(
            id: managedObject.id ?? UUID(),
            userId: managedObject.userId ?? UUID(),
            name: managedObject.name ?? "",
            backstory: managedObject.backstory,
            personalityTraits: managedObject.personalityTraits,
            speechPatterns: managedObject.speechPatterns,
            avatarUrl: managedObject.avatarUrl,
            isPublic: managedObject.isPublic,
            createdAt: managedObject.createdAt ?? Date(),
            updatedAt: managedObject.updatedAt
        )
    }

    public override func toManagedObject(_ entity: Character, managedObject: CDCharacter) {
        managedObject.id = entity.id
        managedObject.userId = entity.userId
        managedObject.name = entity.name
        managedObject.backstory = entity.backstory
        managedObject.personalityTraits = entity.personalityTraits
        managedObject.speechPatterns = entity.speechPatterns
        managedObject.avatarUrl = entity.avatarUrl
        managedObject.isPublic = entity.isPublic
        managedObject.createdAt = entity.createdAt
        managedObject.updatedAt = entity.updatedAt
        managedObject.syncStatus = SyncStatus.pendingSync.rawValue
    }

    public override func createManagedObject(from entity: Character, in context: NSManagedObjectContext) -> CDCharacter {
        let managedObject = CDCharacter(context: context)
        toManagedObject(entity, managedObject: managedObject)
        managedObject.syncStatus = SyncStatus.pending.rawValue
        return managedObject
    }

    // MARK: - Custom Queries

    /// Fetch characters for user
    public func fetch(byUserId userId: UUID) async throws -> [Character] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacter.fetchRequest(byUserId: userId)
            let managedObjects = try context.fetch(request)
            return managedObjects.map { self.toDomain($0) }
        }
    }

    /// Fetch public characters
    public func fetchPublicCharacters() async throws -> [Character] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacter.fetchRequest(publicOnly: true)
            let managedObjects = try context.fetch(request)
            return managedObjects.map { self.toDomain($0) }
        }
    }

    /// Search characters by name
    public func search(query: String, userId: UUID? = nil) async throws -> [Character] {
        var predicates: [NSPredicate] = [
            NSPredicate(format: "name CONTAINS[cd] %@", query)
        ]

        if let userId = userId {
            predicates.append(NSPredicate(format: "userId == %@", userId as CVarArg))
        }

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        return try await fetchAll(options: FetchOptions(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)],
            predicate: predicate
        ))
    }

    /// Update character visibility
    public func updateVisibility(characterId: UUID, isPublic: Bool) async throws -> Character {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacter.fetchRequest(byId: characterId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(characterId)
            }

            managedObject.isPublic = isPublic
            managedObject.syncStatus = SyncStatus.pendingSync.rawValue

            return self.toDomain(managedObject)
        }
    }

    /// Update personality traits
    public func updatePersonalityTraits(characterId: UUID, traits: [String: Any]) async throws -> Character {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacter.fetchRequest(byId: characterId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(characterId)
            }

            managedObject.personalityTraits = traits
            managedObject.syncStatus = SyncStatus.pendingSync.rawValue

            return self.toDomain(managedObject)
        }
    }

    /// Add speech pattern
    public func addSpeechPattern(characterId: UUID, pattern: String) async throws -> Character {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacter.fetchRequest(byId: characterId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(characterId)
            }

            var patterns = managedObject.speechPatterns
            if !patterns.contains(pattern) {
                patterns.append(pattern)
                managedObject.speechPatterns = patterns
                managedObject.syncStatus = SyncStatus.pendingSync.rawValue
            }

            return self.toDomain(managedObject)
        }
    }

    /// Remove speech pattern
    public func removeSpeechPattern(characterId: UUID, pattern: String) async throws -> Character {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacter.fetchRequest(byId: characterId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(characterId)
            }

            var patterns = managedObject.speechPatterns
            patterns.removeAll { $0 == pattern }
            managedObject.speechPatterns = patterns
            managedObject.syncStatus = SyncStatus.pendingSync.rawValue

            return self.toDomain(managedObject)
        }
    }

    /// Delete all characters for user
    public func deleteAll(forUserId userId: UUID) async throws {
        let predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        try await deleteWhere(predicate: predicate)
    }

    /// Count characters for user
    public func count(forUserId userId: UUID) async throws -> Int {
        let predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        return try await count(predicate: predicate)
    }
}
