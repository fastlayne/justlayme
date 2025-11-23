import Foundation

// MARK: - Chat Request
/// Request body for sending a chat message
/// Matches backend: character-api.js POST /api/chat

struct ChatRequest: Codable {
    let message: String
    let characterId: String
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case message
        case characterId = "character_id"
        case userId = "user_id"
    }

    init(message: String, characterId: String = "layme_v1", userId: String? = nil) {
        self.message = message
        self.characterId = characterId
        self.userId = userId
    }
}

// MARK: - Chat Response
/// Response from chat API
/// Matches backend: character-api.js POST /api/chat response

struct ChatResponse: Codable {
    let response: String
    let character: String
    let model: String
    let customized: Bool?
    let modelInfo: ModelInfo?
    let sessionId: String?
    let error: String?
    let memoryId: String?
    let conversationId: String?
    let messageId: String?

    enum CodingKeys: String, CodingKey {
        case response
        case character
        case model
        case customized
        case modelInfo = "model_info"
        case sessionId = "sessionId"
        case error
        case memoryId = "memory_id"
        case conversationId = "conversation_id"
        case messageId = "message_id"
    }

    init(
        response: String,
        character: String,
        model: String,
        customized: Bool? = nil,
        modelInfo: ModelInfo? = nil,
        sessionId: String? = nil,
        error: String? = nil,
        memoryId: String? = nil,
        conversationId: String? = nil,
        messageId: String? = nil
    ) {
        self.response = response
        self.character = character
        self.model = model
        self.customized = customized
        self.modelInfo = modelInfo
        self.sessionId = sessionId
        self.error = error
        self.memoryId = memoryId
        self.conversationId = conversationId
        self.messageId = messageId
    }
}

// MARK: - Chat Session
/// Represents an active chat session
/// Matches backend: global.activeSessions structure

struct ChatSession: Codable, Identifiable, Hashable {
    let id: String
    var userId: String
    var characterId: String
    var messages: [SessionMessage]
    var startTime: Date
    var lastActivity: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "userId"
        case characterId = "characterId"
        case messages
        case startTime = "startTime"
        case lastActivity = "lastActivity"
    }

    init(
        id: String = UUID().uuidString,
        userId: String = "anonymous",
        characterId: String = "layme_v1",
        messages: [SessionMessage] = [],
        startTime: Date = Date(),
        lastActivity: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.characterId = characterId
        self.messages = messages
        self.startTime = startTime
        self.lastActivity = lastActivity
    }

    /// Duration of the session
    var duration: TimeInterval {
        return lastActivity.timeIntervalSince(startTime)
    }

    /// Formatted duration string
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}

// MARK: - Session Message
/// A message within a chat session
struct SessionMessage: Codable, Identifiable, Hashable {
    let id: String
    let content: String
    let isUser: Bool
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        content: String,
        isUser: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

// MARK: - Character Memory
/// Memory of past interactions for learning
/// Matches backend: character-api.js character_memories table

struct CharacterMemory: Codable, Identifiable, Hashable {
    let id: String
    let characterId: String
    let userMessage: String
    let aiResponse: String
    var feedbackScore: Int?
    var correctedResponse: String?
    var importanceScore: Double
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case characterId = "character_id"
        case userMessage = "user_message"
        case aiResponse = "ai_response"
        case feedbackScore = "feedback_score"
        case correctedResponse = "corrected_response"
        case importanceScore = "importance_score"
        case createdAt = "created_at"
    }

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
}

// MARK: - Character Learning
/// Learning patterns for character behavior
/// Matches backend: character-api.js character_learning table

struct CharacterLearning: Codable, Identifiable, Hashable {
    let id: String
    let characterId: String
    var patternType: String?
    var userInput: String
    var expectedOutput: String
    var confidence: Double
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case characterId = "character_id"
        case patternType = "pattern_type"
        case userInput = "user_input"
        case expectedOutput = "expected_output"
        case confidence
        case createdAt = "created_at"
    }

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
}

// MARK: - Feedback Request
/// Request to submit feedback on an AI response
/// Matches backend: character-api.js POST /api/feedback/:memory_id

struct FeedbackRequest: Codable {
    let score: Int
    let correctedResponse: String?
    let patternType: String?

    enum CodingKeys: String, CodingKey {
        case score
        case correctedResponse = "corrected_response"
        case patternType = "pattern_type"
    }

    init(score: Int, correctedResponse: String? = nil, patternType: String? = nil) {
        self.score = score
        self.correctedResponse = correctedResponse
        self.patternType = patternType
    }
}

// MARK: - Feedback Response
struct FeedbackResponse: Codable {
    let success: Bool
}

// MARK: - Prompt Preview Response
/// Response from prompt preview API
/// Matches backend: character-api.js GET /api/characters/:id/preview-prompt

struct PromptPreviewResponse: Codable {
    let characterId: String
    let customized: Bool
    let systemPrompt: String
    let characterName: String

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case customized
        case systemPrompt = "system_prompt"
        case characterName = "character_name"
    }
}
