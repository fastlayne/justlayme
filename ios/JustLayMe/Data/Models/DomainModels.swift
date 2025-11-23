import Foundation

// MARK: - Sync Status

public enum SyncStatus: Int16, Codable, CaseIterable {
    case pending = 0
    case pendingSync = 1
    case syncing = 2
    case synced = 3
    case failed = 4

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .pendingSync: return "Pending Sync"
        case .syncing: return "Syncing"
        case .synced: return "Synced"
        case .failed: return "Failed"
        }
    }

    public var needsSync: Bool {
        self == .pending || self == .pendingSync || self == .failed
    }
}

// MARK: - Subscription Status

public enum SubscriptionStatus: String, Codable, CaseIterable {
    case free
    case premium
    case monthly
    case yearly
    case lifetime

    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    public var isPremium: Bool {
        self != .free
    }

    public var messageLimit: Int? {
        switch self {
        case .free: return 100
        default: return nil // Unlimited
        }
    }
}

// MARK: - Model Type

public enum ModelType: String, Codable, CaseIterable {
    case layme_v1 = "layme_v1"
    case uncensored_gpt = "uncensored_gpt"
    case roleplay = "roleplay"
    case companion = "companion"
    case dominant = "dominant"
    case submissive = "submissive"

    public var displayName: String {
        switch self {
        case .layme_v1: return "Layme V1"
        case .uncensored_gpt: return "LayMe V1 Uncensored"
        case .roleplay: return "Mythomax Roleplay"
        case .companion: return "FastLayMe"
        case .dominant: return "Dominant AI"
        case .submissive: return "Submissive AI"
        }
    }

    public var isFree: Bool {
        self == .layme_v1
    }

    public var freeMessageLimit: Int {
        isFree ? Int.max : 3
    }
}

// MARK: - User Model

public struct User: Identifiable, Codable, Equatable {
    public let id: UUID
    public var email: String
    public var name: String?
    public var googleId: String?
    public var subscriptionStatus: SubscriptionStatus
    public var subscriptionEnd: Date?
    public var messageCount: Int
    public var emailVerified: Bool
    public var verificationToken: String?
    public var verificationExpires: Date?
    public var createdAt: Date
    public var lastLogin: Date?
    public var updatedAt: Date?
    public var avatarStyle: String?
    public var themePreference: String?

    public init(
        id: UUID = UUID(),
        email: String,
        name: String? = nil,
        googleId: String? = nil,
        subscriptionStatus: SubscriptionStatus = .free,
        subscriptionEnd: Date? = nil,
        messageCount: Int = 0,
        emailVerified: Bool = false,
        verificationToken: String? = nil,
        verificationExpires: Date? = nil,
        createdAt: Date = Date(),
        lastLogin: Date? = nil,
        updatedAt: Date? = nil,
        avatarStyle: String? = nil,
        themePreference: String? = nil
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.googleId = googleId
        self.subscriptionStatus = subscriptionStatus
        self.subscriptionEnd = subscriptionEnd
        self.messageCount = messageCount
        self.emailVerified = emailVerified
        self.verificationToken = verificationToken
        self.verificationExpires = verificationExpires
        self.createdAt = createdAt
        self.lastLogin = lastLogin
        self.updatedAt = updatedAt
        self.avatarStyle = avatarStyle
        self.themePreference = themePreference
    }

    public var isPremium: Bool {
        subscriptionStatus.isPremium
    }

    public var isSubscriptionActive: Bool {
        guard isPremium else { return false }
        if subscriptionStatus == .lifetime { return true }
        guard let endDate = subscriptionEnd else { return false }
        return endDate > Date()
    }
}

// MARK: - Character Model

public struct Character: Identifiable, Codable, Equatable {
    public let id: UUID
    public let userId: UUID
    public var name: String
    public var backstory: String?
    public var personalityTraits: [String: Any]
    public var speechPatterns: [String]
    public var avatarUrl: String?
    public var isPublic: Bool
    public var createdAt: Date
    public var updatedAt: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        name: String,
        backstory: String? = nil,
        personalityTraits: [String: Any] = [:],
        speechPatterns: [String] = [],
        avatarUrl: String? = nil,
        isPublic: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
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

    // Custom Codable for [String: Any]
    enum CodingKeys: String, CodingKey {
        case id, userId, name, backstory, personalityTraits, speechPatterns
        case avatarUrl, isPublic, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        backstory = try container.decodeIfPresent(String.self, forKey: .backstory)
        speechPatterns = try container.decodeIfPresent([String].self, forKey: .speechPatterns) ?? []
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)

        if let data = try container.decodeIfPresent(Data.self, forKey: .personalityTraits),
           let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            personalityTraits = dict
        } else {
            personalityTraits = [:]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(backstory, forKey: .backstory)
        try container.encode(speechPatterns, forKey: .speechPatterns)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)

        let data = try JSONSerialization.data(withJSONObject: personalityTraits)
        try container.encode(data, forKey: .personalityTraits)
    }

    public static func == (lhs: Character, rhs: Character) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Conversation Model

