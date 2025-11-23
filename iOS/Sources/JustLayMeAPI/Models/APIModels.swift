// MARK: - JustLayMe API Models
// Auto-generated from server API analysis
// All models match server's JSON structures exactly

import Foundation

// MARK: - Authentication Models

public struct RegisterRequest: Codable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct RegisterResponse: Codable {
    public let message: String
    public let email: String
    public let requiresVerification: Bool
    public let emailSent: Bool
}

public struct LoginRequest: Codable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct LoginResponse: Codable {
    public let token: String
    public let user: User
}

public struct User: Codable, Identifiable {
    public let id: String
    public let email: String
    public let name: String?
    public let subscriptionStatus: String
    public let emailVerified: Bool?
    public let isProfessionalEmail: Bool?
    public let createdAt: String?
    public let subscriptionEnd: String?

    enum CodingKeys: String, CodingKey {
        case id, email, name
        case subscriptionStatus = "subscription_status"
        case emailVerified = "email_verified"
        case isProfessionalEmail = "is_professional_email"
        case createdAt = "created_at"
        case subscriptionEnd = "subscription_end"
    }
}

public struct GoogleAuthRequest: Codable {
    public let credential: String

    public init(credential: String) {
        self.credential = credential
    }
}

public struct VerifyEmailResponse: Codable {
    public let message: String
    public let email: String
}

public struct ResendVerificationRequest: Codable {
    public let email: String

    public init(email: String) {
        self.email = email
    }
}

public struct ResendVerificationResponse: Codable {
    public let message: String
}

// MARK: - Chat Models

public struct ChatRequest: Codable {
    public let message: String
    public let characterId: String
    public let userId: String?

    enum CodingKeys: String, CodingKey {
        case message
        case characterId = "character_id"
        case userId = "user_id"
    }

    public init(message: String, characterId: String = "layme_v1", userId: String? = nil) {
        self.message = message
        self.characterId = characterId
        self.userId = userId
    }
}

public struct ChatResponse: Codable {
    public let response: String
    public let character: String
    public let model: String
    public let customized: Bool?
    public let modelInfo: ModelInfo?
    public let sessionId: String?
    public let error: String?
    public let memoryId: String?
    public let conversationId: String?
    public let messageId: String?

    enum CodingKeys: String, CodingKey {
        case response, character, model, customized, error
        case modelInfo = "model_info"
        case sessionId
        case memoryId = "memory_id"
        case conversationId = "conversation_id"
        case messageId = "message_id"
    }
}

public struct ModelInfo: Codable {
    public let name: String
    public let size: Int?
    public let capabilities: ModelCapabilities?
    public let recommendedFor: [String]?

    enum CodingKeys: String, CodingKey {
        case name, size, capabilities
        case recommendedFor = "recommended_for"
    }
}

public struct ModelCapabilities: Codable {
    public let strengths: [String]?
    public let bestFor: [String]?
    public let memoryUsage: String?
    public let speed: String?

    enum CodingKeys: String, CodingKey {
        case strengths
        case bestFor = "best_for"
        case memoryUsage = "memory_usage"
        case speed
    }
}

// MARK: - Character Models

public struct Character: Codable, Identifiable {
    public let id: String
    public let userId: String?
    public let name: String
    public let backstory: String?
    public let personalityTraits: PersonalityTraits?
    public let speechPatterns: [String]?
    public let avatarUrl: String?
    public let isPublic: Bool?
    public let createdAt: String?
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, backstory
        case userId = "user_id"
        case personalityTraits = "personality_traits"
        case speechPatterns = "speech_patterns"
        case avatarUrl = "avatar_url"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct PersonalityTraits: Codable {
    public let personality: String?
    public let interests: [String]?
    public let quirks: [String]?
    public let tone: String?
    public let relationship: String?
    public let baseModel: String?

    enum CodingKeys: String, CodingKey {
        case personality, interests, quirks, tone, relationship
        case baseModel = "base_model"
    }
}

public struct CreateCharacterRequest: Codable {
    public let name: String
    public let backstory: String?
    public let personalityTraits: [String: Any]?
    public let speechPatterns: [String]?

