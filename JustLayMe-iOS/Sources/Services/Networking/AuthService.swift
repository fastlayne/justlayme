import Foundation
import Combine

// MARK: - Auth Service
final class AuthService {
    static let shared = AuthService()
    private let apiClient = APIClient.shared

    private init() {}

    // MARK: - Login
    func login(email: String, password: String) async throws -> User {
        let response: LoginResponse = try await apiClient.request(
            .login(email: email, password: password),
            responseType: LoginResponse.self
        )

        // Store token and user
        TokenManager.shared.authToken = response.token
        TokenManager.shared.currentUser = response.user

        return response.user
    }

    // MARK: - Register
    func register(email: String, password: String) async throws -> RegisterResponse {
        let response: RegisterResponse = try await apiClient.request(
            .register(email: email, password: password),
            responseType: RegisterResponse.self
        )
        return response
    }

    // MARK: - Google Sign In
    func googleSignIn(idToken: String) async throws -> User {
        let response: LoginResponse = try await apiClient.request(
            .googleAuth(credential: idToken),
            responseType: LoginResponse.self
        )

        TokenManager.shared.authToken = response.token
        TokenManager.shared.currentUser = response.user

        return response.user
    }

    // MARK: - Verify Token
    func verifyToken() async throws -> Bool {
        guard TokenManager.shared.authToken != nil else {
            return false
        }

        // Check if token is expired locally first
        if TokenManager.shared.isTokenExpired {
            TokenManager.shared.clearAll()
            return false
        }

        do {
            let _: VerifyTokenResponse = try await apiClient.request(
                .verifyToken,
                responseType: VerifyTokenResponse.self
            )
            return true
        } catch {
            TokenManager.shared.clearAll()
            return false
        }
    }

    // MARK: - Resend Verification
    func resendVerification(email: String) async throws {
        struct Response: Codable {
            let message: String
        }
        let _: Response = try await apiClient.request(
            .resendVerification(email: email),
            responseType: Response.self
        )
    }

    // MARK: - Logout
    func logout() {
        TokenManager.shared.clearAll()
    }

    // MARK: - Get Current User
    var currentUser: User? {
        TokenManager.shared.currentUser
    }

    var isAuthenticated: Bool {
        TokenManager.shared.isAuthenticated
    }
}

// MARK: - Chat Service
final class ChatService {
    static let shared = ChatService()
    private let apiClient = APIClient.shared

    private init() {}

    func sendMessage(
        message: String,
        characterId: String,
        userId: String? = nil
    ) async throws -> ChatResponse {
        let effectiveUserId = userId ?? TokenManager.shared.currentUser?.id
        return try await apiClient.request(
            .sendMessage(message: message, characterId: characterId, userId: effectiveUserId),
            responseType: ChatResponse.self
        )
    }

    func sendFeedback(
        memoryId: String,
        score: Int,
        correctedResponse: String? = nil,
        patternType: String? = nil
    ) async throws {
        try await apiClient.requestEmpty(
            .sendFeedback(memoryId: memoryId, score: score, correctedResponse: correctedResponse, patternType: patternType)
        )
    }
}

// MARK: - Character Service
final class CharacterService {
    static let shared = CharacterService()
    private let apiClient = APIClient.shared

    private init() {}

    func getCharacters() async throws -> [AICharacter] {
        return try await apiClient.request(
            .characters,
            responseType: [AICharacter].self
        )
    }

    func createCharacter(_ request: CreateCharacterRequest) async throws -> AICharacter {
        return try await apiClient.request(
            .createCharacter(request),
            responseType: AICharacter.self
        )
    }

    func updateCharacter(
        id: String,
        traits: [String]? = nil,
        backstory: String? = nil,
        patterns: [String]? = nil
    ) async throws -> AICharacter {
        return try await apiClient.request(
            .updateCharacter(id: id, traits: traits, backstory: backstory, patterns: patterns),
            responseType: AICharacter.self
        )
    }

    func getCustomizationOptions(characterId: String) async throws -> CharacterCustomizationOptions {
        return try await apiClient.request(
            .characterCustomizationOptions(id: characterId),
            responseType: CharacterCustomizationOptions.self
        )
    }
}

// MARK: - Conversation Service
final class ConversationService {
    static let shared = ConversationService()
    private let apiClient = APIClient.shared

    private init() {}

    func getConversations(page: Int = 1, limit: Int = 20) async throws -> [Conversation] {
        let response: ConversationsResponse = try await apiClient.request(
            .conversations(page: page, limit: limit),
            responseType: ConversationsResponse.self
        )
        return response.conversations
    }

    func getMessages(conversationId: String) async throws -> [Message] {
        let response: MessagesResponse = try await apiClient.request(
            .conversationMessages(id: conversationId),
            responseType: MessagesResponse.self
        )
        return response.messages
    }

    func searchConversations(query: String) async throws -> [Conversation] {
        let response: ConversationsResponse = try await apiClient.request(
            .searchConversations(query: query),
            responseType: ConversationsResponse.self
        )
        return response.conversations
    }

    func archiveConversation(id: String) async throws {
        try await apiClient.requestEmpty(.archiveConversation(id: id))
    }

    func deleteConversation(id: String) async throws {
        try await apiClient.requestEmpty(.deleteConversation(id: id))
    }

    func exportConversation(id: String) async throws -> Data {
        return try await apiClient.requestData(.exportConversation(id: id))
    }
}

// MARK: - Profile Service
final class ProfileService {
    static let shared = ProfileService()
    private let apiClient = APIClient.shared

    private init() {}

    func getProfile() async throws -> User {
        return try await apiClient.request(
            .profile,
            responseType: User.self
        )
    }

    func updateProfile(name: String?, avatarStyle: String?, theme: String?) async throws -> User {
        let request = ProfileUpdateRequest(name: name, avatarStyle: avatarStyle, themePreference: theme)
        let response: ProfileUpdateResponse = try await apiClient.request(
            .updateProfile(request),
            responseType: ProfileUpdateResponse.self
        )
        TokenManager.shared.currentUser = response.user
        return response.user
    }

    func exportData() async throws -> ExportedData {
        return try await apiClient.request(
            .exportData,
            responseType: ExportedData.self
        )
    }

    func clearAllData() async throws {
        try await apiClient.requestEmpty(.clearData)
    }
}

// MARK: - Payment Service
final class PaymentService {
    static let shared = PaymentService()
    private let apiClient = APIClient.shared

    private init() {}

    func createCheckoutSession(plan: SubscriptionPlan) async throws -> String {
        let user = TokenManager.shared.currentUser
        let response: CheckoutSessionResponse = try await apiClient.request(
            .createCheckoutSession(plan: plan.rawValue, userId: user?.id, email: user?.email),
            responseType: CheckoutSessionResponse.self
        )
        return response.sessionId
    }
}

// MARK: - Model Service
final class ModelService {
    static let shared = ModelService()
    private let apiClient = APIClient.shared

    private init() {}

    func getModels() async throws -> ModelsResponse {
        return try await apiClient.request(
            .models,
            responseType: ModelsResponse.self
        )
    }

    func testModel(model: String, prompt: String) async throws -> String {
        struct Response: Codable {
            let response: String
            let responseTime: Double?

            enum CodingKeys: String, CodingKey {
                case response
                case responseTime = "response_time"
            }
        }
        let response: Response = try await apiClient.request(
            .testModel(model: model, prompt: prompt),
            responseType: Response.self
        )
        return response.response
    }
}
