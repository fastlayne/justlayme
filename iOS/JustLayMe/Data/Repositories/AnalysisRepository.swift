import Foundation
import SwiftData
import Combine

// MARK: - Analysis Repository Protocol
/// Protocol defining character analysis and learning data operations

protocol AnalysisRepositoryProtocol {
    // Character Memories
    func getMemories(characterId: String) -> AnyPublisher<[CharacterMemory], Error>
    func addMemory(_ memory: CharacterMemory) -> AnyPublisher<CharacterMemory, Error>
    func updateMemory(id: String, feedbackScore: Int, correctedResponse: String?) -> AnyPublisher<CharacterMemory, Error>
    func deleteMemory(id: String) -> AnyPublisher<Void, Error>

    // Character Learning
    func getLearnings(characterId: String) -> AnyPublisher<[CharacterLearning], Error>
    func addLearning(_ learning: CharacterLearning) -> AnyPublisher<CharacterLearning, Error>

    // Analysis Stats
    func getAnalysisStats(characterId: String) -> AnyPublisher<AnalysisStats, Error>
}

// MARK: - Analysis Stats
struct AnalysisStats: Codable {
    let totalMemories: Int
    let totalLearnings: Int
    let averageFeedbackScore: Double
    let topPatterns: [String]
    let lastActivityDate: Date?

    init(
        totalMemories: Int = 0,
        totalLearnings: Int = 0,
        averageFeedbackScore: Double = 0,
        topPatterns: [String] = [],
        lastActivityDate: Date? = nil
    ) {
        self.totalMemories = totalMemories
        self.totalLearnings = totalLearnings
        self.averageFeedbackScore = averageFeedbackScore
        self.topPatterns = topPatterns
        self.lastActivityDate = lastActivityDate
    }
}

// MARK: - Analysis Repository
/// Repository for managing character analysis data (memories and learning patterns)

