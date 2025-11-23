import Foundation
import Combine

// MARK: - API Service Protocol

protocol APIServiceProtocol {
    // Auth
    func register(email: String, password: String, name: String?) async throws -> AuthResponse
    func login(email: String, password: String) async throws -> AuthResponse
    func verifyToken() async throws -> User
    func googleAuth(idToken: String) async throws -> AuthResponse
    func resendVerification(email: String) async throws

    // Characters
    func getCharacters() async throws -> [Character]
    func createCharacter(_ request: CharacterCreateRequest) async throws -> Character
    func updateCharacter(id: Int, _ request: CharacterUpdateRequest) async throws -> Character
    func deleteCharacter(id: Int) async throws

    // Chat
    func sendMessage(_ request: ChatRequest) async throws -> ChatResponse

    // Models
    func getModels() async throws -> [AIModel]
    func testModel(_ request: ModelTestRequest) async throws -> ModelTestResponse
    func getModelHealth() async throws -> ModelHealthResponse

    // Conversations
    func getConversations(page: Int, limit: Int) async throws -> ConversationsResponse
    func getConversationMessages(id: Int) async throws -> ConversationMessagesResponse
    func searchConversations(query: String) async throws -> ConversationSearchResponse
    func archiveConversation(id: Int) async throws
    func deleteConversation(id: Int) async throws
    func exportConversation(id: Int, format: ExportFormat) async throws -> Data

    // Profile
    func getProfile() async throws -> User
    func updateProfile(_ request: UserProfileUpdate) async throws -> User
    func exportData() async throws -> Data
    func clearData() async throws

    // Payment
    func createCheckoutSession(plan: String, userId: Int?, email: String?) async throws -> CheckoutSessionResponse
}

// MARK: - API Service

final class APIService: APIServiceProtocol {
    // MARK: - Singleton

    static let shared = APIService()

    // MARK: - Properties

    private let networkService: NetworkServiceProtocol

    // MARK: - Initialization

    private init(networkService: NetworkServiceProtocol = NetworkService.shared) {
        self.networkService = networkService
    }

    // MARK: - Auth

    func register(email: String, password: String, name: String?) async throws -> AuthResponse {
        let request = RegisterRequest(email: email, password: password, name: name)
        return try await networkService.request(
            endpoint: .register,
            method: .post,
            body: request,
            headers: nil
        )
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let request = LoginRequest(email: email, password: password)
        return try await networkService.request(
            endpoint: .login,
            method: .post,
            body: request,
            headers: nil
        )
    }

    func verifyToken() async throws -> User {
        return try await networkService.request(
            endpoint: .verify,
            method: .get,
            body: nil,
            headers: nil
        )
    }

    func googleAuth(idToken: String) async throws -> AuthResponse {
        let request = GoogleAuthRequest(idToken: idToken)
        return try await networkService.request(
            endpoint: .googleAuth,
            method: .post,
            body: request,
            headers: nil
        )
    }

    func resendVerification(email: String) async throws {
        struct ResendRequest: Codable {
            let email: String
        }

        let _: Data = try await networkService.request(
            endpoint: .resendVerification,
            method: .post,
            body: ResendRequest(email: email),
            headers: nil
        )
    }

    // MARK: - Characters

    func getCharacters() async throws -> [Character] {
        struct CharactersResponse: Codable {
            let characters: [Character]
        }

        let response: CharactersResponse = try await networkService.request(
            endpoint: .characters,
            method: .get,
            body: nil,
            headers: nil
        )
        return response.characters
    }

    func createCharacter(_ request: CharacterCreateRequest) async throws -> Character {
        return try await networkService.request(
            endpoint: .characters,
            method: .post,
            body: request,
            headers: nil
        )
    }

    func updateCharacter(id: Int, _ request: CharacterUpdateRequest) async throws -> Character {
        return try await networkService.request(
            endpoint: .character(id: id),
            method: .put,
            body: request,
            headers: nil
        )
    }

    func deleteCharacter(id: Int) async throws {
        let _: Data = try await networkService.request(
            endpoint: .character(id: id),
            method: .delete,
            body: nil,
            headers: nil
        )
    }

    // MARK: - Chat

    func sendMessage(_ request: ChatRequest) async throws -> ChatResponse {
        return try await networkService.request(
            endpoint: .chat,
            method: .post,
            body: request,
            headers: nil
        )
    }

    // MARK: - Models

    func getModels() async throws -> [AIModel] {
        struct ModelsResponse: Codable {
            let models: [AIModel]
        }

        let response: ModelsResponse = try await networkService.request(
            endpoint: .models,
            method: .get,
            body: nil,
            headers: nil
        )
        return response.models
    }

    func testModel(_ request: ModelTestRequest) async throws -> ModelTestResponse {
        return try await networkService.request(
            endpoint: .modelTest,
            method: .post,
            body: request,
            headers: nil
        )
    }

    func getModelHealth() async throws -> ModelHealthResponse {
        return try await networkService.request(
            endpoint: .modelHealth,
            method: .get,
            body: nil,
            headers: nil
        )
    }

    // MARK: - Conversations

    func getConversations(page: Int = 1, limit: Int = 20) async throws -> ConversationsResponse {
        return try await networkService.request(
            endpoint: .conversations,
            method: .get,
            body: nil,
            headers: nil
        )
    }

    func getConversationMessages(id: Int) async throws -> ConversationMessagesResponse {
        return try await networkService.request(
            endpoint: .conversationMessages(id: id),
            method: .get,
            body: nil,
            headers: nil
        )
    }

    func searchConversations(query: String) async throws -> ConversationSearchResponse {
        return try await networkService.request(
            endpoint: .conversationSearch,
            method: .get,
            body: nil,
            headers: nil
        )
    }

    func archiveConversation(id: Int) async throws {
        let _: Data = try await networkService.request(
            endpoint: .conversationArchive(id: id),
            method: .post,
            body: nil,
            headers: nil
        )
    }

    func deleteConversation(id: Int) async throws {
        let _: Data = try await networkService.request(
            endpoint: .conversation(id: id),
            method: .delete,
            body: nil,
            headers: nil
        )
    }

    func exportConversation(id: Int, format: ExportFormat) async throws -> Data {
        return try await networkService.request(
            endpoint: .conversationExport(id: id, format: format.rawValue),
            method: .get,
            body: nil,
            headers: nil
        )
    }

    // MARK: - Profile

    func getProfile() async throws -> User {
        return try await networkService.request(
            endpoint: .profile,
            method: .get,
            body: nil,
            headers: nil
        )
    }

    func updateProfile(_ request: UserProfileUpdate) async throws -> User {
        return try await networkService.request(
            endpoint: .profile,
            method: .put,
            body: request,
            headers: nil
        )
    }

    func exportData() async throws -> Data {
        return try await networkService.request(
            endpoint: .exportData,
            method: .get,
            body: nil,
            headers: nil
        )
    }

    func clearData() async throws {
        let _: Data = try await networkService.request(
            endpoint: .clearData,
            method: .delete,
            body: nil,
            headers: nil
        )
    }

    // MARK: - Payment

    func createCheckoutSession(plan: String, userId: Int?, email: String?) async throws -> CheckoutSessionResponse {
        let request = CheckoutSessionRequest(plan: plan, userId: userId, userEmail: email)
        return try await networkService.request(
            endpoint: .createCheckoutSession,
            method: .post,
            body: request,
            headers: nil
        )
    }
}
