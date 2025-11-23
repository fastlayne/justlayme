import Foundation
import CoreData

// MARK: - Character Learning Repository

public final class CharacterLearningRepository: BaseRepository<CharacterLearning, CDCharacterLearning> {

    // MARK: - Singleton

    public static let shared = CharacterLearningRepository()

    // MARK: - Initialization

    private init() {
        super.init(entityName: "CDCharacterLearning")
    }

    // MARK: - Domain Conversion

    public override func toDomain(_ managedObject: CDCharacterLearning) -> CharacterLearning {
        CharacterLearning(
            id: managedObject.id ?? UUID(),
            characterId: managedObject.characterId ?? UUID(),
            patternType: PatternType(rawValue: managedObject.patternType ?? "") ?? .speech,
            userInput: managedObject.userInput ?? "",
            expectedOutput: managedObject.expectedOutput ?? "",
            confidence: managedObject.confidence,
            createdAt: managedObject.createdAt ?? Date()
        )
    }

    public override func toManagedObject(_ entity: CharacterLearning, managedObject: CDCharacterLearning) {
        managedObject.id = entity.id
        managedObject.characterId = entity.characterId
        managedObject.patternType = entity.patternType.rawValue
        managedObject.userInput = entity.userInput
        managedObject.expectedOutput = entity.expectedOutput
        managedObject.confidence = entity.confidence
        managedObject.createdAt = entity.createdAt
        managedObject.syncStatus = SyncStatus.pendingSync.rawValue
    }

    public override func createManagedObject(from entity: CharacterLearning, in context: NSManagedObjectContext) -> CDCharacterLearning {
        let managedObject = CDCharacterLearning(context: context)
        toManagedObject(entity, managedObject: managedObject)
        managedObject.syncStatus = SyncStatus.pending.rawValue
        return managedObject
    }

    // MARK: - Custom Queries

    /// Fetch learning patterns for character
    public func fetch(byCharacterId characterId: UUID) async throws -> [CharacterLearning] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacterLearning.fetchRequest(byCharacterId: characterId)
            let managedObjects = try context.fetch(request)
            return managedObjects.map { self.toDomain($0) }
        }
    }

    /// Fetch patterns by type
    public func fetch(byPatternType type: PatternType, characterId: UUID) async throws -> [CharacterLearning] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacterLearning.fetchRequest(byPatternType: type, characterId: characterId)
            let managedObjects = try context.fetch(request)
            return managedObjects.map { self.toDomain($0) }
        }
    }

    /// Fetch high confidence patterns
    public func fetchHighConfidence(characterId: UUID, threshold: Double = 0.8) async throws -> [CharacterLearning] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacterLearning.fetchRequest(highConfidence: threshold, characterId: characterId)
            let managedObjects = try context.fetch(request)
            return managedObjects.map { self.toDomain($0) }
        }
    }

    /// Reinforce a pattern (increase confidence)
    public func reinforce(patternId: UUID) async throws -> CharacterLearning {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacterLearning.fetchRequest(byId: patternId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(patternId)
            }

            managedObject.reinforce()
            return self.toDomain(managedObject)
        }
    }

    /// Weaken a pattern (decrease confidence)
    public func weaken(patternId: UUID) async throws -> CharacterLearning {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacterLearning.fetchRequest(byId: patternId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(patternId)
            }

            managedObject.weaken()
            return self.toDomain(managedObject)
        }
    }

    /// Adjust confidence
    public func adjustConfidence(patternId: UUID, delta: Double) async throws -> CharacterLearning {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacterLearning.fetchRequest(byId: patternId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(patternId)
            }

            managedObject.adjustConfidence(by: delta)
            return self.toDomain(managedObject)
        }
    }

    /// Delete low confidence patterns
    public func deleteLowConfidence(characterId: UUID, threshold: Double = 0.2) async throws {
        let predicate = NSPredicate(
            format: "characterId == %@ AND confidence < %f",
            characterId as CVarArg, threshold
        )
        try await deleteWhere(predicate: predicate)
    }

    /// Delete all patterns for character
    public func deleteAll(forCharacterId characterId: UUID) async throws {
        let predicate = NSPredicate(format: "characterId == %@", characterId as CVarArg)
        try await deleteWhere(predicate: predicate)
    }

    /// Count patterns by type
    public func count(byPatternType type: PatternType, characterId: UUID) async throws -> Int {
        let predicate = NSPredicate(
            format: "characterId == %@ AND patternType == %@",
            characterId as CVarArg, type.rawValue
        )
        return try await count(predicate: predicate)
    }
}
