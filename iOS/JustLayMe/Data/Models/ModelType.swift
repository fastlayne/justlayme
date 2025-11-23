import Foundation

// MARK: - Model Type
/// Available AI model types matching backend MODEL_TYPES
/// Matches backend: character-api.js MODEL_TYPES

enum ModelType: String, Codable, CaseIterable, Identifiable {
    case uncensoredGpt = "uncensored_gpt"
    case roleplay = "roleplay"
    case companion = "companion"
    case dominant = "dominant"
    case submissive = "submissive"
    case laymeV1 = "layme_v1"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .uncensoredGpt: return "LayMe V1 Uncensored"
        case .roleplay: return "Mythomax Roleplay"
        case .companion: return "FastLayMe"
        case .dominant: return "Dominant AI"
        case .submissive: return "Submissive AI"
        case .laymeV1: return "Layme V1"
        }
    }

    var emoji: String {
        switch self {
        case .uncensoredGpt: return "🔓"
        case .roleplay: return "🎭"
        case .companion: return "⚡"
        case .dominant: return "👑"
        case .submissive: return "🎀"
        case .laymeV1: return "🆓"
        }
    }

    var description: String {
        switch self {
        case .uncensoredGpt:
            return "Completely unrestricted AI with no filters or limits"
        case .roleplay:
            return "Immersive roleplay AI that adapts to any scenario"
        case .companion:
            return "Quick and friendly AI companion for casual chat"
        case .dominant:
            return "Commanding AI personality with authoritative presence"
        case .submissive:
            return "Obedient AI that's eager to please and follow directions"
        case .laymeV1:
            return "Free unlimited access AI model"
        }
    }

    var isPremium: Bool {
        switch self {
        case .laymeV1: return false
        case .uncensoredGpt, .roleplay, .companion, .dominant, .submissive: return true
        }
    }

    var freeMessageLimit: Int {
        switch self {
        case .laymeV1: return Int.max
        default: return 3
        }
    }

    /// Default model for free users
    static var `default`: ModelType {
        return .laymeV1
    }

    /// All premium models
    static var premiumModels: [ModelType] {
        return allCases.filter { $0.isPremium }
    }

    /// All free models
    static var freeModels: [ModelType] {
        return allCases.filter { !$0.isPremium }
    }
}

// MARK: - Model Info
/// Detailed information about an AI model
/// Matches backend: model-manager.js getModelInfo()

struct ModelInfo: Codable, Identifiable, Hashable {
    let name: String
    let size: Int64?
    let capabilities: ModelCapabilities
    let recommendedFor: [String]?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case capabilities
        case recommendedFor = "recommended_for"
    }

    init(
        name: String,
        size: Int64? = nil,
        capabilities: ModelCapabilities = ModelCapabilities(),
        recommendedFor: [String]? = nil
    ) {
        self.name = name
        self.size = size
        self.capabilities = capabilities
        self.recommendedFor = recommendedFor
    }

    /// Formatted size string
    var formattedSize: String? {
        guard let size = size else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Model Capabilities
/// Capabilities and characteristics of an AI model
/// Matches backend: model-manager.js modelCapabilities

struct ModelCapabilities: Codable, Hashable {
    var strengths: [String]
    var bestFor: [String]
    var memoryUsage: MemoryUsage
    var speed: ModelSpeed

    enum CodingKeys: String, CodingKey {
        case strengths
        case bestFor = "best_for"
        case memoryUsage = "memory_usage"
        case speed
    }

    init(
        strengths: [String] = ["general"],
        bestFor: [String] = ["general"],
        memoryUsage: MemoryUsage = .medium,
        speed: ModelSpeed = .medium
    ) {
        self.strengths = strengths
        self.bestFor = bestFor
        self.memoryUsage = memoryUsage
        self.speed = speed
    }
}

// MARK: - Memory Usage
enum MemoryUsage: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Model Speed
enum ModelSpeed: String, Codable, CaseIterable {
    case fast = "fast"
    case medium = "medium"
    case slow = "slow"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .medium: return "Medium"
        case .slow: return "Slow"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .fast: return "bolt.fill"
        case .medium: return "bolt"
        case .slow: return "tortoise.fill"
        case .unknown: return "questionmark"
        }
    }
}

// MARK: - Models List Response
struct ModelsListResponse: Codable {
    let models: [ModelInfo]
    let defaultModel: String?
    let totalModels: Int

    enum CodingKeys: String, CodingKey {
        case models
        case defaultModel = "default_model"
        case totalModels = "total_models"
    }
}

// MARK: - Model Recommendation Response
struct ModelRecommendationResponse: Codable {
    let characterId: String
    let recommendedModel: String
    let modelInfo: ModelInfo?
    let availableModels: [ModelSummary]

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case recommendedModel = "recommended_model"
        case modelInfo = "model_info"
        case availableModels = "available_models"
    }
}

// MARK: - Model Summary
struct ModelSummary: Codable, Identifiable, Hashable {
    let name: String
    let bestFor: [String]
    let speed: ModelSpeed

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case bestFor = "best_for"
        case speed
    }
}

// MARK: - Model Test Request
struct ModelTestRequest: Codable {
    let model: String
    let prompt: String?
}

// MARK: - Model Test Response
struct ModelTestResponse: Codable {
    let model: String
    let responseTime: Int?
    let response: String?
    let success: Bool
    let error: String?

    enum CodingKeys: String, CodingKey {
        case model
        case responseTime = "response_time"
        case response
        case success
        case error
    }
}

// MARK: - Model Prompt Settings
/// Settings for generating AI responses
/// Matches backend: model-manager.js generateModelPromptSettings()

struct ModelPromptSettings: Codable {
    var temperature: Double
    var topP: Double
    var maxTokens: Int
    var stop: [String]?
    var repeatPenalty: Double?

    enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case maxTokens = "max_tokens"
        case stop
        case repeatPenalty = "repeat_penalty"
    }

    init(
        temperature: Double = 0.8,
        topP: Double = 0.9,
        maxTokens: Int = 500,
        stop: [String]? = ["\nHuman:", "\n\n"],
        repeatPenalty: Double? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.stop = stop
        self.repeatPenalty = repeatPenalty
    }

    /// Default settings for each model type
    static func settings(for modelName: String) -> ModelPromptSettings {
        switch modelName {
        case "solar:10.7b-instruct-v1-q8_0":
            return ModelPromptSettings(
                temperature: 0.7,
                topP: 0.95,
                maxTokens: 600,
                repeatPenalty: 1.1
            )
        case "zephyr:7b-alpha-q4_0":
            return ModelPromptSettings(
                temperature: 0.8,
                topP: 0.9,
                maxTokens: 400,
                repeatPenalty: 1.05
            )
        case "mistral:7b-instruct":
            return ModelPromptSettings(
                temperature: 0.75,
                topP: 0.9,
                maxTokens: 500,
                repeatPenalty: 1.1
            )
        default:
            return ModelPromptSettings()
        }
    }
}
