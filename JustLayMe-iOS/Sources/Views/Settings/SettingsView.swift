import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                // Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $viewModel.settings.themePreference) {
                        ForEach(ThemePreference.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }

                    Picker("Default Character", selection: $viewModel.settings.defaultCharacter) {
                        ForEach(PredefinedCharacter.allCases) { character in
                            Text(character.displayName).tag(character.rawValue)
                        }
                    }
                }

                // Chat Settings
                Section("Chat") {
                    Picker("Response Length", selection: $viewModel.settings.responseLength) {
                        ForEach(ResponseLength.allCases, id: \.self) { length in
                            Text(length.displayName).tag(length)
                        }
                    }

                    Toggle("Auto-scroll to new messages", isOn: $viewModel.settings.autoScroll)

                    Toggle("Sound Notifications", isOn: $viewModel.settings.soundNotifications)

                    Toggle("Save Conversations", isOn: $viewModel.settings.saveConversations)
                }

                // Privacy
                Section("Privacy") {
                    Toggle("Opt out of Analytics", isOn: $viewModel.settings.analyticsOptOut)

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Text("Privacy Policy")
                    }

                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        Text("Terms of Service")
                    }
                }

                // Reset
                Section {
                    Button("Reset to Defaults") {
                        viewModel.showResetConfirmation = true
                    }
                    .foregroundColor(.orange)
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: viewModel.versionString)

                    Link(destination: URL(string: "https://justlay.me")!) {
                        HStack {
                            Text("Website")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }

                    Link(destination: URL(string: "mailto:support@justlay.me")!) {
                        HStack {
                            Text("Contact Support")
                            Spacer()
                            Image(systemName: "envelope")
                                .font(.caption)
                        }
                    }
                }

                // Logout (if guest or authenticated)
                if authViewModel.authState == .guest {
                    Section {
                        NavigationLink {
                            AuthView()
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Create Account")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset Settings",
                isPresented: $viewModel.showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset to Defaults", role: .destructive) {
                    viewModel.resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all settings to their default values.")
            }
            .preferredColorScheme(viewModel.settings.themePreference.colorScheme)
        }
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Last updated: June 2025")
                    .foregroundColor(.secondary)

                Group {
                    Text("Information We Collect")
                        .font(.headline)
                    Text("We collect information you provide directly, including your email address, chat messages, and any custom characters you create.")

                    Text("How We Use Your Information")
                        .font(.headline)
                    Text("We use your information to provide and improve our services, process payments, and communicate with you about your account.")

                    Text("Data Storage")
                        .font(.headline)
                    Text("Your data is stored securely and is not shared with third parties except as necessary to provide our services.")

                    Text("Your Rights")
                        .font(.headline)
                    Text("You can export or delete your data at any time through the Profile section of the app.")
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Service")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Last updated: June 2025")
                    .foregroundColor(.secondary)

                Group {
                    Text("Acceptance of Terms")
                        .font(.headline)
                    Text("By using JustLayMe, you agree to these terms of service.")

                    Text("Use of Service")
                        .font(.headline)
                    Text("You must be at least 18 years old to use this service. You are responsible for all activity under your account.")

                    Text("Prohibited Content")
                        .font(.headline)
                    Text("You may not use the service to generate illegal content, harass others, or violate any applicable laws.")

                    Text("Payments")
                        .font(.headline)
                    Text("Premium subscriptions are billed according to the plan you select. Refunds are handled on a case-by-case basis.")

                    Text("Termination")
                        .font(.headline)
                    Text("We reserve the right to terminate accounts that violate these terms.")
                }
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
