import Foundation
import Combine

final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = false
    @Published var error: String?

    private let api = APIService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        checkAuthentication()
    }

    // MARK: - Public Methods

    func checkAuthentication() {
        guard KeychainService.shared.getToken() != nil else {
            isAuthenticated = false
            currentUser = nil
            return
        }

        Task { @MainActor in
            isLoading = true
            do {
                let user = try await api.verifyToken()
                self.currentUser = user
                self.isAuthenticated = true
            } catch {
                // Token invalid, clear it
                KeychainService.shared.deleteToken()
                self.isAuthenticated = false
                self.currentUser = nil
            }
            isLoading = false
        }
    }

    func login(email: String, password: String) async throws {
        await MainActor.run { isLoading = true }

        do {
            let response = try await api.login(email: email, password: password)
            KeychainService.shared.saveToken(response.token)
            UserDefaults.standard.set(try? JSONEncoder().encode(response.user), forKey: "currentUser")

            await MainActor.run {
                self.currentUser = response.user
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.error = error.localizedDescription
            }
            throw error
        }
    }

    func register(email: String, password: String) async throws -> RegisterResponse {
        await MainActor.run { isLoading = true }

        do {
            let response = try await api.register(email: email, password: password)
            await MainActor.run { isLoading = false }
            return response
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.error = error.localizedDescription
            }
            throw error
        }
    }

    func googleSignIn(credential: String) async throws {
        await MainActor.run { isLoading = true }

        do {
            let response = try await api.googleAuth(credential: credential)
            KeychainService.shared.saveToken(response.token)

            await MainActor.run {
                self.currentUser = response.user
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.error = error.localizedDescription
            }
            throw error
        }
    }

    func continueAsGuest() {
        let guestUser = User(
            id: "guest",
            email: "guest@demo.com",
            name: "Guest",
            subscriptionStatus: .free,
            subscriptionEnd: nil,
            emailVerified: false,
            messageCount: 0,
            createdAt: Date(),
            lastLogin: Date()
        )
        currentUser = guestUser
        isAuthenticated = true
    }

    func logout() {
        KeychainService.shared.deleteToken()
        UserDefaults.standard.removeObject(forKey: "currentUser")
        currentUser = nil
        isAuthenticated = false
    }

    func resendVerification(email: String) async throws {
        _ = try await api.resendVerification(email: email)
    }

    func verifyEmail(token: String) async throws {
        _ = try await api.verifyEmail(token: token)
    }

    func updateProfile(name: String?) async throws {
        let request = ProfileUpdateRequest(
            name: name,
            avatarStyle: nil,
            themePreference: nil
        )
        let updatedUser = try await api.updateProfile(request)

        await MainActor.run {
            self.currentUser = updatedUser
        }
    }

    var isPremium: Bool {
        currentUser?.isPremium ?? false
    }
}
