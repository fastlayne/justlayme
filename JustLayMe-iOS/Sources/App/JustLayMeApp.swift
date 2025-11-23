import SwiftUI
import StripePaymentSheet

@main
struct JustLayMeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var navigationCoordinator = NavigationCoordinator()

    init() {
        // Configure Stripe with publishable key
        StripeAPI.defaultPublishableKey = AppConfig.stripePublishableKey
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authViewModel)
                .environmentObject(navigationCoordinator)
                .onAppear {
                    Task {
                        await authViewModel.checkAuthStatus()
                    }
                }
        }
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }
}

// MARK: - App Configuration
enum AppConfig {
    // Server Configuration - Update for your environment
    static let baseURL = "http://localhost:3000"
    static let websocketURL = "ws://localhost:3000"

    // Production URLs (uncomment when deploying)
    // static let baseURL = "https://justlay.me"
    // static let websocketURL = "wss://justlay.me"

    // Stripe Configuration
    static let stripePublishableKey = "pk_test_51RaZdMBG18npwvfXQtexz8KmG0Mj59YHSaY4kp8i5hie2zztv1WHcWXKYGQzgzTAPkV9RpsgbsQKzDGPZvII6URY00J2wgzyRX"

    // Free Message Limits
    static let freeMessageLimit = 3
    static let unlimitedFreeModel = "layme_v1"

    // Google OAuth Client ID (add your iOS client ID)
    static let googleClientID = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
}
