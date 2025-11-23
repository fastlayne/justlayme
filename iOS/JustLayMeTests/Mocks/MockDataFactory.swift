import Foundation
@testable import JustLayMe

// MARK: - Mock Data Factory

enum MockDataFactory {

    // MARK: - Users

    static func createUser(
        id: String = UUID().uuidString,
        email: String = "test@example.com",
        name: String? = "Test User",
        subscriptionStatus: SubscriptionStatus = .free,
        subscriptionEnd: Date? = nil,
        emailVerified: Bool = true,
        messageCount: Int = 0,
        createdAt: Date = Date(),
        lastLogin: Date? = Date()
    ) -> User {
        User(
            id: id,
            email: email,
            name: name,
            subscriptionStatus: subscriptionStatus,
            subscriptionEnd: subscriptionEnd,
            emailVerified: emailVerified,
            isProfessionalEmail: false,
            messageCount: messageCount,
            createdAt: createdAt,
            lastLogin: lastLogin
        )
    }

    static func createFreeUser() -> User {
        createUser(subscriptionStatus: .free)
    }

    static func createPremiumUser(endDate: Date = Date().addingTimeInterval(30 * 24 * 60 * 60)) -> User {
        createUser(subscriptionStatus: .premium, subscriptionEnd: endDate)
    }

    static func createLifetimeUser() -> User {
        createUser(subscriptionStatus: .lifetime)
    }

    static func createUnverifiedUser() -> User {
        createUser(emailVerified: false)
    }

    // MARK: - Auth Responses

    static func createAuthResponse(
        token: String = "mock-jwt-token-\(UUID().uuidString)",
        user: User? = nil
    ) -> AuthResponse {
        AuthResponse(token: token, user: user ?? createUser())
    }

    static func createRegistrationResponse(
        email: String = "test@example.com",
        emailSent: Bool = true
    ) -> RegistrationResponse {
        RegistrationResponse(
            message: "Registration successful!",
            email: email,
            requiresVerification: true,
            emailSent: emailSent
        )
    }

    static func createVerificationResponse(email: String = "test@example.com") -> VerificationResponse {
        VerificationResponse(message: "Email verified successfully!", email: email)
    }

    // MARK: - Characters

    static func createCharacter(
        id: String = UUID().uuidString,
        name: String = "Test Character",
        backstory: String? = "A mysterious AI companion",
        personalityTraits: [String: Int]? = ["friendliness": 8, "humor": 7],
        speechPatterns: [String]? = ["Uses casual language", "Often makes jokes"],
        isPublic: Bool = false,
        createdAt: Date = Date()
    ) -> AICharacter {
        AICharacter(
            id: id,
            name: name,
            backstory: backstory,
            personalityTraits: personalityTraits,
            speechPatterns: speechPatterns,
            avatarURL: nil,
            isPublic: isPublic,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    static func createCharacters(count: Int) -> [AICharacter] {
        (0..<count).map { index in
            createCharacter(name: "Character \(index + 1)")
        }
    }

    static func createCustomizationOptions() -> CustomizationOptions {
        CustomizationOptions(
            personalityTraits: ["friendly", "mysterious", "playful", "intellectual", "adventurous"],
            speechStyles: ["casual", "formal", "flirty", "professional", "poetic"],
            tones: ["warm", "sarcastic", "enthusiastic", "calm", "dramatic"],
            interests: ["technology", "art", "music", "travel", "gaming", "movies"]
        )
    }

    // MARK: - Chat

    static func createChatMessage(
        id: String = UUID().uuidString,
        conversationId: String? = nil,
        senderType: SenderType = .human,
        content: String = "Hello, how are you?",
        createdAt: Date = Date()
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            conversationId: conversationId,
            senderType: senderType,
            content: content,
            metadata: nil,
            createdAt: createdAt
        )
    }

    static func createUserMessage(content: String = "Hello!") -> ChatMessage {
        createChatMessage(senderType: .human, content: content)
    }

    static func createAIMessage(content: String = "Hi there! How can I help you today?") -> ChatMessage {
        createChatMessage(senderType: .ai, content: content)
    }

    static func createConversation(count: Int) -> [ChatMessage] {
        var messages: [ChatMessage] = []
        let conversationId = UUID().uuidString

        for i in 0..<count {
            let isUser = i % 2 == 0
            messages.append(createChatMessage(
                conversationId: conversationId,
                senderType: isUser ? .human : .ai,
                content: isUser ? "User message \(i / 2 + 1)" : "AI response \(i / 2 + 1)",
                createdAt: Date().addingTimeInterval(Double(i) * 60)
            ))
        }

        return messages
    }

    static func createConversationModel(
        id: String = UUID().uuidString,
        userId: String? = nil,
        modelType: String = CharacterType.laymeV1.rawValue,
        title: String? = "Test Conversation",
        messageCount: Int = 0,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) -> Conversation {
        Conversation(
            id: id,
            userId: userId,
            modelType: modelType,
            title: title,
            messageCount: messageCount,
            isArchived: isArchived,
            tags: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    static func createConversations(count: Int) -> [Conversation] {
        (0..<count).map { index in
            createConversationModel(title: "Conversation \(index + 1)")
        }
    }

    static func createChatResponse(
        response: String = "Hello! I'm doing great, thanks for asking!",
        character: String = "Layme V1",
        model: String = "zephyr:7b-alpha-q4_0",
        customized: Bool = false,
        sessionId: String = UUID().uuidString
    ) -> ChatResponse {
        ChatResponse(
            response: response,
            character: character,
            model: model,
            customized: customized,
            modelInfo: createModelInfo(),
            sessionId: sessionId,
            error: nil
        )
    }

    static func createModelInfo() -> ModelInfo {
        ModelInfo(
            name: "zephyr:7b-alpha-q4_0",
            size: 4_000_000_000,
            capabilities: ModelCapabilities(
                strengths: ["fast", "conversational"],
                bestFor: ["playful", "casual"],
                memoryUsage: "medium",
                speed: "fast"
            ),
            recommendedFor: ["casual", "roleplay"]
        )
    }

    // MARK: - Subscription

    static func createCheckoutSession(sessionId: String = "cs_test_\(UUID().uuidString)") -> CheckoutSession {
        CheckoutSession(sessionId: sessionId)
    }

    // MARK: - Profile

    static func createExportData(user: User? = nil) -> ExportData {
        ExportData(
            user: user ?? createUser(),
            conversations: createConversations(count: 3),
            characters: createCharacters(count: 2),
            exportedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    // MARK: - Edge Cases

    static func createUserAtMessageLimit(limit: Int = 100) -> User {
        createUser(messageCount: limit)
    }

    static func createExpiredPremiumUser() -> User {
        createUser(
            subscriptionStatus: .premium,
            subscriptionEnd: Date().addingTimeInterval(-24 * 60 * 60) // Expired yesterday
        )
    }

    static func createLongMessage(wordCount: Int = 500) -> String {
        Array(repeating: "Lorem ipsum dolor sit amet", count: wordCount / 5).joined(separator: " ")
    }

    static func createEmptyConversation() -> Conversation {
        createConversationModel(messageCount: 0)
    }

    static func createArchivedConversation() -> Conversation {
        createConversationModel(isArchived: true)
    }
}

// MARK: - Test Credentials

extension MockDataFactory {
    static let validEmail = "test@example.com"
    static let validPassword = "password123"
    static let invalidEmail = "notanemail"
    static let shortPassword = "123"
    static let premiumEmail = "premium@company.com"
}
