import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showPaywall = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
                    .sheet(isPresented: $showPaywall) {
                        PaywallView()
                    }
            } else {
                AuthenticationView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
    }
}

struct MainTabView: View {
    @StateObject private var chatViewModel = ChatViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CharacterSelectorView(viewModel: chatViewModel)
                ChatView(viewModel: chatViewModel)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LogoView()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileButton()
                }
            }
        }
    }
}

struct LogoView: View {
    var body: some View {
        Text("JustLayMe")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.purple, Color.pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

struct ProfileButton: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showMenu = false

    var body: some View {
        Menu {
            Button(action: { showProfile() }) {
                Label("Profile", systemImage: "person.circle")
            }
            Button(action: { showSubscription() }) {
                Label("Subscription", systemImage: "diamond")
            }
            Button(action: { showSettings() }) {
                Label("Settings", systemImage: "gearshape")
            }
            Divider()
            Button(role: .destructive, action: { authManager.logout() }) {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            UserAvatarView(name: authManager.currentUser?.name ?? "?", size: 36)
        }
    }

    private func showProfile() {
        // Navigate to profile
    }

    private func showSubscription() {
        // Show paywall
    }

    private func showSettings() {
        // Navigate to settings
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .environmentObject(ThemeManager.shared)
}
