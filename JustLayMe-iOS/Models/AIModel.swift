import Foundation

// MARK: - AI Model

struct AIModel: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
    var description: String?
    var isPremium: Bool
    var freeMessageLimit: Int
    var isAvailable: Bool

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName = "display_name"
        case description
        case isPremium = "is_premium"
        case freeMessageLimit = "free_message_limit"
        case isAvailable = "is_available"
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AIModel, rhs: AIModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Preset Models

extension AIModel {
    static let laymeV1 = AIModel(
        id: "layme_v1",
        name: "layme_v1",
        displayName: "Layme V1",
        description: "FREE & Unlimited - Your friendly AI companion",
        isPremium: false,
        freeMessageLimit: -1, // Unlimited
        isAvailable: true
    )

    static let laymeUncensored = AIModel(
        id: "layeme_uncensored",
        name: "layeme_uncensored",
        displayName: "LayMe Uncensored",
        description: "Premium model with unrestricted responses",
        isPremium: true,
        freeMessageLimit: 3,
        isAvailable: true
    )

    static let mythomaxRoleplay = AIModel(
        id: "mythomax_roleplay",
        name: "mythomax_roleplay",
        displayName: "Mythomax Roleplay",
        description: "Premium model for immersive roleplay",
        isPremium: true,
        freeMessageLimit: 3,
        isAvailable: true
    )

    static let fastLayme = AIModel(
        id: "fast_layme",
        name: "fast_layme",
        displayName: "FastLayMe",
        description: "Premium model optimized for speed",
        isPremium: true,
        freeMessageLimit: 3,
        isAvailable: true
    )

    static let allModels: [AIModel] = [
        .laymeV1,
        .laymeUncensored,
        .mythomaxRoleplay,
        .fastLayme
    ]

    static let freeModels: [AIModel] = allModels.filter { !$0.isPremium }
    static let premiumModels: [AIModel] = allModels.filter { $0.isPremium }
}

// MARK: - Model Health Response

struct ModelHealthResponse: Codable {
    let models: [ModelHealth]

    struct ModelHealth: Codable {
        let name: String
        let isHealthy: Bool
        let responseTime: Double?
        let lastChecked: Date?

        enum CodingKeys: String, CodingKey {
            case name
            case isHealthy = "is_healthy"
            case responseTime = "response_time"
            case lastChecked = "last_checked"
        }
    }
}

// MARK: - Model Test Request/Response

struct ModelTestRequest: Codable {
    let modelName: String
    let prompt: String

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case prompt
    }
}

struct ModelTestResponse: Codable {
    let response: String
    let model: String
    let responseTime: Double

    enum CodingKeys: String, CodingKey {
        case response
        case model
        case responseTime = "response_time"
    }
}

// MARK: - Model Recommendation

struct ModelRecommendation: Codable {
    let recommendedModel: String
    let reason: String
    let alternatives: [String]

    enum CodingKeys: String, CodingKey {
        case recommendedModel = "recommended_model"
        case reason
        case alternatives
    }
}