    enum CodingKeys: String, CodingKey {
        case name, backstory
        case personalityTraits = "personality_traits"
        case speechPatterns = "speech_patterns"
    }

    public init(name: String, backstory: String? = nil, personalityTraits: [String: Any]? = nil, speechPatterns: [String]? = nil) {
        self.name = name
        self.backstory = backstory
        self.personalityTraits = personalityTraits
        self.speechPatterns = speechPatterns
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(backstory, forKey: .backstory)
        try container.encodeIfPresent(speechPatterns, forKey: .speechPatterns)
        if let traits = personalityTraits {
            let data = try JSONSerialization.data(withJSONObject: traits)
            let jsonString = String(data: data, encoding: .utf8)
            try container.encodeIfPresent(jsonString, forKey: .personalityTraits)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        backstory = try container.decodeIfPresent(String.self, forKey: .backstory)
        speechPatterns = try container.decodeIfPresent([String].self, forKey: .speechPatterns)
        personalityTraits = nil
    }
}

public struct CharacterCustomization: Codable {
    public let name: String?
    public let age: Int?
    public let background: String?
    public let personalityTraits: String?
    public let interests: [String]?
    public let speechStyle: String?
    public let tone: String?
    public let relationshipToUser: String?
    public let specialKnowledge: [String]?
    public let quirks: [String]?
    public let emotionalState: String?
    public let conversationStyle: String?
    public let boundaries: [String]?

    enum CodingKeys: String, CodingKey {
        case name, age, background, interests, tone, quirks, boundaries
        case personalityTraits = "personality_traits"
        case speechStyle = "speech_style"
        case relationshipToUser = "relationship_to_user"
        case specialKnowledge = "special_knowledge"
        case emotionalState = "emotional_state"
        case conversationStyle = "conversation_style"
    }

    public init(
        name: String? = nil,
        age: Int? = nil,
        background: String? = nil,
        personalityTraits: String? = nil,
        interests: [String]? = nil,
        speechStyle: String? = nil,
        tone: String? = nil,
        relationshipToUser: String? = nil,
        specialKnowledge: [String]? = nil,
        quirks: [String]? = nil,
        emotionalState: String? = nil,
        conversationStyle: String? = nil,
        boundaries: [String]? = nil
    ) {
        self.name = name
        self.age = age
        self.background = background
        self.personalityTraits = personalityTraits
        self.interests = interests
        self.speechStyle = speechStyle
        self.tone = tone
        self.relationshipToUser = relationshipToUser
        self.specialKnowledge = specialKnowledge
        self.quirks = quirks
        self.emotionalState = emotionalState
        self.conversationStyle = conversationStyle
        self.boundaries = boundaries
    }
}

public struct CustomizationOptions: Codable {
    public let personalityTraits: [String]
    public let speechStyles: [String]
    public let tones: [String]
    public let relationshipTypes: [String]
    public let conversationStyles: [String]

    enum CodingKeys: String, CodingKey {
        case personalityTraits = "personality_traits"
        case speechStyles = "speech_styles"
        case tones
        case relationshipTypes = "relationship_types"
        case conversationStyles = "conversation_styles"
    }
}

public struct CustomizeCharacterResponse: Codable {
    public let success: Bool
    public let message: String
    public let characterId: String

    enum CodingKeys: String, CodingKey {
        case success, message
        case characterId = "character_id"
    }
}

public struct PreviewPromptResponse: Codable {
    public let characterId: String
    public let customized: Bool
    public let systemPrompt: String
    public let characterName: String

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case customized
        case systemPrompt = "system_prompt"
        case characterName = "character_name"
    }
}

// MARK: - Model Management Models

public struct AIModel: Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let size: Int?
    public let modified: String?
    public let capabilities: ModelCapabilities?
}

public struct ModelsResponse: Codable {
    public let models: [AIModel]
    public let defaultModel: String
    public let totalModels: Int

    enum CodingKeys: String, CodingKey {
        case models
        case defaultModel = "default_model"
        case totalModels = "total_models"
    }
}

public struct TestModelRequest: Codable {
    public let model: String
    public let prompt: String

