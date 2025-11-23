import SwiftUI

struct VerificationView: View {
    let email: String
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "envelope.badge")
                .font(.system(size: 80))
                .foregroundStyle(Color.premiumGradient)

            // Title
            Text("Check Your Email")
                .font(.title.weight(.bold))
                .foregroundColor(.appTextPrimary)

            // Message
            Text("We've sent a verification link to \(email). Please check your email and click the link to verify your account.")
                .font(.subheadline)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            // Actions
            VStack(spacing: 16) {
                PremiumButton(
                    title: "Resend Email",
                    style: .secondary,
                    isLoading: viewModel.isLoading
                ) {
                    Task {
                        await viewModel.resendVerification()
                    }
                }

                Button(action: { viewModel.backToAuth() }) {
                    Text("Back to login")
                        .font(.footnote)
                        .foregroundColor(.appTextSecondary)
                        .underline()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appDarkBg)
    }
}

#Preview {
    VerificationView(email: "test@example.com", viewModel: AuthViewModel())
}
