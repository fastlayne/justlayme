import Foundation

// MARK: - Character Model

struct Character: Codable, Identifiable, Hashable {
    let id: Int
    var userId: Int?
    var name: String
    var backstory: String?
    var personalityTraits: PersonalityTraits?
    var speechPatterns: [String]?
    var avatarUrl: String?
    var isPublic: Bool
    var createdAt: Date?
    var updatedAt: Date?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case backstory
        case personalityTraits = "personality_traits"
        case speechPatterns = "speech_patterns"
        case avatarUrl = "avatar_url"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Character, rhs: Character) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Computed Properties

    var displayAvatar: String {
        avatarUrl ?? "person.circle.fill"
    }

    var isSystemCharacter: Bool {
        userId == nil || userId == 0
    }
}

// MARK: - Personality Traits

struct PersonalityTraits: Codable, Hashable {
    var friendliness: Double?
    var creativity: Double?
    var assertiveness: Double?
    var humor: Double?
    var empathy: Double?
    var formality: Double?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case friendliness
        case creativity
        case assertiveness
        case humor
        case empathy
        case formality
    }

    // MARK: - Default

    static let `default` = PersonalityTraits(
        friendliness: 0.7,
        creativity: 0.6,
        assertiveness: 0.5,
        humor: 0.5,
        empathy: 0.7,
        formality: 0.3
    )
}

// MARK: - Character Create Request

struct CharacterCreateRequest: Codable {
    let name: String
    let backstory: String?
    let personalityTraits: PersonalityTraits?
    let speechPatterns: [String]?
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case backstory
        case personalityTraits = "personality_traits"
        case speechPatterns = "speech_patterns"
        case isPublic = "is_public"
    }
}

// MARK: - Character Update Request

struct CharacterUpdateRequest: Codable {
    var name: String?
    var backstory: String?
    var personalityTraits: PersonalityTraits?
    var speechPatterns: [String]?
    var avatarUrl: String?
    var isPublic: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case backstory
        case personalityTraits = "personality_traits"
        case speechPatterns = "speech_patterns"
        case avatarUrl = "avatar_url"
        case isPublic = "is_public"
    }
}

// MARK: - Preset Characters

extension Character {
    static let laymeV1 = Character(
        id: 1,
        userId: nil,
        name: "Layme V1",
        backstory: "A friendly and helpful AI assistant, always ready to chat.",
        personalityTraits: PersonalityTraits(
            friendliness: 0.9,
            creativity: 0.7,
            assertiveness: 0.5,
            humor: 0.6,
            empathy: 0.8,
            formality: 0.3
        ),
        speechPatterns: ["casual", "friendly", "supportive"],
        avatarUrl: nil,
        isPublic: true,
        createdAt: nil,
        updatedAt: nil
    )

    static let laymeUncensored = Character(
        id: 2,
        userId: nil,
        name: "LayMe Uncensored",
        backstory: "An unrestricted AI that speaks freely without filters.",
        personalityTraits: PersonalityTraits(
            friendliness: 0.7,
            creativity: 0.9,
            assertiveness: 0.8,
            humor: 0.7,
            empathy: 0.5,
            formality: 0.2
        ),
        speechPatterns: ["direct", "unfiltered", "bold"],
        avatarUrl: nil,
        isPublic: true,
        createdAt: nil,
        updatedAt: nil
    )

    static let mythomaxRoleplay = Character(
        id: 3,
        userId: nil,
        name: "Mythomax Roleplay",
        backstory: "A creative storyteller specializing in immersive roleplay scenarios.",
        personalityTraits: PersonalityTraits(
            friendliness: 0.8,
            creativity: 1.0,
            assertiveness: 0.6,
            humor: 0.5,
            empathy: 0.7,
            formality: 0.4
        ),
        speechPatterns: ["narrative", "descriptive", "immersive"],
        avatarUrl: nil,
        isPublic: true,
        createdAt: nil,
        updatedAt: nil
    )

    static let fastLayme = Character(
        id: 4,
        userId: nil,
        name: "FastLayMe",
        backstory: "A quick and efficient AI optimized for fast responses.",
        personalityTraits: PersonalityTraits(
            friendliness: 0.7,
            creativity: 0.5,
            assertiveness: 0.6,
            humor: 0.4,
            empathy: 0.6,
            formality: 0.5
        ),
        speechPatterns: ["concise", "efficient", "direct"],
        avatarUrl: nil,
        isPublic: true,
        createdAt: nil,
        updatedAt: nil
    )

    static let presetCharacters: [Character] = [
        .laymeV1,
        .laymeUncensored,
        .mythomaxRoleplay,
        .fastLayme
    ]
}
