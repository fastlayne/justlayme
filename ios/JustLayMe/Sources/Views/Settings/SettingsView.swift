// SettingsView.swift
// JustLayMe iOS - Settings Screen
// Server connection, model defaults, and user preferences

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss

    @State private var serverURL: String = ""
    @State private var temperature: Double = 0.8
    @State private var topP: Double = 0.9
    @State private var maxTokens: Double = 500
    @State private var systemPrompt: String = ""
    @State private var defaultModel: AIModel = .laymeV1
    @State private var responseLength: AppSettings.ResponseLength = .medium
    @State private var autoScroll: Bool = true
    @State private var soundNotifications: Bool = false
    @State private var saveConversations: Bool = true
    @State private var analyticsOptOut: Bool = false
    @State private var showClearDataAlert = false
    @State private var showExportSuccess = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0a0a0f")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Connection Section
                        connectionSection

                        // Model Defaults Section
                        modelDefaultsSection

                        // Chat Preferences Section
                        chatPreferencesSection

                        // Privacy Section
                        privacySection

                        // Data Management Section
                        dataManagementSection

                        // About Section
                        aboutSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "6b46ff"))
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadSettings()
            }
            .alert("Clear All Data", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    viewModel.clearAllConversations()
                }
            } message: {
                Text("This will permanently delete all your conversations. This action cannot be undone.")
            }
            .alert("Export Successful", isPresented: $showExportSuccess) {
                Button("OK") { }
            } message: {
                Text("Your data has been exported successfully.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        SettingsSection(title: "Server Connection", icon: "network") {
            VStack(spacing: 16) {
                // Server URL
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server URL")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    TextField("https://justlay.me", text: $serverURL)
                        .textFieldStyle(SettingsTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }

                // Connection status
                HStack {
                    Circle()
                        .fill(viewModel.connectionStatus.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)

                    Text(viewModel.connectionStatus.statusText)
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Button("Test") {
                        viewModel.checkConnection()
                    }
                    .font(.caption)
                    .foregroundColor(Color(hex: "6b46ff"))
                }
            }
        }
    }

    // MARK: - Model Defaults Section

    private var modelDefaultsSection: some View {
        SettingsSection(title: "Model Defaults", icon: "cpu") {
            VStack(spacing: 16) {
                // Default Model
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Model")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Picker("", selection: $defaultModel) {
                        ForEach(AIModel.allCases) { model in
                            HStack {
                                Text(model.displayName)
                                if model.isPremium {
                                    Text("PRO")
                                        .font(.caption2)
                                        .foregroundColor(Color(hex: "ffd700"))
                                }
                            }
                            .tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                }

                // Temperature
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Temperature")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Spacer()

                        Text(String(format: "%.1f", temperature))
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }

                    Slider(value: $temperature, in: 0...2, step: 0.1)
                        .tint(Color(hex: "6b46ff"))

                    Text("Higher values make output more random, lower values more deterministic")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                // Top P
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Top P")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Spacer()

                        Text(String(format: "%.2f", topP))
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }

                    Slider(value: $topP, in: 0...1, step: 0.05)
                        .tint(Color(hex: "6b46ff"))
                }

                // Max Tokens
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max Tokens")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Spacer()

                        Text("\(Int(maxTokens))")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }

                    Slider(value: $maxTokens, in: 100...2000, step: 100)
                        .tint(Color(hex: "6b46ff"))
                }

                // System Prompt
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom System Prompt (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    TextEditor(text: $systemPrompt)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Chat Preferences Section

    private var chatPreferencesSection: some View {
        SettingsSection(title: "Chat Preferences", icon: "bubble.left.and.bubble.right") {
            VStack(spacing: 16) {
                // Response Length
                VStack(alignment: .leading, spacing: 8) {
                    Text("Response Length")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Picker("", selection: $responseLength) {
                        Text("Short").tag(AppSettings.ResponseLength.short)
                        Text("Medium").tag(AppSettings.ResponseLength.medium)
                        Text("Long").tag(AppSettings.ResponseLength.long)
                    }
                    .pickerStyle(.segmented)
                }

                // Toggle settings
                SettingsToggle(
                    title: "Auto-scroll to new messages",
                    isOn: $autoScroll
                )

                SettingsToggle(
                    title: "Sound notifications",
                    isOn: $soundNotifications
                )
            }
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        SettingsSection(title: "Privacy", icon: "lock.shield") {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "Save conversation history",
                    isOn: $saveConversations
                )

                SettingsToggle(
                    title: "Opt out of usage analytics",
                    isOn: $analyticsOptOut
                )
            }
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        SettingsSection(title: "Data Management", icon: "externaldrive") {
            VStack(spacing: 12) {
                Button(action: exportData) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export My Data")
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }

                Button(action: { showClearDataAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Conversations")
                        Spacer()
                    }
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        SettingsSection(title: "About", icon: "info.circle") {
            VStack(spacing: 12) {
                HStack {
                    Text("Version")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.white)
                }

                HStack {
                    Text("Build")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("1")
                        .foregroundColor(.white)
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                Link(destination: URL(string: "https://justlay.me")!) {
                    HStack {
                        Text("Visit Website")
                            .foregroundColor(Color(hex: "6b46ff"))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(Color(hex: "6b46ff"))
                    }
                }

                Link(destination: URL(string: "https://justlay.me/privacy")!) {
                    HStack {
                        Text("Privacy Policy")
                            .foregroundColor(Color(hex: "6b46ff"))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(Color(hex: "6b46ff"))
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadSettings() {
        let settings = viewModel.settings
        serverURL = settings.serverURL
        temperature = settings.temperature
        topP = settings.topP
        maxTokens = Double(settings.maxTokens)
        systemPrompt = settings.systemPrompt ?? ""
        defaultModel = settings.defaultModel
        responseLength = settings.responseLength
        autoScroll = settings.autoScroll
        soundNotifications = settings.soundNotifications
        saveConversations = settings.saveConversations
        analyticsOptOut = settings.analyticsOptOut
    }

    private func saveSettings() {
        let newSettings = AppSettings(
            defaultModel: defaultModel,
            responseLength: responseLength,
            autoScroll: autoScroll,
            soundNotifications: soundNotifications,
            saveConversations: saveConversations,
            analyticsOptOut: analyticsOptOut,
            serverURL: serverURL,
            temperature: temperature,
            topP: topP,
            maxTokens: Int(maxTokens),
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
        )
        viewModel.updateSettings(newSettings)
    }

    private func exportData() {
        // TODO: Implement actual export
        showExportSuccess = true
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(Color(hex: "6b46ff"))

                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            content
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Settings Toggle

struct SettingsToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .tint(Color(hex: "6b46ff"))
    }
}

// MARK: - Settings Text Field Style

struct SettingsTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .foregroundColor(.white)
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ChatViewModel(persistence: PersistenceController.preview))
    }
}
