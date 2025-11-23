import Foundation

// MARK: - Character Models

struct AICharacter: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var backstory: String?
    var personalityTraits: [String: Int]?
    var speechPatterns: [String]?
    var avatarURL: String?
    var isPublic: Bool
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, backstory
        case personalityTraits = "personality_traits"
        case speechPatterns = "speech_patterns"
        case avatarURL = "avatar_url"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum CharacterType: String, CaseIterable, Codable, Equatable {
    case laymeV1 = "layme_v1"
    case uncensoredGPT = "uncensored_gpt"
    case roleplay = "roleplay"
    case companion = "companion"

    var displayName: String {
        switch self {
        case .laymeV1: return "Layme V1"
        case .uncensoredGPT: return "LayMe Uncensored"
        case .roleplay: return "Mythomax Roleplay"
        case .companion: return "FastLayMe"
        }
    }

    var isPremium: Bool {
        self != .laymeV1
    }

    var freeMessageLimit: Int {
        isPremium ? 3 : Int.max
    }

    var iconName: String {
        switch self {
        case .laymeV1: return "star.fill"
        case .uncensoredGPT: return "flame.fill"
        case .roleplay: return "theatermasks.fill"
        case .companion: return "bolt.fill"
        }
    }
}

struct CharacterCustomization: Codable, Equatable {
    var name: String?
    var personalityTraits: [String]?
    var speechStyle: String?
    var background: String?
    var interests: [String]?
    var quirks: [String]?
    var tone: String?
    var relationshipToUser: String?

    enum CodingKeys: String, CodingKey {
        case name
        case personalityTraits = "personality_traits"
        case speechStyle = "speech_style"
        case background, interests, quirks, tone
        case relationshipToUser = "relationship_to_user"
    }
}

struct CustomizationOptions: Codable, Equatable {
    let personalityTraits: [String]
    let speechStyles: [String]
    let tones: [String]
    let interests: [String]

    enum CodingKeys: String, CodingKey {
        case personalityTraits = "personality_traits"
        case speechStyles = "speech_styles"
        case tones, interests
    }
}
