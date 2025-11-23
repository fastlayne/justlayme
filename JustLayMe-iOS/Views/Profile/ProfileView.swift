import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    @State private var showSubscription = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            AppColors.darkBackground
                .ignoresSafeArea()

            if authViewModel.isGuest {
                guestView
            } else if let user = profileViewModel.user {
                loggedInView(user: user)
            } else {
                loadingView
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
                .environmentObject(subscriptionViewModel)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(profileViewModel)
        }
        .task {
            if !authViewModel.isGuest {
                await profileViewModel.loadProfile()
            }
        }
    }

    // MARK: - Guest View

    private var guestView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.circle")
                .font(.system(size: 80))
                .foregroundColor(AppColors.textMuted)

            Text("You're browsing as a guest")
                .font(AppFonts.headline)
                .foregroundColor(.white)

            Text("Create an account to save your conversations, create custom characters, and unlock premium features.")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                authViewModel.logout()
            } label: {
                Text("Create Account / Sign In")
                    .font(AppFonts.semibold(16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.primaryGradient)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Logged In View

    private func loggedInView(user: User) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                profileHeader(user: user)

                // Subscription Card
                subscriptionCard(user: user)

                // Stats
                statsSection(user: user)

                // Quick Actions
                quickActionsSection

                // Account Info
                accountInfoSection(user: user)

                // Logout Button
                logoutButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
    }

    // MARK: - Profile Header

    private func profileHeader(user: User) -> some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppColors.primaryGradient)
                    .frame(width: 100, height: 100)

                Text(user.initials)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(AppFonts.title)
                    .foregroundColor(.white)

                Text(user.email)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Subscription Card

    private func subscriptionCard(user: User) -> some View {
        Button {
            showSubscription = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: user.subscriptionStatus.icon)
                            .foregroundColor(user.isPremium ? .yellow : AppColors.textMuted)

                        Text(profileViewModel.subscriptionStatusText)
                            .font(AppFonts.medium(16))
                            .foregroundColor(.white)
                    }

                    if !user.isPremium {
                        Text("Upgrade to unlock all features")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                if !user.isPremium {
                    Text("Upgrade")
                        .font(AppFonts.semibold(14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.primaryGradient)
                        .cornerRadius(20)
                }
            }
            .padding(20)
            .background(
                user.isPremium
                    ? LinearGradient(
                        colors: [Color(hex: "#FFD700").opacity(0.2), Color(hex: "#FFA500").opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(colors: [AppColors.cardBackground], startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(user.isPremium ? Color(hex: "#FFD700").opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
    }

    // MARK: - Stats Section

    private func statsSection(user: User) -> some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "bubble.left.fill",
                value: "\(user.messageCount)",
                label: "Messages"
            )

            StatCard(
                icon: "calendar",
                value: daysSinceJoined(user.createdAt),
                label: "Days Active"
            )
        }
    }

    private func daysSinceJoined(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return "\(max(1, days))"
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            ProfileActionRow(
                icon: "clock.arrow.circlepath",
                title: "Chat History",
                subtitle: "View past conversations"
            ) {
                // Navigate to history
            }

            ProfileActionRow(
                icon: "square.and.arrow.up",
                title: "Export Data",
                subtitle: "Download your data"
            ) {
                Task {
                    await profileViewModel.exportData()
                }
            }
        }
    }

    // MARK: - Account Info

    private func accountInfoSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.textMuted)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                AccountInfoRow(label: "Email", value: user.email)
                Divider().background(AppColors.textMuted.opacity(0.2))
                AccountInfoRow(label: "Email Verified", value: user.emailVerified ? "Yes" : "No")
                Divider().background(AppColors.textMuted.opacity(0.2))
                AccountInfoRow(label: "Member Since", value: formatDate(user.createdAt))
            }
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Logout Button

    private var logoutButton: some View {
        Button {
            profileViewModel.showLogoutConfirmation = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
            }
            .font(AppFonts.medium(16))
            .foregroundColor(AppColors.error)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppColors.error.opacity(0.1))
            .cornerRadius(12)
        }
        .confirmationDialog("Sign Out", isPresented: $profileViewModel.showLogoutConfirmation) {
            Button("Sign Out", role: .destructive) {
                profileViewModel.logout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(AppColors.primary)

            Text(value)
                .font(AppFonts.bold(24))
                .foregroundColor(.white)

            Text(label)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Profile Action Row

struct ProfileActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 40, height: 40)
                    .background(AppColors.primary.opacity(0.2))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFonts.medium(16))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textMuted)
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
    }
}

// MARK: - Account Info Row

struct AccountInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppFonts.body)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(ProfileViewModel())
            .environmentObject(AuthViewModel())
            .environmentObject(SubscriptionViewModel())
    }
    .preferredColorScheme(.dark)
}
