import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Appearance
                        settingsSection(title: "Appearance") {
                            SettingsToggleRow(
                                icon: "moon.fill",
                                title: "Dark Mode",
                                isOn: $profileViewModel.darkModeEnabled
                            )
                        }

                        // Notifications
                        settingsSection(title: "Notifications") {
                            SettingsToggleRow(
                                icon: "bell.fill",
                                title: "Push Notifications",
                                isOn: $profileViewModel.notificationsEnabled
                            )
                        }

                        // Haptics
                        settingsSection(title: "Feedback") {
                            SettingsToggleRow(
                                icon: "hand.tap.fill",
                                title: "Haptic Feedback",
                                isOn: $profileViewModel.hapticFeedbackEnabled
                            )
                        }

                        // Data Management
                        settingsSection(title: "Data & Privacy") {
                            SettingsButtonRow(
                                icon: "square.and.arrow.up",
                                title: "Export My Data",
                                iconColor: AppColors.info
                            ) {
                                Task {
                                    await profileViewModel.exportData()
                                }
                            }

                            Divider().background(AppColors.textMuted.opacity(0.2))

                            SettingsButtonRow(
                                icon: "trash.fill",
                                title: "Clear All Data",
                                iconColor: AppColors.error
                            ) {
                                profileViewModel.showClearDataConfirmation = true
                            }
                        }

                        // About
                        settingsSection(title: "About") {
                            SettingsInfoRow(
                                icon: "info.circle.fill",
                                title: "Version",
                                value: Bundle.main.appVersion
                            )

                            Divider().background(AppColors.textMuted.opacity(0.2))

                            SettingsLinkRow(
                                icon: "doc.text.fill",
                                title: "Terms of Service"
                            ) {
                                // Open terms
                            }

                            Divider().background(AppColors.textMuted.opacity(0.2))

                            SettingsLinkRow(
                                icon: "hand.raised.fill",
                                title: "Privacy Policy"
                            ) {
                                // Open privacy
                            }

                            Divider().background(AppColors.textMuted.opacity(0.2))

                            SettingsLinkRow(
                                icon: "envelope.fill",
                                title: "Contact Support"
                            ) {
                                // Open support
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .confirmationDialog("Clear All Data", isPresented: $profileViewModel.showClearDataConfirmation) {
                Button("Clear All Data", role: .destructive) {
                    Task {
                        await profileViewModel.clearAllData()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your conversations and characters. This action cannot be undone.")
            }
            .alert("Success", isPresented: .constant(profileViewModel.successMessage != nil)) {
                Button("OK") {
                    profileViewModel.successMessage = nil
                }
            } message: {
                Text(profileViewModel.successMessage ?? "")
            }
        }
    }

    // MARK: - Section Builder

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.textMuted)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content()
            }
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 28)

                Text(title)
                    .font(AppFonts.body)
                    .foregroundColor(.white)
            }
        }
        .tint(AppColors.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Settings Button Row

struct SettingsButtonRow: View {
    let icon: String
    let title: String
    var iconColor: Color = AppColors.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 28)

                Text(title)
                    .font(AppFonts.body)
                    .foregroundColor(iconColor == AppColors.error ? iconColor : .white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Settings Info Row

struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(AppColors.primary)
                .frame(width: 28)

            Text(title)
                .font(AppFonts.body)
                .foregroundColor(.white)

            Spacer()

            Text(value)
                .font(AppFonts.body)
                .foregroundColor(AppColors.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Settings Link Row

struct SettingsLinkRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 28)

                Text(title)
                    .font(AppFonts.body)
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(ProfileViewModel())
}
