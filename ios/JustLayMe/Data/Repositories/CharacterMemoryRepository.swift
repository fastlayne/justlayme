import Foundation
import CoreData

// MARK: - Character Memory Repository

public final class CharacterMemoryRepository: BaseRepository<CharacterMemory, CDCharacterMemory> {

    // MARK: - Singleton

    public static let shared = CharacterMemoryRepository()

    // MARK: - Initialization

    private init() {
        super.init(entityName: "CDCharacterMemory")
    }

    // MARK: - Domain Conversion

    public override func toDomain(_ managedObject: CDCharacterMemory) -> CharacterMemory {
        CharacterMemory(
            id: managedObject.id ?? UUID(),
            characterId: managedObject.characterId ?? UUID(),
            userMessage: managedObject.userMessage ?? "",
            aiResponse: managedObject.aiResponse ?? "",
            feedbackScore: managedObject.feedbackScoreValue,
            correctedResponse: managedObject.correctedResponse,
            importanceScore: managedObject.importanceScore,
            createdAt: managedObject.createdAt ?? Date()
        )
    }

    public override func toManagedObject(_ entity: CharacterMemory, managedObject: CDCharacterMemory) {
        managedObject.id = entity.id
        managedObject.characterId = entity.characterId
        managedObject.userMessage = entity.userMessage
        managedObject.aiResponse = entity.aiResponse
        managedObject.feedbackScoreValue = entity.feedbackScore
        managedObject.correctedResponse = entity.correctedResponse
        managedObject.importanceScore = entity.importanceScore
        managedObject.createdAt = entity.createdAt
        managedObject.syncStatus = SyncStatus.pendingSync.rawValue
    }

    public override func createManagedObject(from entity: CharacterMemory, in context: NSManagedObjectContext) -> CDCharacterMemory {
        let managedObject = CDCharacterMemory(context: context)
        toManagedObject(entity, managedObject: managedObject)
        managedObject.syncStatus = SyncStatus.pending.rawValue
        return managedObject
    }

    // MARK: - Custom Queries

    /// Fetch memories for character
    public func fetch(byCharacterId characterId: UUID) async throws -> [CharacterMemory] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacterMemory.fetchRequest(byCharacterId: characterId)
            let managedObjects = try context.fetch(request)
            return managedObjects.map { self.toDomain($0) }
        }
    }

    /// Fetch high importance memories
    public func fetchHighImportance(characterId: UUID, threshold: Double = 0.7) async throws -> [CharacterMemory] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacterMemory.fetchRequest(highImportance: threshold, characterId: characterId)
            let managedObjects = try context.fetch(request)
            return managedObjects.map { self.toDomain($0) }
        }
    }

    /// Fetch memories with feedback
    public func fetchWithFeedback(characterId: UUID) async throws -> [CharacterMemory] {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacterMemory.fetchRequest(withFeedback: characterId)
            let managedObjects = try context.fetch(request)
            return managedObjects.map { self.toDomain($0) }
        }
    }

    /// Apply feedback to memory
    public func applyFeedback(memoryId: UUID, score: Int, correctedResponse: String? = nil) async throws -> CharacterMemory {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacterMemory.fetchRequest(byId: memoryId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(memoryId)
            }

            managedObject.applyFeedback(score: score, correctedResponse: correctedResponse)
            return self.toDomain(managedObject)
        }
    }

    /// Update importance score
    public func updateImportance(memoryId: UUID, score: Double) async throws -> CharacterMemory {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacterMemory.fetchRequest(byId: memoryId)
            guard let managedObject = try context.fetch(request).first else {
                throw RepositoryError.notFound(memoryId)
            }

            managedObject.importanceScore = max(0.0, min(1.0, score))
            managedObject.syncStatus = SyncStatus.pendingSync.rawValue

            return self.toDomain(managedObject)
        }
    }

    /// Delete all memories for character
    public func deleteAll(forCharacterId characterId: UUID) async throws {
        let predicate = NSPredicate(format: "characterId == %@", characterId as CVarArg)
        try await deleteWhere(predicate: predicate)
    }

    /// Get average feedback score for character
    public func averageFeedbackScore(characterId: UUID) async throws -> Double? {
        try await coreDataStack.performBackgroundTask { [weak self] context in
            guard self != nil else { throw RepositoryError.contextNotAvailable }

            let request = CDCharacterMemory.fetchRequest(withFeedback: characterId)
            let memories = try context.fetch(request)

            let scores = memories.compactMap { $0.feedbackScoreValue }
            guard !scores.isEmpty else { return nil }

            return Double(scores.reduce(0, +)) / Double(scores.count)
        }
    }
}
