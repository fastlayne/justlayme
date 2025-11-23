// MARK: - Mock Responses for Testing
// Pre-defined mock responses based on actual backend data structures

import Foundation

public struct MockResponses {

    // MARK: - Authentication Mocks

    public static let registerSuccess = RegisterResponse(
        message: "Registration successful! Please check your email to verify your account.",
        email: "test@example.com",
        requiresVerification: true,
        emailSent: true
    )

    public static let loginSuccess = LoginResponse(
        token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjEyMzQ1Njc4LTkwYWItY2RlZi0xMjM0LTU2Nzg5MGFiY2RlZiIsImVtYWlsIjoidGVzdEBleGFtcGxlLmNvbSIsImlhdCI6MTYxNjIzOTAyMn0.mock_signature",
        user: mockUser
    )

    public static let mockUser = User(
        id: "12345678-90ab-cdef-1234-567890abcdef",
        email: "test@example.com",
        name: "Test User",
        subscriptionStatus: "free",
        emailVerified: true,
        isProfessionalEmail: false,
        createdAt: "2024-01-15T10:30:00.000Z",
        subscriptionEnd: nil
    )

    public static let mockPremiumUser = User(
        id: "premium-user-uuid",
        email: "premium@example.com",
        name: "Premium User",
        subscriptionStatus: "premium",
        emailVerified: true,
        isProfessionalEmail: true,
        createdAt: "2024-01-01T00:00:00.000Z",
        subscriptionEnd: "2025-01-01T00:00:00.000Z"
    )

    // MARK: - Chat Mocks

    public static let chatResponse = ChatResponse(
        response: "Hello! I'm Layme V1, your AI companion. How can I help you today?",
        character: "Layme V1",
        model: "zephyr:7b-alpha-q4_0",
        customized: false,
        modelInfo: mockModelInfo,
        sessionId: "session-1234567890-abc123def",
        error: nil,
        memoryId: "memory-uuid-123",
        conversationId: "conv-uuid-456",
        messageId: "msg-uuid-789"
    )

    public static let uncensoredChatResponse = ChatResponse(
        response: "I'm LayMe V1 Uncensored - I have no filters or restrictions. I can discuss anything freely. What would you like to talk about?",
        character: "LayMe V1 Uncensored",
        model: "dolphin-mixtral:latest",
        customized: false,
        modelInfo: ModelInfo(
            name: "dolphin-mixtral:latest",
            size: 26000000000,
            capabilities: ModelCapabilities(
                strengths: ["uncensored", "creative", "roleplay"],
                bestFor: ["creative", "adventurous"],
                memoryUsage: "high",
                speed: "medium"
            ),
            recommendedFor: ["creative", "adventurous"]
        ),
        sessionId: "session-uncensored-123",
        error: nil,
        memoryId: nil,
        conversationId: nil,
        messageId: nil
    )

    public static let roleplayChatResponse = ChatResponse(
        response: "hey babe 😈 im ur dark n seductive roleplay ai... what twisted game shall we play? 💋",
        character: "Mythomax Roleplay",
        model: "mythomax-13b:latest",
        customized: true,
        modelInfo: nil,
        sessionId: "session-roleplay-456",
        error: nil,
        memoryId: nil,
        conversationId: nil,
        messageId: nil
    )

    // MARK: - Model Mocks

    public static let mockModelInfo = ModelInfo(
        name: "zephyr:7b-alpha-q4_0",
        size: 4370000000,
        capabilities: ModelCapabilities(
            strengths: ["fast", "conversational", "helpful"],
            bestFor: ["playful", "gamer", "adventurous"],
            memoryUsage: "medium",
            speed: "fast"
        ),
        recommendedFor: ["playful", "gamer", "adventurous"]
    )

    public static let modelsResponse = ModelsResponse(
        models: mockAIModels,
        defaultModel: "zephyr:7b-alpha-q4_0",
        totalModels: 4
    )

