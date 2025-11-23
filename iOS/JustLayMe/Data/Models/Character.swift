import Foundation

// MARK: - Character Model
/// Represents a custom AI character created by a user
/// Matches backend: character-api.js characters table

struct Character: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    var name: String
    var backstory: String?
    var personalityTraits: PersonalityTraits
    var speechPatterns: SpeechPatterns
    var avatarUrl: String?
    var isPublic: Bool
    var createdAt: Date
    var updatedAt: Date

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

    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        backstory: String? = nil,
        personalityTraits: PersonalityTraits = PersonalityTraits(),
        speechPatterns: SpeechPatterns = SpeechPatterns(),
        avatarUrl: String? = nil,
        isPublic: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.backstory = backstory
        self.personalityTraits = personalityTraits
        self.speechPatterns = speechPatterns
        self.avatarUrl = avatarUrl
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Personality Traits
struct PersonalityTraits: Codable, Hashable {
    var personality: String?
    var interests: [String]?
    var quirks: [String]?
    var tone: String?
    var relationship: String?
    var baseModel: String?

    // Numeric trait values (0-10 scale)
    var warmth: Int?
    var humor: Int?
    var intelligence: Int?
    var creativity: Int?
    var assertiveness: Int?

    enum CodingKeys: String, CodingKey {
        case personality
        case interests
        case quirks
        case tone
        case relationship
        case baseModel = "base_model"
        case warmth
        case humor
        case intelligence
        case creativity
        case assertiveness
    }

    init(
        personality: String? = nil,
        interests: [String]? = nil,
        quirks: [String]? = nil,
        tone: String? = nil,
        relationship: String? = nil,
        baseModel: String? = nil,
        warmth: Int? = nil,
        humor: Int? = nil,
        intelligence: Int? = nil,
        creativity: Int? = nil,
        assertiveness: Int? = nil
    ) {
        self.personality = personality
        self.interests = interests
        self.quirks = quirks
        self.tone = tone
        self.relationship = relationship
        self.baseModel = baseModel
        self.warmth = warmth
        self.humor = humor
        self.intelligence = intelligence
        self.creativity = creativity
        self.assertiveness = assertiveness
    }

    /// Returns traits as a dictionary for display
    var traitsDictionary: [String: Int] {
        var traits: [String: Int] = [:]
        if let warmth = warmth { traits["Warmth"] = warmth }
        if let humor = humor { traits["Humor"] = humor }
        if let intelligence = intelligence { traits["Intelligence"] = intelligence }
        if let creativity = creativity { traits["Creativity"] = creativity }
        if let assertiveness = assertiveness { traits["Assertiveness"] = assertiveness }
        return traits
    }
}

// MARK: - Speech Patterns
struct SpeechPatterns: Codable, Hashable {
    var style: String?
    var conversationStyle: String?
    var patterns: [String]?

    enum CodingKeys: String, CodingKey {
        case style
        case conversationStyle = "conversation_style"
        case patterns
    }

    init(
        style: String? = nil,
        conversationStyle: String? = nil,
        patterns: [String]? = nil
    ) {
        self.style = style
        self.conversationStyle = conversationStyle
        self.patterns = patterns
    }
}

// MARK: - Character Customization Options
/// Available options for customizing characters
/// Matches backend: prompt-layer.js getCustomizationOptions()
struct CharacterCustomizationOptions: Codable {
    let personalityTraits: [String]
    let speechStyles: [String]
    let tones: [String]
    let relationshipTypes: [String]
    let conversationStyles: [String]

    enum CodingKeys: String, CodingKey {
        case personalityTraits = "personality_traits"
        case speechStyles = "speech_styles"
        case tones
        case relationshipTypes = "relationship_types"
        case conversationStyles = "conversation_styles"
    }

    static let `default` = CharacterCustomizationOptions(
        personalityTraits: [
            "intellectual and curious",
            "playful and energetic",
            "calm and thoughtful",
            "adventurous and bold",
            "creative and artistic",
            "caring and empathetic",
            "witty and humorous",
            "mysterious and intriguing"
        ],
        speechStyles: [
            "formal and eloquent",
            "casual and friendly",
            "playful and animated",
            "calm and soothing",
            "energetic and enthusiastic",
            "poetic and expressive"
        ],
        tones: [
            "warm and welcoming",
            "cool and mysterious",
            "bright and cheerful",
            "deep and philosophical",
            "light and humorous",
            "passionate and intense"
        ],
        relationshipTypes: [
            "AI companion",
            "virtual friend",
            "mentor and guide",
            "creative partner",
            "conversation partner",
            "study buddy"
        ],
        conversationStyles: [
            "engaging and interactive",
            "deep and meaningful",
            "light and entertaining",
            "supportive and encouraging",
            "challenging and thought-provoking"
        ]
    )
}

// MARK: - Character Creation Request
struct CharacterCreateRequest: Codable {
    let name: String
    let backstory: String?
    let personalityTraits: PersonalityTraits?
    let speechPatterns: SpeechPatterns?

    enum CodingKeys: String, CodingKey {
        case name
        case backstory
        case personalityTraits = "personality_traits"
        case speechPatterns = "speech_patterns"
    }
}

// MARK: - Character Customization Request
struct CharacterCustomizationRequest: Codable {
    var name: String?
    var age: Int?
    var background: String?
    var personalityTraits: String?
    var interests: [String]?
    var speechStyle: String?
    var tone: String?
    var relationshipToUser: String?
    var specialKnowledge: [String]?
    var quirks: [String]?
    var emotionalState: String?
    var conversationStyle: String?
    var boundaries: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case age
        case background
        case personalityTraits = "personality_traits"
        case interests
        case speechStyle = "speech_style"
        case tone
        case relationshipToUser = "relationship_to_user"
        case specialKnowledge = "special_knowledge"
        case quirks
        case emotionalState = "emotional_state"
        case conversationStyle = "conversation_style"
        case boundaries
    }
}
