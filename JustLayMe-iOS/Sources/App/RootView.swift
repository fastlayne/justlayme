import SwiftUI

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch authViewModel.authState {
            case .loading:
                LoadingView()

            case .unauthenticated:
                AuthView()
                    .transition(.opacity)

            case .authenticated, .guest:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.authState)
        .alert("Error", isPresented: $appState.showError) {
            Button("OK") {
                appState.clearError()
            }
        } message: {
            Text(appState.errorMessage ?? "An unknown error occurred")
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(0)

            CharacterListView()
                .tabItem {
                    Label("Characters", systemImage: "person.2.fill")
                }
                .tag(1)

            if authViewModel.authState == .authenticated {
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.circle.fill")
                    }
                    .tag(2)
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .tint(.purple)
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(AuthViewModel())
        .environmentObject(NavigationCoordinator())
}
