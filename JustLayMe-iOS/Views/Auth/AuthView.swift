import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            // Background
            AppColors.darkBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Logo
                    logoSection

                    // Form
                    formSection

                    // Social Login
                    socialLoginSection

                    // Guest Option
                    guestSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
        }
        .alert("Error", isPresented: .constant(authViewModel.errorMessage != nil)) {
            Button("OK") {
                authViewModel.errorMessage = nil
            }
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.primaryGradient)

            Text("JustLayMe")
                .font(AppFonts.title)
                .foregroundColor(.white)

            Text(authViewModel.isLoginMode ? "Welcome back!" : "Create your account")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 16) {
            // Mode Toggle
            Picker("Mode", selection: $authViewModel.isLoginMode) {
                Text("Login").tag(true)
                Text("Sign Up").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 8)

            // Name field (signup only)
            if !authViewModel.isLoginMode {
                CustomTextField(
                    placeholder: "Name (optional)",
                    text: $authViewModel.name,
                    icon: "person.fill"
                )
            }

            // Email field
            CustomTextField(
                placeholder: "Email",
                text: $authViewModel.email,
                icon: "envelope.fill",
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never
            )

            // Password field
            CustomSecureField(
                placeholder: "Password",
                text: $authViewModel.password,
                icon: "lock.fill"
            )

            // Confirm password (signup only)
            if !authViewModel.isLoginMode {
                CustomSecureField(
                    placeholder: "Confirm Password",
                    text: $authViewModel.confirmPassword,
                    icon: "lock.fill"
                )

                // Password strength
                if !authViewModel.password.isEmpty {
                    PasswordStrengthView(strength: authViewModel.passwordStrength)
                }
            }

            // Submit button
            Button {
                Task {
                    if authViewModel.isLoginMode {
                        await authViewModel.login()
                    } else {
                        await authViewModel.register()
                    }
                }
            } label: {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(authViewModel.isLoginMode ? "Login" : "Create Account")
                            .font(AppFonts.semibold(16))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppColors.primaryGradient)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(authViewModel.isLoading || !authViewModel.isFormValid)
            .opacity(authViewModel.isFormValid ? 1.0 : 0.6)
        }
    }

    // MARK: - Social Login Section

    private var socialLoginSection: some View {
        VStack(spacing: 16) {
            HStack {
                Rectangle()
                    .fill(AppColors.textMuted.opacity(0.3))
                    .frame(height: 1)

                Text("or")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textMuted)

                Rectangle()
                    .fill(AppColors.textMuted.opacity(0.3))
                    .frame(height: 1)
            }

            // Google Sign In
            Button {
                // TODO: Implement Google Sign In
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 20))

                    Text("Continue with Google")
                        .font(AppFonts.medium(16))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(12)
            }

            // Apple Sign In
            Button {
                // TODO: Implement Apple Sign In
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20))

                    Text("Continue with Apple")
                        .font(AppFonts.medium(16))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Guest Section

    private var guestSection: some View {
        Button {
            authViewModel.continueAsGuest()
        } label: {
            Text("Continue as Guest")
                .font(AppFonts.medium(16))
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Password Strength View

struct PasswordStrengthView: View {
    let strength: PasswordStrength

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(height: 4)
            }

            Text(strength.text)
                .font(AppFonts.small)
                .foregroundColor(strength.color)
        }
    }

    private func barColor(for index: Int) -> Color {
        switch strength {
        case .weak:
            return index == 0 ? .red : AppColors.textMuted.opacity(0.3)
        case .medium:
            return index < 2 ? .orange : AppColors.textMuted.opacity(0.3)
        case .strong:
            return .green
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