@MainActor
final class AnalysisRepository: AnalysisRepositoryProtocol, ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var memories: [CharacterMemory] = []
    @Published private(set) var learnings: [CharacterLearning] = []
    @Published private(set) var stats: AnalysisStats = AnalysisStats()
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    // MARK: - Private Properties

    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Publishers

    /// Publisher for memory updates
    var memoriesPublisher: AnyPublisher<[CharacterMemory], Never> {
        $memories.eraseToAnyPublisher()
    }

    /// Publisher for learning updates
    var learningsPublisher: AnyPublisher<[CharacterLearning], Never> {
        $learnings.eraseToAnyPublisher()
    }

    /// Publisher for stats updates
    var statsPublisher: AnyPublisher<AnalysisStats, Never> {
        $stats.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(modelContext: ModelContext = DataContainer.shared.mainContext) {
        self.modelContext = modelContext
    }

    // MARK: - Memory Operations

    func getMemories(characterId: String) -> AnyPublisher<[CharacterMemory], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    self.isLoading = true

                    let predicate = #Predicate<CharacterMemoryEntity> { $0.characterId == characterId }
                    var descriptor = FetchDescriptor<CharacterMemoryEntity>(predicate: predicate)
                    descriptor.sortBy = [
                        SortDescriptor(\.importanceScore, order: .reverse),
                        SortDescriptor(\.createdAt, order: .reverse)
                    ]

                    let entities = try self.modelContext.fetch(descriptor)
                    let memories = entities.map { $0.toModel() }

                    self.memories = memories
                    self.isLoading = false

                    promise(.success(memories))
                } catch {
                    self.error = error
                    self.isLoading = false
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func addMemory(_ memory: CharacterMemory) -> AnyPublisher<CharacterMemory, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let entity = CharacterMemoryEntity(from: memory)

                    // Link to character if exists
                    let characterId = memory.characterId
                    let predicate = #Predicate<CharacterEntity> { $0.id == characterId }
                    var descriptor = FetchDescriptor<CharacterEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    if let character = try self.modelContext.fetch(descriptor).first {
                        entity.character = character
                    }

                    self.modelContext.insert(entity)
                    try self.modelContext.save()

                    let added = entity.toModel()
                    self.memories.insert(added, at: 0)

                    promise(.success(added))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func updateMemory(id: String, feedbackScore: Int, correctedResponse: String?) -> AnyPublisher<CharacterMemory, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let predicate = #Predicate<CharacterMemoryEntity> { $0.id == id }
                    var descriptor = FetchDescriptor<CharacterMemoryEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    guard let entity = try self.modelContext.fetch(descriptor).first else {
                        throw RepositoryError.notFound
                    }

                    // Update feedback
                    entity.feedbackScore = feedbackScore
                    entity.correctedResponse = correctedResponse

                    // Adjust importance score based on feedback
                    let multiplier = feedbackScore > 3 ? 1.2 : 0.8
                    entity.importanceScore = min(entity.importanceScore * multiplier, 1.0)

                    try self.modelContext.save()

                    let updated = entity.toModel()

                    // Update local cache
                    if let index = self.memories.firstIndex(where: { $0.id == id }) {
                        self.memories[index] = updated
                    }

                    // If correction provided, create a learning pattern
                    if let corrected = correctedResponse {
                        let learning = CharacterLearning(
                            characterId: entity.characterId,
                            patternType: "speech",
                            userInput: entity.userMessage,
                            expectedOutput: corrected,
                            confidence: 0.9
                        )
                        _ = self.addLearning(learning)
                            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                    }

                    promise(.success(updated))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteMemory(id: String) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let predicate = #Predicate<CharacterMemoryEntity> { $0.id == id }
                    var descriptor = FetchDescriptor<CharacterMemoryEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    guard let entity = try self.modelContext.fetch(descriptor).first else {
                        throw RepositoryError.notFound
                    }

                    self.modelContext.delete(entity)
                    try self.modelContext.save()

                    // Update local cache
                    self.memories.removeAll { $0.id == id }

                    promise(.success(()))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Learning Operations

    func getLearnings(characterId: String) -> AnyPublisher<[CharacterLearning], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    self.isLoading = true

                    let predicate = #Predicate<CharacterLearningEntity> {
                        $0.characterId == characterId && $0.confidence > 0.7
                    }
                    var descriptor = FetchDescriptor<CharacterLearningEntity>(predicate: predicate)
                    descriptor.sortBy = [SortDescriptor(\.confidence, order: .reverse)]

                    let entities = try self.modelContext.fetch(descriptor)
                    let learnings = entities.map { $0.toModel() }

                    self.learnings = learnings
                    self.isLoading = false

                    promise(.success(learnings))
                } catch {
                    self.error = error
                    self.isLoading = false
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func addLearning(_ learning: CharacterLearning) -> AnyPublisher<CharacterLearning, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let entity = CharacterLearningEntity(from: learning)

                    // Link to character if exists
                    let characterId = learning.characterId
                    let predicate = #Predicate<CharacterEntity> { $0.id == characterId }
                    var descriptor = FetchDescriptor<CharacterEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    if let character = try self.modelContext.fetch(descriptor).first {
                        entity.character = character
                    }

                    self.modelContext.insert(entity)
                    try self.modelContext.save()

                    let added = entity.toModel()
                    self.learnings.insert(added, at: 0)

                    promise(.success(added))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Stats

    func getAnalysisStats(characterId: String) -> AnyPublisher<AnalysisStats, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    // Count memories
                    let memoryPredicate = #Predicate<CharacterMemoryEntity> { $0.characterId == characterId }
                    let memoryCount = try self.modelContext.fetchCount(
                        FetchDescriptor<CharacterMemoryEntity>(predicate: memoryPredicate)
                    )

                    // Count learnings
                    let learningPredicate = #Predicate<CharacterLearningEntity> { $0.characterId == characterId }
                    let learningCount = try self.modelContext.fetchCount(
                        FetchDescriptor<CharacterLearningEntity>(predicate: learningPredicate)
                    )

                    // Calculate average feedback score
                    let memories = try self.modelContext.fetch(
                        FetchDescriptor<CharacterMemoryEntity>(predicate: memoryPredicate)
                    )
                    let scores = memories.compactMap { $0.feedbackScore }
                    let averageScore = scores.isEmpty ? 0.0 : Double(scores.reduce(0, +)) / Double(scores.count)

                    // Get top patterns
                    let learnings = try self.modelContext.fetch(
                        FetchDescriptor<CharacterLearningEntity>(predicate: learningPredicate)
                    )
                    let patterns = learnings.compactMap { $0.patternType }
                    let patternCounts = Dictionary(grouping: patterns, by: { $0 }).mapValues { $0.count }
                    let topPatterns = patternCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }

                    // Get last activity date
                    let lastMemoryDate = memories.map { $0.createdAt }.max()
                    let lastLearningDate = learnings.map { $0.createdAt }.max()
                    let lastActivity = [lastMemoryDate, lastLearningDate].compactMap { $0 }.max()

                    let stats = AnalysisStats(
                        totalMemories: memoryCount,
                        totalLearnings: learningCount,
                        averageFeedbackScore: averageScore,
                        topPatterns: topPatterns,
                        lastActivityDate: lastActivity
                    )

                    self.stats = stats

                    promise(.success(stats))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Helpers

    /// Clear all analysis data for a character
    func clearCharacterData(characterId: String) async throws {
        // Delete memories
        let memoryPredicate = #Predicate<CharacterMemoryEntity> { $0.characterId == characterId }
        try modelContext.delete(model: CharacterMemoryEntity.self, where: memoryPredicate)

        // Delete learnings
        let learningPredicate = #Predicate<CharacterLearningEntity> { $0.characterId == characterId }
        try modelContext.delete(model: CharacterLearningEntity.self, where: learningPredicate)

        try modelContext.save()

        memories = []
        learnings = []
        stats = AnalysisStats()
    }

    /// Get important memories for context building
    func getImportantMemories(characterId: String, limit: Int = 10) async throws -> [CharacterMemory] {
        let predicate = #Predicate<CharacterMemoryEntity> { $0.characterId == characterId }
        var descriptor = FetchDescriptor<CharacterMemoryEntity>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.importanceScore, order: .reverse)]
        descriptor.fetchLimit = limit

        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.toModel() }
    }

    /// Get high-confidence learnings for prompt building
    func getHighConfidenceLearnings(characterId: String, limit: Int = 5) async throws -> [CharacterLearning] {
        let predicate = #Predicate<CharacterLearningEntity> {
            $0.characterId == characterId && $0.confidence > 0.7
        }
        var descriptor = FetchDescriptor<CharacterLearningEntity>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.confidence, order: .reverse)]
        descriptor.fetchLimit = limit

        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.toModel() }
    }
}