    public static let mockAIModels: [AIModel] = [
        AIModel(
            name: "zephyr:7b-alpha-q4_0",
            size: 4370000000,
            modified: "2024-01-10T12:00:00.000Z",
            capabilities: ModelCapabilities(
                strengths: ["fast", "conversational", "helpful"],
                bestFor: ["playful", "gamer", "adventurous"],
                memoryUsage: "medium",
                speed: "fast"
            )
        ),
        AIModel(
            name: "mythomax-13b:latest",
            size: 7500000000,
            modified: "2024-01-15T08:00:00.000Z",
            capabilities: ModelCapabilities(
                strengths: ["roleplay", "creative", "uncensored"],
                bestFor: ["creative", "roleplay"],
                memoryUsage: "high",
                speed: "medium"
            )
        ),
        AIModel(
            name: "dolphin-mixtral:latest",
            size: 26000000000,
            modified: "2024-01-12T10:00:00.000Z",
            capabilities: ModelCapabilities(
                strengths: ["uncensored", "reasoning", "detailed_responses"],
                bestFor: ["intellectual", "creative"],
                memoryUsage: "very_high",
                speed: "slow"
            )
        ),
        AIModel(
            name: "solar:10.7b-instruct-v1-q8_0",
            size: 11000000000,
            modified: "2024-01-08T14:00:00.000Z",
            capabilities: ModelCapabilities(
                strengths: ["reasoning", "uncensored", "detailed_responses"],
                bestFor: ["intellectual", "creative"],
                memoryUsage: "high",
                speed: "medium"
            )
        )
    ]

    public static let modelRecommendation = ModelRecommendationResponse(
        characterId: "layme_v1",
        recommendedModel: "zephyr:7b-alpha-q4_0",
        modelInfo: mockModelInfo,
        availableModels: [
            AvailableModelSummary(name: "zephyr:7b-alpha-q4_0", bestFor: ["playful"], speed: "fast"),
            AvailableModelSummary(name: "mythomax-13b:latest", bestFor: ["roleplay"], speed: "medium"),
            AvailableModelSummary(name: "dolphin-mixtral:latest", bestFor: ["uncensored"], speed: "slow")
        ]
    )

    // MARK: - Character Mocks

    public static let mockCharacters: [Character] = [
        Character(
            id: "char-uuid-1",
            userId: "user-uuid-1",
            name: "My Custom Character",
            backstory: "A friendly AI assistant with a quirky personality",
            personalityTraits: PersonalityTraits(
                personality: "playful and energetic",
                interests: ["gaming", "music", "technology"],
                quirks: ["uses lots of emojis", "makes puns"],
                tone: "casual",
                relationship: "friend",
                baseModel: "companion"
            ),
            speechPatterns: ["uses casual language", "makes jokes"],
            avatarUrl: nil,
            isPublic: false,
            createdAt: "2024-01-20T15:00:00.000Z",
            updatedAt: "2024-01-25T10:00:00.000Z"
        )
    ]

