import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                // Profile Header
                Section {
                    ProfileHeaderView(
                        user: viewModel.user ?? authViewModel.currentUser,
                        isPremium: viewModel.isPremium
                    )
                }

                // Account Info
                Section("Account") {
                    if let user = viewModel.user ?? authViewModel.currentUser {
                        LabeledContent("Email", value: user.email)

                        LabeledContent("Status", value: viewModel.subscriptionStatusText)
                            .foregroundColor(viewModel.isPremium ? .green : .secondary)

                        LabeledContent("Member Since", value: viewModel.memberSinceText)
                    }
                }

                // Edit Profile
                Section("Profile") {
                    TextField("Display Name", text: $viewModel.name)

                    Picker("Avatar Style", selection: $viewModel.avatarStyle) {
                        Text("Default").tag("default")
                        Text("Minimalist").tag("minimalist")
                        Text("Colorful").tag("colorful")
                    }

                    Button {
                        Task {
                            await viewModel.updateProfile()
                        }
                    } label: {
                        HStack {
                            Text("Save Changes")
                            if viewModel.isSaving {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }

                // Subscription
                if !viewModel.isPremium {
                    Section {
                        NavigationLink {
                            PaywallView()
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("Upgrade to Premium")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }

                // Data Management
                Section("Data") {
                    Button {
                        Task {
                            await viewModel.exportData()
                        }
                    } label: {
                        HStack {
                            Label("Export My Data", systemImage: "square.and.arrow.up")
                            if viewModel.isExporting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isExporting)

                    Button(role: .destructive) {
                        viewModel.showClearDataConfirmation = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                }

                // Logout
                Section {
                    Button(role: .destructive) {
                        authViewModel.logout()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .refreshable {
                await viewModel.loadProfile()
            }
            .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
                Button("OK") {
                    viewModel.successMessage = nil
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .confirmationDialog(
                "Clear All Data",
                isPresented: $viewModel.showClearDataConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Data", role: .destructive) {
                    Task {
                        await viewModel.clearAllData()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your conversations. This action cannot be undone.")
            }
            .sheet(isPresented: $viewModel.showExportSheet) {
                ExportDataSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.loadProfile()
            }
        }
    }
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    let user: User?
    let isPremium: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.purple.gradient)
                    .frame(width: 70, height: 70)

                Text((user?.name ?? user?.email ?? "U").prefix(1).uppercased())
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(user?.name ?? "User")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(user?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if isPremium {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text("Premium")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.yellow)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Export Data Sheet
struct ExportDataSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let json = viewModel.getExportJSON() {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your exported data:")
                            .font(.headline)

                        Text(json)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)

                        ShareLink(
                            item: json,
                            subject: Text("JustLayMe Data Export"),
                            message: Text("My exported data from JustLayMe")
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                } else {
                    Text("No data to export")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
