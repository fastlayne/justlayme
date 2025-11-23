import SwiftUI

struct RootView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if coordinator.isLoading {
                SplashView()
            } else if authViewModel.isAuthenticated || authViewModel.isGuest {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.isLoading)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .task {
            await initializeApp()
        }
        .alert(item: $coordinator.alertItem) { alertItem in
            if let secondaryButton = alertItem.secondaryButton {
                return Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    primaryButton: .default(Text(alertItem.primaryButton?.title ?? "OK")) {
                        alertItem.primaryButton?.action()
                    },
                    secondaryButton: .cancel(Text(secondaryButton.title)) {
                        secondaryButton.action()
                    }
                )
            } else {
                return Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text(alertItem.primaryButton?.title ?? "OK")) {
                        alertItem.primaryButton?.action()
                    }
                )
            }
        }
    }

    // MARK: - Private Methods

    private func initializeApp() async {
        // Add small delay for splash screen
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Check authentication state
        await authViewModel.checkAuthState()

        // Mark loading as complete
        coordinator.isLoading = false
    }
}

// MARK: - Splash View

struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            AppColors.darkBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(scale)

                Text("JustLayMe")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                    .scaleEffect(1.2)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .environmentObject(AppCoordinator())
        .environmentObject(AuthViewModel())
        .environmentObject(ChatViewModel())
        .environmentObject(SubscriptionViewModel())
}
