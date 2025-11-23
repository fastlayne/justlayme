// MARK: - Authentication Service
// Handles user registration, login, and token management

import Foundation
import Combine

public final class AuthService: ObservableObject {
    public static let shared = AuthService()

    private let client: APIClient
    private var cancellables = Set<AnyCancellable>()

    @Published public private(set) var currentUser: User?
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isLoading: Bool = false

    private let tokenKey = "JustLayMe_AuthToken"
    private let userKey = "JustLayMe_CurrentUser"

    public init(client: APIClient = .shared) {
        self.client = client
        loadStoredCredentials()
    }

    // MARK: - Token Management

    private func loadStoredCredentials() {
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            client.authToken = token
            isAuthenticated = true

            if let userData = UserDefaults.standard.data(forKey: userKey),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                currentUser = user
            }
        }
    }

    private func storeCredentials(token: String, user: User) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
        client.authToken = token
        currentUser = user
        isAuthenticated = true
    }

    public func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        client.authToken = nil
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Registration

    public func register(email: String, password: String) -> AnyPublisher<RegisterResponse, APIError> {
        isLoading = true

        let request = RegisterRequest(email: email, password: password)
        return client.request(.register, body: request)
            .handleEvents(
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func register(email: String, password: String) async throws -> RegisterResponse {
        isLoading = true
        defer { isLoading = false }

        let request = RegisterRequest(email: email, password: password)
        return try await client.request(.register, body: request)
    }

    // MARK: - Login

    public func login(email: String, password: String) -> AnyPublisher<LoginResponse, APIError> {
        isLoading = true

        let request = LoginRequest(email: email, password: password)
        return client.request(.login, body: request)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.storeCredentials(token: response.token, user: response.user)
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func login(email: String, password: String) async throws -> LoginResponse {
        isLoading = true
        defer { isLoading = false }

        let request = LoginRequest(email: email, password: password)
        let response: LoginResponse = try await client.request(.login, body: request)
        storeCredentials(token: response.token, user: response.user)
        return response
    }

    // MARK: - Google Authentication

    public func loginWithGoogle(credential: String) -> AnyPublisher<LoginResponse, APIError> {
        isLoading = true

        let request = GoogleAuthRequest(credential: credential)
        return client.request(.googleAuth, body: request)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.storeCredentials(token: response.token, user: response.user)
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func loginWithGoogle(credential: String) async throws -> LoginResponse {
        isLoading = true
        defer { isLoading = false }

        let request = GoogleAuthRequest(credential: credential)
        let response: LoginResponse = try await client.request(.googleAuth, body: request)
        storeCredentials(token: response.token, user: response.user)
        return response
    }

    // MARK: - Email Verification

    public func verifyEmail(token: String) -> AnyPublisher<VerifyEmailResponse, APIError> {
        let queryItems = [URLQueryItem(name: "token", value: token)]
        return client.request(.verifyEmail, queryItems: queryItems)
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func verifyEmail(token: String) async throws -> VerifyEmailResponse {
        let queryItems = [URLQueryItem(name: "token", value: token)]
        return try await client.request(.verifyEmail, queryItems: queryItems)
    }

    public func resendVerification(email: String) -> AnyPublisher<ResendVerificationResponse, APIError> {
        let request = ResendVerificationRequest(email: email)
        return client.request(.resendVerification, body: request)
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func resendVerification(email: String) async throws -> ResendVerificationResponse {
        let request = ResendVerificationRequest(email: email)
        return try await client.request(.resendVerification, body: request)
    }

    // MARK: - Token Verification

    public func verifyToken() -> AnyPublisher<User, APIError> {
        guard isAuthenticated else {
            return Fail(error: .unauthorized).eraseToAnyPublisher()
        }

        return client.request(.verify)
            .handleEvents(
                receiveOutput: { [weak self] user in
                    self?.currentUser = user
                },
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.clearCredentials()
                    }
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func verifyToken() async throws -> User {
        guard isAuthenticated else {
            throw APIError.unauthorized
        }

        do {
            let user: User = try await client.request(.verify)
            currentUser = user
            return user
        } catch {
            clearCredentials()
            throw error
        }
    }

    // MARK: - Logout

    public func logout() {
        clearCredentials()
    }
}
