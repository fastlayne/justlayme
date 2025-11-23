import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and Title
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.purple.gradient)

                        Text("JustLayMe")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Your AI Chat Companion")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    // Auth Form
                    VStack(spacing: 20) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            TextField("Enter your email", text: $authViewModel.email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .textFieldStyle(RoundedTextFieldStyle())
                        }

                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            SecureField("Enter your password", text: $authViewModel.password)
                                .textContentType(authViewModel.isSignUp ? .newPassword : .password)
                                .textFieldStyle(RoundedTextFieldStyle())
                        }

                        // Confirm Password (Sign Up only)
                        if authViewModel.isSignUp {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                SecureField("Confirm your password", text: $authViewModel.confirmPassword)
                                    .textContentType(.newPassword)
                                    .textFieldStyle(RoundedTextFieldStyle())
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal)

                    // Action Buttons
                    VStack(spacing: 16) {
                        // Primary Button
                        Button {
                            Task {
                                if authViewModel.isSignUp {
                                    await authViewModel.register()
                                } else {
                                    await authViewModel.login()
                                }
                            }
                        } label: {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(authViewModel.isSignUp ? "Create Account" : "Sign In")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(authViewModel.isFormValid ? Color.purple : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!authViewModel.isFormValid || authViewModel.isLoading)

                        // Toggle Auth Mode
                        Button {
                            withAnimation {
                                authViewModel.toggleAuthMode()
                            }
                        } label: {
                            Text(authViewModel.isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.subheadline)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.horizontal)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)

                        Text("or")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal)

                    // Social Sign In
                    VStack(spacing: 12) {
                        // Google Sign In
                        Button {
                            Task {
                                await authViewModel.signInWithGoogle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                Text("Continue with Google")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .foregroundColor(.primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(12)
                        }

                        // Continue as Guest
                        Button {
                            authViewModel.continueAsGuest()
                        } label: {
                            Text("Continue as Guest")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .alert("Error", isPresented: $authViewModel.showError) {
                Button("OK") {
                    authViewModel.dismissError()
                }
            } message: {
                Text(authViewModel.errorMessage ?? "An error occurred")
            }
            .sheet(isPresented: $authViewModel.showVerificationSent) {
                VerificationSentView(email: authViewModel.verificationEmail ?? "")
            }
        }
    }
}

// MARK: - Verification Sent View
struct VerificationSentView: View {
    let email: String
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 64))
                .foregroundColor(.purple)

            Text("Check Your Email")
                .font(.title)
                .fontWeight(.bold)

            Text("We've sent a verification link to:")
                .foregroundColor(.secondary)

            Text(email)
                .fontWeight(.medium)

            Text("Please verify your email to continue.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    Task {
                        await authViewModel.resendVerification()
                    }
                } label: {
                    Text("Resend Verification Email")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button("Back to Login") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
            .padding(.top)
        }
        .padding()
    }
}

// MARK: - Custom Text Field Style
struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
