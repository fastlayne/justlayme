import Foundation
import SwiftUI

struct AICharacter: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let avatarLetter: String
    let gradient: GradientColors
    let isFree: Bool
    let freeMessageLimit: Int

    var gradientColors: [Color] {
        [Color(hex: gradient.start), Color(hex: gradient.end)]
    }

    static let defaultCharacters: [AICharacter] = [
        AICharacter(
            id: "layme_v1",
            name: "Layme V1",
            description: "FREE & Unlimited - No Paywall",
            avatarLetter: "L",
            gradient: GradientColors(start: "#10b981", end: "#059669"),
            isFree: true,
            freeMessageLimit: -1
        ),
        AICharacter(
            id: "uncensored_gpt",
            name: "LayMe Uncensored",
            description: "No Limits - Dolphin 46.7B",
            avatarLetter: "L",
            gradient: GradientColors(start: "#667eea", end: "#764ba2"),
            isFree: false,
            freeMessageLimit: 3
        ),
        AICharacter(
            id: "roleplay",
            name: "Mythomax Roleplay",
            description: "Dark & Seductive - 13B",
            avatarLetter: "M",
            gradient: GradientColors(start: "#f093fb", end: "#f5576c"),
            isFree: false,
            freeMessageLimit: 3
        ),
        AICharacter(
            id: "companion",
            name: "FastLayMe",
            description: "Fast & Light - Zephyr 7B",
            avatarLetter: "F",
            gradient: GradientColors(start: "#4facfe", end: "#00f2fe"),
            isFree: false,
            freeMessageLimit: 3
        )
    ]
}

struct GradientColors: Codable, Hashable {
    let start: String
    let end: String
}

struct CustomCharacter: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    var backstory: String?
    var personalityTraits: [String: Int]?
    var speechPatterns: [String]?
    var avatarUrl: String?
    var isPublic: Bool
    var createdAt: Date
    var updatedAt: Date

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
}

struct CharacterCustomization: Codable {
    var name: String?
    var personalityTraits: String?
    var speechStyle: String?
    var relationshipToUser: String?
    var background: String?
    var interests: [String]?
    var quirks: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case personalityTraits = "personality_traits"
        case speechStyle = "speech_style"
        case relationshipToUser = "relationship_to_user"
        case background, interests, quirks
    }
}
