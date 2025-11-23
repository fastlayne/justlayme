import SwiftUI

@main
struct JustLayMeApp: App {
    // MARK: - State Objects
    @StateObject private var appCoordinator = AppCoordinator()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var subscriptionViewModel = SubscriptionViewModel()

    // MARK: - Scene Phase
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appCoordinator)
                .environmentObject(authViewModel)
                .environmentObject(chatViewModel)
                .environmentObject(subscriptionViewModel)
                .preferredColorScheme(.dark)
                .onAppear {
                    configureAppearance()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }

    // MARK: - Private Methods

    private func configureAppearance() {
        // Configure navigation bar appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = UIColor(AppColors.darkBackground)
        navigationBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance

        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppColors.darkBackground)

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active - refresh auth state
            Task {
                await authViewModel.checkAuthState()
            }
        case .inactive:
            // App became inactive
            break
        case .background:
            // App moved to background - save state
            appCoordinator.saveState()
        @unknown default:
            break
        }
    }
}
