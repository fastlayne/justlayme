import Foundation

// MARK: - AI Character Model
struct AICharacter: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let userId: String?
    var name: String
    var backstory: String?
    var personalityTraits: [String]?
    var speechPatterns: [String]?
    var avatarUrl: String?
    var isPublic: Bool
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, backstory
        case personalityTraits = "personality_traits"
        case speechPatterns = "speech_patterns"
        case avatarUrl = "avatar_url"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Predefined Characters (matching web MODEL_TYPES)
enum PredefinedCharacter: String, CaseIterable, Identifiable {
    case laymeV1 = "layme_v1"
    case uncensoredGpt = "uncensored_gpt"
    case roleplay = "roleplay"
    case companion = "companion"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .laymeV1: return "Layme V1"
        case .uncensoredGpt: return "LayMe Uncensored"
        case .roleplay: return "Mythomax Roleplay"
        case .companion: return "FastLayMe"
        }
    }

    var description: String {
        switch self {
        case .laymeV1:
            return "FREE & Unlimited - General purpose AI companion"
        case .uncensoredGpt:
            return "Premium - No filters, completely unrestricted"
        case .roleplay:
            return "Premium - Dark, seductive roleplay character"
        case .companion:
            return "Premium - Quick and friendly AI companion"
        }
    }

    var icon: String {
        switch self {
        case .laymeV1: return "sparkles"
        case .uncensoredGpt: return "flame.fill"
        case .roleplay: return "theatermasks.fill"
        case .companion: return "bolt.fill"
        }
    }

    var isFree: Bool {
        self == .laymeV1
    }

    var isPremium: Bool {
        !isFree
    }

    var color: String {
        switch self {
        case .laymeV1: return "green"
        case .uncensoredGpt: return "red"
        case .roleplay: return "purple"
        case .companion: return "blue"
        }
    }
}

// MARK: - Character Customization
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
}

struct CharacterCustomization: Codable {
    var name: String
    var personalityTraits: [String]
    var interests: [String]
    var quirks: [String]
    var tone: String
    var relationshipToUser: String
    var background: String
    var speechStyle: String

    enum CodingKeys: String, CodingKey {
        case name
        case personalityTraits = "personality_traits"
        case interests, quirks, tone
        case relationshipToUser = "relationship_to_user"
        case background
        case speechStyle = "speech_style"
    }
}

struct CreateCharacterRequest: Codable {
    let name: String
    let backstory: String?
    let personalityTraits: [String]?
    let speechPatterns: [String]?

    enum CodingKeys: String, CodingKey {
        case name, backstory
        case personalityTraits = "personality_traits"
        case speechPatterns = "speech_patterns"
    }
}
