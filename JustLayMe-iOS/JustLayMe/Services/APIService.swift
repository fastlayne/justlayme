import Foundation
import Combine

final class APIService {
    static let shared = APIService()
    private let network = NetworkManager.shared

    private init() {}

    // MARK: - Authentication

    func register(email: String, password: String) async throws -> RegisterResponse {
        let body = ["email": email, "password": password]
        return try await network.request(
            endpoint: "/api/register",
            method: .post,
            body: body
        )
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let body = ["email": email, "password": password]
        return try await network.request(
            endpoint: "/api/login",
            method: .post,
            body: body
        )
    }

    func verifyToken() async throws -> User {
        return try await network.request(
            endpoint: "/api/verify",
            authenticated: true
        )
    }

    func verifyEmail(token: String) async throws -> VerificationResponse {
        return try await network.request(
            endpoint: "/api/verify-email?token=\(token)"
        )
    }

    func resendVerification(email: String) async throws -> VerificationResponse {
        let body = ["email": email]
        return try await network.request(
            endpoint: "/api/resend-verification",
            method: .post,
            body: body
        )
    }

    func googleAuth(credential: String) async throws -> AuthResponse {
        let body = ["credential": credential]
        return try await network.request(
            endpoint: "/api/auth/google",
            method: .post,
            body: body
        )
    }

    // MARK: - Chat

    func sendMessage(
        message: String,
        characterId: String,
        userId: String
    ) async throws -> ChatResponse {
        let request = ChatRequest(
            message: message,
            characterId: characterId,
            userId: userId
        )
        return try await network.request(
            endpoint: "/api/chat",
            method: .post,
            body: request
        )
    }

    // MARK: - Characters

    func getCharacters() async throws -> [CustomCharacter] {
        return try await network.request(
            endpoint: "/api/characters",
            authenticated: true
        )
    }

    func createCharacter(_ customization: CharacterCustomization) async throws -> CustomCharacter {
        return try await network.request(
            endpoint: "/api/characters",
            method: .post,
            body: customization,
            authenticated: true
        )
    }

    func customizeCharacter(
        id: String,
        customization: CharacterCustomization
    ) async throws -> EmptyResponse {
        return try await network.request(
            endpoint: "/api/characters/\(id)/customize",
            method: .post,
            body: customization,
            authenticated: true
        )
    }

    // MARK: - Conversations

    func getConversations() async throws -> [Conversation] {
        return try await network.request(
            endpoint: "/api/conversations",
            authenticated: true
        )
    }

    func getMessages(conversationId: String) async throws -> [Message] {
        return try await network.request(
            endpoint: "/api/conversations/\(conversationId)/messages",
            authenticated: true
        )
    }

    func archiveConversation(id: String) async throws -> EmptyResponse {
        return try await network.request(
            endpoint: "/api/conversations/\(id)/archive",
            method: .post,
            authenticated: true
        )
    }

    func deleteConversation(id: String) async throws -> EmptyResponse {
        return try await network.request(
            endpoint: "/api/conversations/\(id)",
            method: .delete,
            authenticated: true
        )
    }

    // MARK: - Profile

    func getProfile() async throws -> User {
        return try await network.request(
            endpoint: "/api/profile",
            authenticated: true
        )
    }

    func updateProfile(_ request: ProfileUpdateRequest) async throws -> User {
        return try await network.request(
            endpoint: "/api/profile",
            method: .put,
            body: request,
            authenticated: true
        )
    }

    // MARK: - Data Management

    func exportData() async throws -> Data {
        return try await network.requestData(
            endpoint: "/api/export-data",
            authenticated: true
        )
    }

    func clearData() async throws -> EmptyResponse {
        return try await network.request(
            endpoint: "/api/clear-data",
            method: .delete,
            authenticated: true
        )
    }

    // MARK: - Models

    func getModels() async throws -> ModelsResponse {
        return try await network.request(endpoint: "/api/models")
    }

    // MARK: - Payments

    func createCheckoutSession(
        plan: String,
        userId: String,
        email: String
    ) async throws -> CheckoutSessionResponse {
        let request = CheckoutSessionRequest(
            plan: plan,
            userId: userId,
            userEmail: email
        )
        return try await network.request(
            endpoint: "/api/create-checkout-session",
            method: .post,
            body: request
        )
    }
}

struct ModelsResponse: Codable {
    let models: [AIModel]
    let defaultModel: String
    let totalModels: Int

    enum CodingKeys: String, CodingKey {
        case models
        case defaultModel = "default_model"
        case totalModels = "total_models"
    }
}

struct AIModel: Codable, Identifiable {
    let name: String
    let size: Int?

    var id: String { name }
}
