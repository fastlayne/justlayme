import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    enum AuthMode {
        case login
        case signup
    }

    enum ViewState {
        case auth
        case verification(email: String)
    }

    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var mode: AuthMode = .login
    @Published var viewState: ViewState = .auth
    @Published var isLoading = false
    @Published var error: String?
    @Published var showError = false

    private let authManager = AuthManager.shared

    // MARK: - Validation

    var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    var isPasswordValid: Bool {
        password.count >= 6
    }

    var passwordsMatch: Bool {
        password == confirmPassword
    }

    var canSubmit: Bool {
        isEmailValid && isPasswordValid && (mode == .login || passwordsMatch)
    }

    // MARK: - Actions

    func submit() async {
        guard canSubmit else {
            setError("Please fill in all fields correctly")
            return
        }

        isLoading = true
        error = nil

        do {
            switch mode {
            case .login:
                try await authManager.login(email: email, password: password)
            case .signup:
                let response = try await authManager.register(email: email, password: password)
                if response.requiresVerification {
                    viewState = .verification(email: email)
                }
            }
        } catch let networkError as NetworkError {
            setError(networkError.localizedDescription)
        } catch {
            setError(error.localizedDescription)
        }

        isLoading = false
    }

    func continueAsGuest() {
        authManager.continueAsGuest()
    }

    func switchMode(_ newMode: AuthMode) {
        mode = newMode
        error = nil
        confirmPassword = ""
    }

    func resendVerification() async {
        guard case .verification(let email) = viewState else { return }

        isLoading = true
        do {
            try await authManager.resendVerification(email: email)
            setError("Verification email sent!")
        } catch {
            setError(error.localizedDescription)
        }
        isLoading = false
    }

    func backToAuth() {
        viewState = .auth
        error = nil
    }

    // MARK: - Private

    private func setError(_ message: String) {
        error = message
        showError = true
    }
}
