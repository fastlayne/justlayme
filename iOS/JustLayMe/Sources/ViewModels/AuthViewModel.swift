import Foundation
import Combine

// MARK: - Auth State

enum AuthState: Equatable {
    case idle
    case loading
    case authenticated(User)
    case requiresVerification(email: String)
    case error(AuthError)
}

enum AuthError: Error, Equatable, LocalizedError {
    case invalidCredentials
    case emailNotVerified
    case emailAlreadyRegistered
    case passwordTooShort
    case passwordsDoNotMatch
    case invalidEmail
    case networkError(String)
    case serverError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailNotVerified:
            return "Please verify your email before logging in"
        case .emailAlreadyRegistered:
            return "This email is already registered"
        case .passwordTooShort:
            return "Password must be at least 6 characters"
        case .passwordsDoNotMatch:
            return "Passwords do not match"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .networkError(let message):
            return message
        case .serverError(let message):
            return message
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// MARK: - Auth ViewModel

@MainActor
class AuthViewModel: ObservableObject {
    @Published private(set) var state: AuthState = .idle
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var name: String = ""

    private let apiClient: APIClientProtocol
    private let keychain: KeychainServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var currentUser: User? {
        if case .authenticated(let user) = state { return user }
        return nil
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var loginCredentials: LoginCredentials {
        LoginCredentials(email: email, password: password)
    }

    var registrationCredentials: RegistrationCredentials {
        RegistrationCredentials(email: email, password: password, confirmPassword: confirmPassword)
    }

    init(
        apiClient: APIClientProtocol = APIClient.shared,
        keychain: KeychainServiceProtocol = KeychainService.shared
    ) {
        self.apiClient = apiClient
        self.keychain = keychain
    }

    func login() async {
        guard validateLoginInput() else { return }

        state = .loading

        do {
            let response: AuthResponse = try await apiClient.request(
                .login(email: email.lowercased().trimmingCharacters(in: .whitespaces), password: password)
            )
            try keychain.save(token: response.token)
            if let client = apiClient as? APIClient {
                client.setAuthToken(response.token)
            }
            state = .authenticated(response.user)
            clearForm()
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            state = .error(.networkError(error.localizedDescription))
        }
    }

    func register() async {
        guard validateRegistrationInput() else { return }

        state = .loading

        do {
            let _: RegistrationResponse = try await apiClient.request(
                .register(email: email.lowercased().trimmingCharacters(in: .whitespaces), password: password)
            )
            state = .requiresVerification(email: email)
            clearForm()
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            state = .error(.networkError(error.localizedDescription))
        }
    }

    func resendVerificationEmail() async {
        guard case .requiresVerification(let email) = state else { return }

        state = .loading

        do {
            let _: VerificationResponse = try await apiClient.request(
                .resendVerification(email: email)
            )
            state = .requiresVerification(email: email)
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            state = .error(.networkError(error.localizedDescription))
        }
    }

    func verifyEmail(token: String) async {
        state = .loading

        do {
            let _: VerificationResponse = try await apiClient.request(
                .verifyEmail(token: token)
            )
            state = .idle
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            state = .error(.networkError(error.localizedDescription))
        }
    }

    func checkAuthStatus() async {
        guard let token = try? keychain.getToken() else {
            state = .idle
            return
        }

        if let client = apiClient as? APIClient {
            client.setAuthToken(token)
        }

        state = .loading

        do {
            let user: User = try await apiClient.request(.verifyToken())
            state = .authenticated(user)
        } catch {
            try? keychain.deleteToken()
            if let client = apiClient as? APIClient {
                client.setAuthToken(nil)
            }
            state = .idle
        }
    }

    func logout() {
        try? keychain.deleteToken()
        if let client = apiClient as? APIClient {
            client.setAuthToken(nil)
        }
        state = .idle
        clearForm()
    }

    func clearError() {
        if case .error = state {
            state = .idle
        }
    }

    // MARK: - Private Methods

    private func validateLoginInput() -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        if trimmedEmail.isEmpty || !trimmedEmail.contains("@") {
            state = .error(.invalidEmail)
            return false
        }

        if password.count < 6 {
            state = .error(.passwordTooShort)
            return false
        }

        return true
    }

    private func validateRegistrationInput() -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        if trimmedEmail.isEmpty || !trimmedEmail.contains("@") {
            state = .error(.invalidEmail)
            return false
        }

        if password.count < 6 {
            state = .error(.passwordTooShort)
            return false
        }

        if password != confirmPassword {
            state = .error(.passwordsDoNotMatch)
            return false
        }

        return true
    }

    private func handleAPIError(_ error: APIError) {
        switch error {
        case .unauthorized:
            state = .error(.invalidCredentials)
        case .forbidden(let message):
            if message.contains("verify") || message.contains("verified") {
                state = .error(.emailNotVerified)
            } else {
                state = .error(.serverError(message))
            }
        case .badRequest(let message):
            if message.contains("already registered") {
                state = .error(.emailAlreadyRegistered)
            } else {
                state = .error(.serverError(message))
            }
        default:
            state = .error(.serverError(error.localizedDescription ?? "Unknown error"))
        }
    }

    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        name = ""
    }
}

// MARK: - Keychain Service

protocol KeychainServiceProtocol {
    func save(token: String) throws
    func getToken() throws -> String?
    func deleteToken() throws
}

class KeychainService: KeychainServiceProtocol {
    static let shared = KeychainService()

    private let tokenKey = "com.justlayme.authToken"

    func save(token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
    }

    func getToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.readFailed
        }

        return String(data: data, encoding: .utf8)
    }

    func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed
        }
    }
}

enum KeychainError: Error {
    case saveFailed
    case readFailed
    case deleteFailed
}
