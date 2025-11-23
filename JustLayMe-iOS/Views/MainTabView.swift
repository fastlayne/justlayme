import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            ChatTab()
                .tabItem {
                    Label(AppTab.chat.title, systemImage: AppTab.chat.icon)
                }
                .tag(AppTab.chat)

            CharactersTab()
                .tabItem {
                    Label(AppTab.characters.title, systemImage: AppTab.characters.icon)
                }
                .tag(AppTab.characters)

            ProfileTab()
                .tabItem {
                    Label(AppTab.profile.title, systemImage: AppTab.profile.icon)
                }
                .tag(AppTab.profile)
        }
        .tint(AppColors.primary)
    }
}

// MARK: - Chat Tab

struct ChatTab: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel

    var body: some View {
        NavigationStack {
            ChatView()
                .navigationTitle("Chat")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Characters Tab

struct CharactersTab: View {
    @StateObject private var characterViewModel = CharacterViewModel()

    var body: some View {
        NavigationStack {
            CharactersView()
                .navigationTitle("Characters")
                .navigationBarTitleDisplayMode(.large)
                .environmentObject(characterViewModel)
        }
    }
}

// MARK: - Profile Tab

struct ProfileTab: View {
    @StateObject private var profileViewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            ProfileView()
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.large)
                .environmentObject(profileViewModel)
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AppCoordinator())
        .environmentObject(AuthViewModel())
        .environmentObject(ChatViewModel())
        .environmentObject(SubscriptionViewModel())
        .preferredColorScheme(.dark)
}
