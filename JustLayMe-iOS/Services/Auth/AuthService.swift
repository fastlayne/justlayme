import Foundation
import Combine

// MARK: - Auth Service Protocol

protocol AuthServiceProtocol {
    var isAuthenticated: Bool { get }
    var currentUser: User? { get }
    var authStatePublisher: AnyPublisher<AuthState, Never> { get }

    func login(email: String, password: String) async throws -> User
    func register(email: String, password: String, name: String?) async throws -> User
    func loginWithGoogle(idToken: String) async throws -> User
    func logout()
    func checkAuthState() async -> Bool
    func refreshUser() async throws -> User
}

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown
    case authenticated(User)
    case guest
    case unauthenticated

    var isAuthenticated: Bool {
        switch self {
        case .authenticated, .guest:
            return true
        case .unknown, .unauthenticated:
            return false
        }
    }
}

// MARK: - Auth Service

final class AuthService: AuthServiceProtocol, ObservableObject {
    // MARK: - Singleton

    static let shared = AuthService()

    // MARK: - Published Properties

    @Published private(set) var authState: AuthState = .unknown

    // MARK: - Properties

    private let apiService: APIServiceProtocol
    private let keychainService: KeychainService
    private let authStateSubject = CurrentValueSubject<AuthState, Never>(.unknown)

    var isAuthenticated: Bool {
        authState.isAuthenticated
    }

    var currentUser: User? {
        if case .authenticated(let user) = authState {
            return user
        }
        return nil
    }

    var authStatePublisher: AnyPublisher<AuthState, Never> {
        authStateSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private init(
        apiService: APIServiceProtocol = APIService.shared,
        keychainService: KeychainService = .shared
    ) {
        self.apiService = apiService
        self.keychainService = keychainService
    }

    // MARK: - Public Methods

    func login(email: String, password: String) async throws -> User {
        let response = try await apiService.login(email: email, password: password)

        // Store token
        keychainService.saveAuthToken(response.token)
        keychainService.saveUserId(String(response.user.id))

        // Update state
        await updateAuthState(.authenticated(response.user))

        // Post notification
        NotificationCenter.default.post(name: .userDidLogin, object: response.user)

        return response.user
    }

    func register(email: String, password: String, name: String?) async throws -> User {
        let response = try await apiService.register(email: email, password: password, name: name)

        // Store token
        keychainService.saveAuthToken(response.token)
        keychainService.saveUserId(String(response.user.id))

        // Update state
        await updateAuthState(.authenticated(response.user))

        // Post notification
        NotificationCenter.default.post(name: .userDidLogin, object: response.user)

        return response.user
    }

    func loginWithGoogle(idToken: String) async throws -> User {
        let response = try await apiService.googleAuth(idToken: idToken)

        // Store token
        keychainService.saveAuthToken(response.token)
        keychainService.saveUserId(String(response.user.id))

        // Update state
        await updateAuthState(.authenticated(response.user))

        // Post notification
        NotificationCenter.default.post(name: .userDidLogin, object: response.user)

        return response.user
    }

    func continueAsGuest() {
        Task { @MainActor in
            authState = .guest
            authStateSubject.send(.guest)
        }
    }

    func logout() {
        // Clear tokens
        keychainService.clearAuthData()

        // Update state
        Task { @MainActor in
            authState = .unauthenticated
            authStateSubject.send(.unauthenticated)
        }

        // Post notification
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }

    func checkAuthState() async -> Bool {
        // Check for existing token
        guard keychainService.getAuthToken() != nil else {
            await updateAuthState(.unauthenticated)
            return false
        }

        do {
            let user = try await apiService.verifyToken()
            await updateAuthState(.authenticated(user))
            return true
        } catch {
            // Token invalid - clear it
            keychainService.clearAuthData()
            await updateAuthState(.unauthenticated)
            return false
        }
    }

    func refreshUser() async throws -> User {
        let user = try await apiService.getProfile()
        await updateAuthState(.authenticated(user))
        return user
    }

    // MARK: - Private Methods

    @MainActor
    private func updateAuthState(_ state: AuthState) {
        authState = state
        authStateSubject.send(state)
    }
}