    public init(model: String, prompt: String = "Hello, how are you?") {
        self.model = model
        self.prompt = prompt
    }
}

public struct TestModelResponse: Codable {
    public let model: String
    public let responseTime: Int?
    public let response: String?
    public let success: Bool
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case model, response, success, error
        case responseTime = "response_time"
    }
}

public struct ModelRecommendationResponse: Codable {
    public let characterId: String
    public let recommendedModel: String
    public let modelInfo: ModelInfo?
    public let availableModels: [AvailableModelSummary]

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case recommendedModel = "recommended_model"
        case modelInfo = "model_info"
        case availableModels = "available_models"
    }
}

public struct AvailableModelSummary: Codable {
    public let name: String
    public let bestFor: [String]?
    public let speed: String?

    enum CodingKeys: String, CodingKey {
        case name
        case bestFor = "best_for"
        case speed
    }
}

// MARK: - Conversation/Chat History Models

public struct Conversation: Codable, Identifiable {
    public let id: String
    public let userId: String?
    public let modelType: String
    public let title: String?
    public let messageCount: Int?
    public let isArchived: Bool?
    public let tags: [String]?
    public let createdAt: String?
    public let updatedAt: String?
    public let totalMessages: Int?
    public let lastMessageTime: String?
    public let lastMessagePreview: String?

    enum CodingKeys: String, CodingKey {
        case id, title, tags
        case userId = "user_id"
        case modelType = "model_type"
        case messageCount = "message_count"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case totalMessages = "total_messages"
        case lastMessageTime = "last_message_time"
        case lastMessagePreview = "last_message_preview"
    }
}

public struct ConversationsResponse: Codable {
    public let conversations: [Conversation]
    public let pagination: Pagination
}

public struct Pagination: Codable {
    public let page: Int
    public let limit: Int
    public let total: Int
    public let totalPages: Int
}

public struct Message: Codable, Identifiable {
    public let id: String
    public let conversationId: String?
    public let senderType: String
    public let content: String
    public let metadata: MessageMetadata?
    public let createdAt: String?
    public let senderName: String?

    enum CodingKeys: String, CodingKey {
        case id, content, metadata
        case conversationId = "conversation_uuid"
        case senderType = "sender_type"
        case createdAt = "created_at"
        case senderName = "sender_name"
    }
}

public struct MessageMetadata: Codable {
    public let characterId: String?
    public let model: String?
    public let characterName: String?
    public let customized: Bool?

    enum CodingKeys: String, CodingKey {
        case model, customized
        case characterId = "character_id"
        case characterName = "character_name"
    }
}

public struct MessagesResponse: Codable {
    public let messages: [Message]
}

public struct SearchConversationsResponse: Codable {
    public let results: [ConversationSearchResult]
}

public struct ConversationSearchResult: Codable, Identifiable {
    public let id: String
    public let userId: String?
    public let modelType: String?
    public let title: String?
    public let matchingMessage: String?
    public let messageTime: String?
    public let relevance: Double?

    enum CodingKeys: String, CodingKey {
        case id, title, relevance
        case userId = "user_id"
        case modelType = "model_type"
        case matchingMessage = "matching_message"
        case messageTime = "message_time"
    }
}

public struct ArchiveConversationRequest: Codable {
    public let archive: Bool

    public init(archive: Bool = true) {
        self.archive = archive
    }
}

public struct ArchiveConversationResponse: Codable {
    public let success: Bool
    public let conversation: Conversation?
}

// MARK: - Profile Models

public struct ProfileResponse: Codable {
    public let id: String
    public let email: String
    public let name: String?
    public let createdAt: String?
    public let subscriptionStatus: String
    public let subscriptionEnd: String?

    enum CodingKeys: String, CodingKey {
        case id, email, name
        case createdAt = "created_at"
        case subscriptionStatus = "subscription_status"
        case subscriptionEnd = "subscription_end"
    }
}

public struct UpdateProfileRequest: Codable {
    public let name: String?
    public let avatarStyle: String?
    public let themePreference: String?

    enum CodingKeys: String, CodingKey {
        case name
        case avatarStyle = "avatar_style"
        case themePreference = "theme_preference"
    }

