import SwiftUI

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        ZStack {
            // Background
            Color.appDarkBg
                .ignoresSafeArea()

            // Animated gradient background
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.2))
                        .frame(width: 300, height: 300)
                        .blur(radius: 60)
                        .offset(x: -geometry.size.width * 0.3, y: -geometry.size.height * 0.2)

                    Circle()
                        .fill(Color.appSecondary.opacity(0.2))
                        .frame(width: 250, height: 250)
                        .blur(radius: 50)
                        .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.1)
                }
            }

            // Content
            switch viewModel.viewState {
            case .auth:
                AuthFormView(viewModel: viewModel)
            case .verification(let email):
                VerificationView(email: email, viewModel: viewModel)
            }
        }
    }
}

struct AuthFormView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 60)

                // Logo
                Text("JustLayMe")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.premiumGradient)

                Text("AI Companions")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)

                Spacer(minLength: 40)

                // Auth Card
                VStack(spacing: 20) {
                    // Tab Selector
                    HStack(spacing: 12) {
                        AuthTabButton(
                            title: "Login",
                            isSelected: viewModel.mode == .login
                        ) {
                            viewModel.switchMode(.login)
                        }

                        AuthTabButton(
                            title: "Sign Up",
                            isSelected: viewModel.mode == .signup
                        ) {
                            viewModel.switchMode(.signup)
                        }
                    }

                    // Google Sign In
                    GoogleSignInButton {
                        // Handle Google Sign In
                    }

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.appBorder)
                            .frame(height: 1)
                        Text("or")
                            .font(.caption)
                            .foregroundColor(.appTextSecondary)
                        Rectangle()
                            .fill(Color.appBorder)
                            .frame(height: 1)
                    }
                    .padding(.vertical, 8)

                    // Email Field
                    CustomTextField(
                        placeholder: "Email",
                        text: $viewModel.email,
                        keyboardType: .emailAddress,
                        autocapitalization: .never
                    )

                    // Password Field
                    CustomSecureField(
                        placeholder: "Password",
                        text: $viewModel.password
                    )

                    // Confirm Password (signup only)
                    if viewModel.mode == .signup {
                        CustomSecureField(
                            placeholder: "Confirm Password",
                            text: $viewModel.confirmPassword
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Error Message
                    if let error = viewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Submit Button
                    PremiumButton(
                        title: viewModel.mode == .login ? "Login" : "Sign Up",
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            await viewModel.submit()
                        }
                    }
                    .disabled(!viewModel.canSubmit)

                    // Guest Link
                    Button(action: { viewModel.continueAsGuest() }) {
                        Text("Continue as guest (limited features)")
                            .font(.footnote)
                            .foregroundColor(.appTextSecondary)
                            .underline()
                    }
                }
                .padding(24)
                .background(Color.appCardBg)
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
                .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.mode)
    }
}

struct AuthTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isSelected ? .white : .appTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if isSelected {
                            Color.premiumGradient
                        } else {
                            Color.clear
                        }
                    }
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color.appBorder, lineWidth: 2)
                )
        }
    }
}

struct GoogleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 20))
                Text("Continue with Google")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthManager.shared)
}
