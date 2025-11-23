import Foundation
import SwiftData

// MARK: - Character Entity
/// SwiftData persistent model for Character

@Model
final class CharacterEntity {
    // MARK: - Properties

    @Attribute(.unique)
    var id: String

    var userId: String
    var name: String
    var backstory: String?
    var avatarUrl: String?
    var isPublic: Bool
    var createdAt: Date
    var updatedAt: Date

    // JSON encoded complex types
    var personalityTraitsJSON: Data?
    var speechPatternsJSON: Data?

    // Local-only flags
    var needsSync: Bool
    var isLocalOnly: Bool

    // MARK: - Relationships

    var user: UserEntity?

    @Relationship(deleteRule: .cascade, inverse: \CharacterMemoryEntity.character)
    var memories: [CharacterMemoryEntity]?

    @Relationship(deleteRule: .cascade, inverse: \CharacterLearningEntity.character)
    var learnings: [CharacterLearningEntity]?

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        backstory: String? = nil,
        personalityTraits: PersonalityTraits? = nil,
        speechPatterns: SpeechPatterns? = nil,
        avatarUrl: String? = nil,
        isPublic: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        needsSync: Bool = true,
        isLocalOnly: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.backstory = backstory
        self.avatarUrl = avatarUrl
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.needsSync = needsSync
        self.isLocalOnly = isLocalOnly

        if let traits = personalityTraits {
            self.personalityTraitsJSON = try? JSONEncoder().encode(traits)
        }
        if let patterns = speechPatterns {
            self.speechPatternsJSON = try? JSONEncoder().encode(patterns)
        }
    }

    // MARK: - Conversion

    /// Convert from API model
    convenience init(from character: Character) {
        self.init(
            id: character.id,
            userId: character.userId,
            name: character.name,
            backstory: character.backstory,
            personalityTraits: character.personalityTraits,
            speechPatterns: character.speechPatterns,
            avatarUrl: character.avatarUrl,
            isPublic: character.isPublic,
            createdAt: character.createdAt,
            updatedAt: character.updatedAt,
            needsSync: false,
            isLocalOnly: false
        )
    }

    /// Convert to API model
    func toModel() -> Character {
        return Character(
            id: id,
            userId: userId,
            name: name,
            backstory: backstory,
            personalityTraits: personalityTraits ?? PersonalityTraits(),
            speechPatterns: speechPatterns ?? SpeechPatterns(),
            avatarUrl: avatarUrl,
            isPublic: isPublic,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Computed Properties

    /// Decoded personality traits
    var personalityTraits: PersonalityTraits? {
        guard let data = personalityTraitsJSON else { return nil }
        return try? JSONDecoder().decode(PersonalityTraits.self, from: data)
    }

    /// Set personality traits
    func setPersonalityTraits(_ traits: PersonalityTraits?) {
        if let traits = traits {
            self.personalityTraitsJSON = try? JSONEncoder().encode(traits)
        } else {
            self.personalityTraitsJSON = nil
        }
        self.updatedAt = Date()
        self.needsSync = true
    }

    /// Decoded speech patterns
    var speechPatterns: SpeechPatterns? {
        guard let data = speechPatternsJSON else { return nil }
        return try? JSONDecoder().decode(SpeechPatterns.self, from: data)
    }

    /// Set speech patterns
    func setSpeechPatterns(_ patterns: SpeechPatterns?) {
        if let patterns = patterns {
            self.speechPatternsJSON = try? JSONEncoder().encode(patterns)
        } else {
            self.speechPatternsJSON = nil
        }
        self.updatedAt = Date()
        self.needsSync = true
    }

    /// Memory count
    var memoryCount: Int {
        return memories?.count ?? 0
    }

    /// Learning count
    var learningCount: Int {
        return learnings?.count ?? 0
    }
}

// MARK: - Character Memory Entity
/// SwiftData persistent model for CharacterMemory

@Model
final class CharacterMemoryEntity {
    @Attribute(.unique)
    var id: String

    var characterId: String
    var userMessage: String
    var aiResponse: String
    var feedbackScore: Int?
    var correctedResponse: String?
    var importanceScore: Double
    var createdAt: Date

    var character: CharacterEntity?

    init(
        id: String = UUID().uuidString,
        characterId: String,
        userMessage: String,
        aiResponse: String,
        feedbackScore: Int? = nil,
        correctedResponse: String? = nil,
        importanceScore: Double = 0.5,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.characterId = characterId
        self.userMessage = userMessage
        self.aiResponse = aiResponse
        self.feedbackScore = feedbackScore
        self.correctedResponse = correctedResponse
        self.importanceScore = importanceScore
        self.createdAt = createdAt
    }

    /// Convert from API model
    convenience init(from memory: CharacterMemory) {
        self.init(
            id: memory.id,
            characterId: memory.characterId,
            userMessage: memory.userMessage,
            aiResponse: memory.aiResponse,
            feedbackScore: memory.feedbackScore,
            correctedResponse: memory.correctedResponse,
            importanceScore: memory.importanceScore,
            createdAt: memory.createdAt
        )
    }

    /// Convert to API model
    func toModel() -> CharacterMemory {
        return CharacterMemory(
            id: id,
            characterId: characterId,
            userMessage: userMessage,
            aiResponse: aiResponse,
            feedbackScore: feedbackScore,
            correctedResponse: correctedResponse,
            importanceScore: importanceScore,
            createdAt: createdAt
        )
    }
}

// MARK: - Character Learning Entity
/// SwiftData persistent model for CharacterLearning

@Model
final class CharacterLearningEntity {
    @Attribute(.unique)
    var id: String

    var characterId: String
    var patternType: String?
    var userInput: String
    var expectedOutput: String
    var confidence: Double
    var createdAt: Date

    var character: CharacterEntity?

    init(
        id: String = UUID().uuidString,
        characterId: String,
        patternType: String? = nil,
        userInput: String,
        expectedOutput: String,
        confidence: Double = 1.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.characterId = characterId
        self.patternType = patternType
        self.userInput = userInput
        self.expectedOutput = expectedOutput
        self.confidence = confidence
        self.createdAt = createdAt
    }

    /// Convert from API model
    convenience init(from learning: CharacterLearning) {
        self.init(
            id: learning.id,
            characterId: learning.characterId,
            patternType: learning.patternType,
            userInput: learning.userInput,
            expectedOutput: learning.expectedOutput,
            confidence: learning.confidence,
            createdAt: learning.createdAt
        )
    }

    /// Convert to API model
    func toModel() -> CharacterLearning {
        return CharacterLearning(
            id: id,
            characterId: characterId,
            patternType: patternType,
            userInput: userInput,
            expectedOutput: expectedOutput,
            confidence: confidence,
            createdAt: createdAt
        )
    }
}

// MARK: - Fetch Descriptors
extension CharacterEntity {

    /// Fetch descriptor for user's characters
    static func fetchDescriptor(userId: String) -> FetchDescriptor<CharacterEntity> {
        let predicate = #Predicate<CharacterEntity> { $0.userId == userId }
        var descriptor = FetchDescriptor<CharacterEntity>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        return descriptor
    }

    /// Fetch descriptor for public characters
    static func publicCharactersDescriptor() -> FetchDescriptor<CharacterEntity> {
        let predicate = #Predicate<CharacterEntity> { $0.isPublic == true }
        var descriptor = FetchDescriptor<CharacterEntity>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.name, order: .forward)]
        return descriptor
    }
}