    public init(name: String? = nil, avatarStyle: String? = nil, themePreference: String? = nil) {
        self.name = name
        self.avatarStyle = avatarStyle
        self.themePreference = themePreference
    }
}

public struct UpdateProfileResponse: Codable {
    public let message: String
    public let user: User?
}

public struct ExportDataResponse: Codable {
    public let user: User
    public let conversations: [Conversation]
    public let characters: [Character]
    public let exportedAt: String

    enum CodingKeys: String, CodingKey {
        case user, conversations, characters
        case exportedAt = "exported_at"
    }
}

// MARK: - Feedback Models

public struct FeedbackRequest: Codable {
    public let score: Int
    public let correctedResponse: String?
    public let patternType: String?

    enum CodingKeys: String, CodingKey {
        case score
        case correctedResponse = "corrected_response"
        case patternType = "pattern_type"
    }

    public init(score: Int, correctedResponse: String? = nil, patternType: String? = nil) {
        self.score = score
        self.correctedResponse = correctedResponse
        self.patternType = patternType
    }
}

public struct FeedbackResponse: Codable {
    public let success: Bool
}

// MARK: - Payment Models

public struct CreateCheckoutSessionRequest: Codable {
    public let plan: PaymentPlan
    public let userId: String?
    public let userEmail: String?

    enum CodingKeys: String, CodingKey {
        case plan
        case userId = "user_id"
        case userEmail = "user_email"
    }

    public init(plan: PaymentPlan, userId: String? = nil, userEmail: String? = nil) {
        self.plan = plan
        self.userId = userId
        self.userEmail = userEmail
    }
}

public enum PaymentPlan: String, Codable {
    case monthly
    case yearly
    case lifetime
}

public struct CreateCheckoutSessionResponse: Codable {
    public let sessionId: String
}

// MARK: - Generic Response Models

public struct SuccessResponse: Codable {
    public let success: Bool
    public let message: String?
}

public struct ErrorResponse: Codable {
    public let error: String
    public let requiresVerification: Bool?
    public let email: String?
}

// MARK: - WebSocket Models

public enum WebSocketMessageType: String, Codable {
    case adminAuth = "ADMIN_AUTH"
    case authSuccess = "AUTH_SUCCESS"
    case getSessions = "GET_SESSIONS"
    case sessionsList = "SESSIONS_LIST"
    case newSession = "NEW_SESSION"
    case newMessage = "NEW_MESSAGE"
}

public struct WebSocketMessage: Codable {
    public let type: WebSocketMessageType
    public let password: String?
    public let sessions: [ChatSession]?
    public let sessionId: String?
    public let userId: String?
    public let characterId: String?
    public let timestamp: String?
    public let message: String?
    public let isUser: Bool?
}

public struct ChatSession: Codable, Identifiable {
    public let id: String
    public let userId: String
    public let characterId: String
    public let messages: [SessionMessage]?
    public let startTime: String
    public let lastActivity: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "userId"
        case characterId = "characterId"
        case messages
        case startTime = "startTime"
        case lastActivity = "lastActivity"
    }
}

public struct SessionMessage: Codable {
    public let content: String
    public let isUser: Bool
    public let timestamp: String
}

// MARK: - Character Type Enum

public enum CharacterType: String, CaseIterable, Codable {
    case laymeV1 = "layme_v1"
    case uncensoredGpt = "uncensored_gpt"
    case roleplay = "roleplay"
    case companion = "companion"
    case dominant = "dominant"
    case submissive = "submissive"

    public var displayName: String {
        switch self {
        case .laymeV1: return "Layme V1"
        case .uncensoredGpt: return "LayMe V1 Uncensored"
        case .roleplay: return "Mythomax Roleplay"
        case .companion: return "FastLayMe"
        case .dominant: return "Dominant AI"
        case .submissive: return "Submissive AI"
        }
    }

    public var isFree: Bool {
        return self == .laymeV1
    }
}

// MARK: - Subscription Status

public enum SubscriptionStatus: String, Codable {
    case free
    case premium

    public var isPremium: Bool {
        return self == .premium
    }
}
