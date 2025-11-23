import Foundation
import Combine
import SwiftUI

// MARK: - Auth View Model

@MainActor
final class AuthViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var name: String = ""

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    @Published var isAuthenticated: Bool = false
    @Published var isGuest: Bool = false
    @Published var currentUser: User?

    @Published var showEmailVerification: Bool = false
    @Published var isLoginMode: Bool = true

    // MARK: - Properties

    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var isFormValid: Bool {
        if isLoginMode {
            return isValidEmail && !password.isEmpty
        } else {
            return isValidEmail && !password.isEmpty && password == confirmPassword && password.count >= 6
        }
    }

    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    var passwordStrength: PasswordStrength {
        if password.count < 6 {
            return .weak
        } else if password.count < 10 {
            return .medium
        } else {
            return .strong
        }
    }

    // MARK: - Initialization

    init(authService: AuthService = .shared) {
        self.authService = authService
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        authService.$authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .authenticated(let user):
                    self?.isAuthenticated = true
                    self?.isGuest = false
                    self?.currentUser = user
                case .guest:
                    self?.isAuthenticated = false
                    self?.isGuest = true
                    self?.currentUser = nil
                case .unauthenticated, .unknown:
                    self?.isAuthenticated = false
                    self?.isGuest = false
                    self?.currentUser = nil
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func login() async {
        guard isFormValid else {
            errorMessage = "Please enter a valid email and password"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.login(email: email, password: password)
            currentUser = user
            isAuthenticated = true
            clearForm()
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func register() async {
        guard isFormValid else {
            errorMessage = "Please fill all fields correctly"
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.register(
                email: email,
                password: password,
                name: name.isEmpty ? nil : name
            )

            if !user.emailVerified {
                showEmailVerification = true
                successMessage = "Please check your email to verify your account"
            } else {
                currentUser = user
                isAuthenticated = true
            }

            clearForm()
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loginWithGoogle(idToken: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.loginWithGoogle(idToken: idToken)
            currentUser = user
            isAuthenticated = true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func continueAsGuest() {
        authService.continueAsGuest()
        isGuest = true
    }

    func logout() {
        authService.logout()
        isAuthenticated = false
        isGuest = false
        currentUser = nil
        clearForm()
    }

    func resendVerificationEmail() async {
        isLoading = true
        errorMessage = nil

        do {
            try await APIService.shared.resendVerification(email: email)
            successMessage = "Verification email sent"
        } catch {
            errorMessage = "Failed to send verification email"
        }

        isLoading = false
    }

    func checkAuthState() async {
        isLoading = true
        _ = await authService.checkAuthState()
        isLoading = false
    }

    func toggleMode() {
        isLoginMode.toggle()
        errorMessage = nil
        successMessage = nil
    }

    // MARK: - Private Methods

    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        name = ""
    }
}

// MARK: - Password Strength

enum PasswordStrength {
    case weak
    case medium
    case strong

    var color: Color {
        switch self {
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }

    var text: String {
        switch self {
        case .weak: return "Weak"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }
}
