import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // Profile Section
                Section {
                    TextField("Display Name", text: $viewModel.name)

                    HStack {
                        Text("Email")
                        Spacer()
                        Text(viewModel.email)
                            .foregroundColor(.secondary)
                    }

                    Picker("Avatar Style", selection: $viewModel.avatarStyle) {
                        Text("Initials").tag("initials")
                        Text("Gradient").tag("gradient")
                        Text("Emoji").tag("emoji")
                    }

                    Picker("Theme", selection: $viewModel.themePreference) {
                        ForEach(ThemePreference.allCases, id: \.self) { preference in
                            Text(preference.displayName).tag(preference)
                        }
                    }
                }

                // Account Status Section
                Section("Account Status") {
                    HStack {
                        Text("Status")
                        Spacer()
                        SubscriptionBadge(isPremium: viewModel.isPremium)
                    }

                    if let endDate = viewModel.subscriptionEndFormatted {
                        HStack {
                            Text("Expires")
                            Spacer()
                            Text(endDate)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveProfile()
                            if viewModel.error == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }
}

struct SubscriptionBadge: View {
    let isPremium: Bool

    var body: some View {
        Text(isPremium ? "Premium" : "Free")
            .font(.caption.weight(.semibold))
            .foregroundColor(isPremium ? .black : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                isPremium ?
                AnyView(Color.goldGradient) :
                AnyView(Color.appPrimary)
            )
            .cornerRadius(8)
    }
}

#Preview {
    ProfileView()
}
