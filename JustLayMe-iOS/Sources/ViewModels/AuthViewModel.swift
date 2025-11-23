import Foundation
import Combine
import GoogleSignIn

// MARK: - Auth State
enum AuthState: Equatable {
    case loading
    case unauthenticated
    case authenticated
    case guest
}

// MARK: - Auth ViewModel
@MainActor
final class AuthViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var authState: AuthState = .loading
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // Form State
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isSignUp = false

    // Verification State
    @Published var showVerificationSent = false
    @Published var verificationEmail: String?

    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6

        if isSignUp {
            return emailValid && passwordValid && password == confirmPassword
        }
        return emailValid && passwordValid
    }

    var isPremium: Bool {
        currentUser?.isPremium ?? false
    }

    var canAccessPremiumContent: Bool {
        currentUser?.canAccessPremiumModels ?? false
    }

    // MARK: - Auth Check
    func checkAuthStatus() async {
        authState = .loading

        // Check for existing token
        if await authService.verifyToken() {
            currentUser = TokenManager.shared.currentUser
            authState = .authenticated
        } else {
            authState = .unauthenticated
        }
    }

    // MARK: - Login
    func login() async {
        guard isFormValid else {
            showError(message: "Please enter a valid email and password")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.login(email: email, password: password)

            if !user.emailVerified {
                verificationEmail = email
                showVerificationSent = true
                isLoading = false
                return
            }

            currentUser = user
            authState = .authenticated
            clearForm()
        } catch let error as APIError {
            showError(message: error.localizedDescription)
        } catch {
            showError(message: "Login failed. Please try again.")
        }

        isLoading = false
    }

    // MARK: - Register
    func register() async {
        guard isFormValid else {
            showError(message: "Please fill in all fields correctly")
            return
        }

        guard password == confirmPassword else {
            showError(message: "Passwords do not match")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await authService.register(email: email, password: password)

            if response.requiresVerification {
                verificationEmail = email
                showVerificationSent = true
            }
        } catch let error as APIError {
            showError(message: error.localizedDescription)
        } catch {
            showError(message: "Registration failed. Please try again.")
        }

        isLoading = false
    }

    // MARK: - Google Sign In
    func signInWithGoogle() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            showError(message: "Unable to present Google Sign In")
            return
        }

        isLoading = true

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                showError(message: "Failed to get Google ID token")
                isLoading = false
                return
            }

            let user = try await authService.googleSignIn(idToken: idToken)
            currentUser = user
            authState = .authenticated
            clearForm()
        } catch {
            showError(message: "Google Sign In failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Continue as Guest
    func continueAsGuest() {
        currentUser = nil
        authState = .guest
        clearForm()
    }

    // MARK: - Resend Verification
    func resendVerification() async {
        guard let email = verificationEmail else { return }

        isLoading = true

        do {
            try await authService.resendVerification(email: email)
            showError(message: "Verification email sent!")
        } catch {
            showError(message: "Failed to resend verification email")
        }

        isLoading = false
    }

    // MARK: - Logout
    func logout() {
        authService.logout()
        currentUser = nil
        authState = .unauthenticated
        clearForm()
    }

    // MARK: - Helpers
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = nil
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func dismissError() {
        showError = false
        errorMessage = nil
    }

    func toggleAuthMode() {
        isSignUp.toggle()
        errorMessage = nil
    }
}