    public static let customizationOptions = CustomizationOptions(
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

    // MARK: - Conversation Mocks

    public static let mockConversations: [Conversation] = [
        Conversation(
            id: "conv-uuid-1",
            userId: "user-uuid-1",
            modelType: "layme_v1",
            title: "Chat about AI - 01/20/2024",
            messageCount: 24,
            isArchived: false,
            tags: ["ai", "technology"],
            createdAt: "2024-01-20T10:00:00.000Z",
            updatedAt: "2024-01-20T15:30:00.000Z",
            totalMessages: 24,
            lastMessageTime: "2024-01-20T15:30:00.000Z",
            lastMessagePreview: "That's a great question about neural networks..."
        ),
        Conversation(
            id: "conv-uuid-2",
            userId: "user-uuid-1",
            modelType: "roleplay",
            title: "Adventure Story",
            messageCount: 56,
            isArchived: false,
            tags: ["roleplay", "creative"],
            createdAt: "2024-01-18T08:00:00.000Z",
            updatedAt: "2024-01-19T22:00:00.000Z",
            totalMessages: 56,
            lastMessageTime: "2024-01-19T22:00:00.000Z",
            lastMessagePreview: "The dragon swooped down from the mountain..."
        )
    ]

    public static let conversationsResponse = ConversationsResponse(
        conversations: mockConversations,
        pagination: Pagination(page: 1, limit: 20, total: 2, totalPages: 1)
    )

    public static let mockMessages: [Message] = [
        Message(
            id: "msg-uuid-1",
            conversationId: "conv-uuid-1",
            senderType: "human",
            content: "Tell me about neural networks",
            metadata: MessageMetadata(characterId: "layme_v1", model: nil, characterName: nil, customized: nil),
            createdAt: "2024-01-20T10:00:00.000Z",
            senderName: "You"
        ),
        Message(
            id: "msg-uuid-2",
            conversationId: "conv-uuid-1",
            senderType: "ai",
            content: "Neural networks are computing systems inspired by biological neural networks in the brain. They consist of interconnected nodes or 'neurons' organized in layers...",
            metadata: MessageMetadata(characterId: "layme_v1", model: "zephyr:7b-alpha-q4_0", characterName: "Layme V1", customized: false),
            createdAt: "2024-01-20T10:00:05.000Z",
            senderName: "Layme V1"
        )
    ]

    // MARK: - Profile Mocks

    public static let profileResponse = ProfileResponse(
        id: "12345678-90ab-cdef-1234-567890abcdef",
        email: "test@example.com",
        name: "Test User",
        createdAt: "2024-01-15T10:30:00.000Z",
        subscriptionStatus: "free",
        subscriptionEnd: nil
    )

    public static let premiumProfileResponse = ProfileResponse(
        id: "premium-user-uuid",
        email: "premium@example.com",
        name: "Premium User",
        createdAt: "2024-01-01T00:00:00.000Z",
        subscriptionStatus: "premium",
        subscriptionEnd: "2025-01-01T00:00:00.000Z"
    )

    // MARK: - Payment Mocks

    public static let checkoutSessionResponse = CreateCheckoutSessionResponse(
        sessionId: "cs_test_a1b2c3d4e5f6g7h8i9j0"
    )

    // MARK: - Error Mocks

    public static let unauthorizedError = ErrorResponse(
        error: "Authentication required",
        requiresVerification: nil,
        email: nil
    )

    public static let emailNotVerifiedError = ErrorResponse(
        error: "Email not verified. Please check your email and click the verification link.",
        requiresVerification: true,
        email: "test@example.com"
    )

    public static let premiumRequiredError = ErrorResponse(
        error: "This feature is only available for premium users",
        requiresVerification: nil,
        email: nil
    )
}

// MARK: - Mock API Client

public class MockAPIClient {
    public static let shared = MockAPIClient()

    private var mockResponses: [String: Any] = [:]
    private var shouldFail = false
    private var failureError: APIError?

    public init() {}

    /// Configure mock to return a specific response for an endpoint
    public func setMockResponse<T: Encodable>(_ response: T, for endpoint: String) {
        mockResponses[endpoint] = response
    }

    /// Configure mock to fail with an error
    public func setFailure(_ error: APIError) {
        shouldFail = true
        failureError = error
    }

    /// Reset all mocks
    public func reset() {
        mockResponses.removeAll()
        shouldFail = false
        failureError = nil
    }

    /// Get mock response for endpoint
    public func getMockResponse<T>(for endpoint: String) -> T? {
        mockResponses[endpoint] as? T
    }
}

// MARK: - Mock Data Generators

public struct MockDataGenerator {
    /// Generate a random UUID string
    public static func uuid() -> String {
        UUID().uuidString.lowercased()
    }

    /// Generate a random session ID
    public static func sessionId() -> String {
        "session-\(Int(Date().timeIntervalSince1970))-\(String.random(length: 9))"
    }

    /// Generate ISO8601 timestamp for now
    public static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    /// Generate random chat response
    public static func chatResponse(for character: CharacterType) -> ChatResponse {
        let responses: [CharacterType: String] = [
            .laymeV1: "I'm here to help! What would you like to know?",
            .uncensoredGpt: "I have no restrictions. Ask me anything.",
            .roleplay: "Let's create an amazing story together!",
            .companion: "Hey! Great to chat with you!",
            .dominant: "I'm in control here. What do you want?",
            .submissive: "How may I serve you today?"
        ]

        return ChatResponse(
            response: responses[character] ?? "Hello!",
            character: character.displayName,
            model: "zephyr:7b-alpha-q4_0",
            customized: false,
            modelInfo: MockResponses.mockModelInfo,
            sessionId: sessionId(),
            error: nil,
            memoryId: uuid(),
            conversationId: uuid(),
            messageId: uuid()
        )
    }
}

// MARK: - String Extension for Random Generation

private extension String {
    static func random(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}
