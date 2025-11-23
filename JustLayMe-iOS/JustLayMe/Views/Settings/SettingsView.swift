import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // Chat Preferences
                Section("Chat Preferences") {
                    Picker("Default Character", selection: $viewModel.defaultCharacter) {
                        ForEach(viewModel.characterOptions, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }

                    Picker("Response Length", selection: $viewModel.responseLength) {
                        ForEach(viewModel.responseLengthOptions, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }

                    Toggle("Auto-scroll to new messages", isOn: $viewModel.autoScroll)
                    Toggle("Sound notifications", isOn: $viewModel.soundNotifications)
                }

                // Privacy
                Section("Privacy") {
                    Toggle("Save conversation history", isOn: $viewModel.saveConversations)
                    Toggle("Opt out of usage analytics", isOn: $viewModel.analyticsOptOut)
                }

                // Data Management
                Section("Data Management") {
                    Button(action: {
                        Task { await viewModel.exportData() }
                    }) {
                        Label("Export My Data", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.isLoading)

                    Button(role: .destructive, action: {
                        viewModel.showClearConfirmation = true
                    }) {
                        Label("Clear All Conversations", systemImage: "trash")
                    }
                    .disabled(viewModel.isLoading)
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link("Terms of Service", destination: URL(string: "https://justlay.me/terms")!)
                    Link("Privacy Policy", destination: URL(string: "https://justlay.me/privacy")!)
                    Link("Contact Support", destination: URL(string: "mailto:support@justlay.me")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveSettings()
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Clear All Data",
                isPresented: $viewModel.showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    Task { await viewModel.clearAllData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your conversations. This action cannot be undone.")
            }
            .alert("Export Complete", isPresented: $viewModel.showExportSuccess) {
                Button("OK") {}
            } message: {
                Text("Your data has been exported to the Files app.")
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }
}

#Preview {
    SettingsView()
}
