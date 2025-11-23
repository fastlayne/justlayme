// ConversationListView.swift
// JustLayMe iOS - Chat List Screen
// Displays all conversations with search and filter

import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var showingNewChat = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var showDeleteAlert = false
    @State private var conversationToDelete: Conversation?

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient matching web
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "0a0a0f"),
                        Color(hex: "1a1a2e")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar

                    // Model filter pills
                    modelFilterPills

                    // Conversation list
                    if viewModel.filteredConversations.isEmpty {
                        emptyStateView
                    } else {
                        conversationList
                    }
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewChat = true }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(Color(hex: "6b46ff"))
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewChat) {
            NewChatView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(viewModel)
        }
        .alert("Delete Conversation", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let conversation = conversationToDelete {
                    viewModel.deleteConversation(conversation)
                }
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This cannot be undone.")
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search conversations...", text: $searchText)
                .foregroundColor(.white)
                .onChange(of: searchText) { newValue in
                    viewModel.searchQuery = newValue
                }

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Model Filter Pills

    private var modelFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(title: "All", isSelected: true) {
                    // Show all
                }

                ForEach(AIModel.allCases) { model in
                    FilterPill(
                        title: model.displayName,
                        isSelected: false,
                        isPremium: model.isPremium
                    ) {
                        // Filter by model
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        List {
            ForEach(viewModel.filteredConversations) { conversation in
                NavigationLink(destination: ChatView(conversation: conversation)
                    .environmentObject(viewModel)) {
                    ConversationRow(conversation: conversation)
                }
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        conversationToDelete = conversation
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        // Archive
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tint(.orange)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "6b46ff").opacity(0.5))

            Text("No Conversations Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Start a new chat to begin talking with AI companions")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showingNewChat = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("New Chat")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "667eea"),
                            Color(hex: "764ba2")
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
            }
            .padding(.top, 10)

            Spacer()
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            // Model avatar
            modelAvatar

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(formatDate(conversation.updatedAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.content)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }

                // Model badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(modelGradient)
                        .frame(width: 8, height: 8)

                    Text(conversation.modelType.displayName)
                        .font(.caption2)
                        .foregroundColor(.gray)

                    if conversation.modelType.isPremium {
                        Text("PRO")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: "ffd700"))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(hex: "ffd700").opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var modelAvatar: some View {
        ZStack {
            Circle()
                .fill(modelGradient)
                .frame(width: 50, height: 50)

            Text(conversation.modelType.emoji == "free" ? "V1" : conversation.modelType.emoji)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var modelGradient: LinearGradient {
        let colors = conversation.modelType.gradientColors
        return LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: colors.0),
                Color(hex: colors.1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    var isPremium: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)

                if isPremium {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: "ffd700"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ?
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "667eea"),
                        Color(hex: "764ba2")
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                ) :
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - New Chat View

struct NewChatView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0a0a0f")
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Choose an AI Model")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 20)

                    Text("Select a model to start chatting")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(AIModel.allCases) { model in
                                ModelSelectionCard(model: model) {
                                    viewModel.selectModel(model)
                                    dismiss()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Model Selection Card

struct ModelSelectionCard: View {
    let model: AIModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(modelGradient)
                        .frame(width: 50, height: 50)

                    Text(model.emoji == "free" ? "V1" : model.emoji)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.displayName)
                            .font(.headline)
                            .foregroundColor(.white)

                        if !model.isPremium {
                            Text("FREE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "10b981"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "10b981").opacity(0.2))
                                .cornerRadius(4)
                        } else {
                            Text("3 FREE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "ffd700"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "ffd700").opacity(0.2))
                                .cornerRadius(4)
                        }
                    }

                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
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

    private var modelGradient: LinearGradient {
        let colors = model.gradientColors
        return LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: colors.0),
                Color(hex: colors.1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

struct ConversationListView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationListView()
            .environmentObject(ChatViewModel(
                persistence: PersistenceController.preview
            ))
    }
}