public struct Conversation: Identifiable, Codable, Equatable {
    public let id: UUID
    public let userId: UUID
    public var modelType: ModelType
    public var title: String?
    public var messageCount: Int
    public var isArchived: Bool
    public var tags: [String]
    public var metadata: [String: String]
    public var createdAt: Date
    public var updatedAt: Date?
    public var lastMessageAt: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        modelType: ModelType,
        title: String? = nil,
        messageCount: Int = 0,
        isArchived: Bool = false,
        tags: [String] = [],
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        lastMessageAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.modelType = modelType
        self.title = title
        self.messageCount = messageCount
        self.isArchived = isArchived
        self.tags = tags
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMessageAt = lastMessageAt ?? createdAt
    }
}

// MARK: - Message Model

public struct Message: Identifiable, Codable, Equatable {
    public let id: UUID
    public let conversationId: UUID
    public var legacyConversationId: String?
    public var senderType: SenderType
    public var content: String
    public var metadata: MessageMetadata
    public var isDeleted: Bool
    public var deletedAt: Date?
    public var isEdited: Bool
    public var editedAt: Date?
    public var tokensUsed: Int?
    public var modelUsed: String?
    public var responseTimeMs: Int?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        conversationId: UUID,
        legacyConversationId: String? = nil,
        senderType: SenderType,
        content: String,
        metadata: MessageMetadata = MessageMetadata(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        isEdited: Bool = false,
        editedAt: Date? = nil,
        tokensUsed: Int? = nil,
        modelUsed: String? = nil,
        responseTimeMs: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.conversationId = conversationId
        self.legacyConversationId = legacyConversationId
        self.senderType = senderType
        self.content = content
        self.metadata = metadata
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.isEdited = isEdited
        self.editedAt = editedAt
        self.tokensUsed = tokensUsed
        self.modelUsed = modelUsed
        self.responseTimeMs = responseTimeMs
        self.createdAt = createdAt
    }

    public var isFromUser: Bool {
        senderType == .human
    }

    public var senderName: String {
        isFromUser ? "You" : (metadata.characterName ?? modelUsed ?? "AI")
    }
}

// MARK: - Character Memory Model

public struct CharacterMemory: Identifiable, Codable, Equatable {
    public let id: UUID
    public let characterId: UUID
    public var userMessage: String
    public var aiResponse: String
    public var feedbackScore: Int?
    public var correctedResponse: String?
    public var importanceScore: Double
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        characterId: UUID,
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
}

// MARK: - Character Learning Model

public struct CharacterLearning: Identifiable, Codable, Equatable {
    public let id: UUID
    public let characterId: UUID
    public var patternType: PatternType
    public var userInput: String
    public var expectedOutput: String
    public var confidence: Double
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        characterId: UUID,
        patternType: PatternType = .speech,
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
}

// MARK: - Email Verification Log Model

public struct EmailVerificationLog: Identifiable, Codable, Equatable {
    public let id: UUID
    public let userId: UUID
    public var action: VerificationAction
    public var ipAddress: String?
    public var userAgent: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        userId: UUID,
        action: VerificationAction,
        ipAddress: String? = nil,
        userAgent: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.action = action
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.createdAt = createdAt
    }
}

// MARK: - Session Model (In-Memory)

public struct ChatSession: Identifiable, Codable {
    public let id: String
    public var userId: String
    public var characterId: String
    public var messages: [SessionMessage]
    public var startTime: Date
    public var lastActivity: Date

    public init(
        id: String? = nil,
        userId: String = "anonymous",
        characterId: String = "layme_v1",
        messages: [SessionMessage] = [],
        startTime: Date = Date(),
        lastActivity: Date = Date()
    ) {
        self.id = id ?? "session-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(8))"
        self.userId = userId
        self.characterId = characterId
        self.messages = messages
        self.startTime = startTime
        self.lastActivity = lastActivity
    }

    public mutating func addMessage(_ content: String, isUser: Bool) {
        messages.append(SessionMessage(content: content, isUser: isUser))
        lastActivity = Date()
    }
}

public struct SessionMessage: Codable {
    public var content: String
    public var isUser: Bool
    public var timestamp: Date

    public init(content: String, isUser: Bool, timestamp: Date = Date()) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

// MARK: - API Response Models

public struct ChatResponse: Codable {
    public let response: String
    public let character: String
    public let model: String
    public let customized: Bool
    public let modelInfo: ModelInfo?
    public let sessionId: String

    public struct ModelInfo: Codable {
        public let name: String
        public let size: Int64?
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
}

public struct AuthResponse: Codable {
    public let token: String
    public let user: AuthUser

    public struct AuthUser: Codable {
        public let id: UUID
        public let email: String
        public let subscriptionStatus: String
        public let emailVerified: Bool
        public let isProfessionalEmail: Bool?

        enum CodingKeys: String, CodingKey {
            case id, email
            case subscriptionStatus = "subscription_status"
            case emailVerified = "email_verified"
            case isProfessionalEmail = "is_professional_email"
        }
    }
}

public struct PaginatedResponse<T: Codable>: Codable {
    public let data: [T]
    public let pagination: Pagination

    public struct Pagination: Codable {
        public let page: Int
        public let limit: Int
        public let total: Int
        public let totalPages: Int
    }
}
