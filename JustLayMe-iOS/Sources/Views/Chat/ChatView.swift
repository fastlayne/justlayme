import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator

    @FocusState private var isInputFocused: Bool
    @State private var showCharacterPicker = false

    var body: some View {
        NavigationStack(path: $navigationCoordinator.chatPath) {
            VStack(spacing: 0) {
                // Character Header
                CharacterHeaderView(
                    characterName: viewModel.currentCharacterName,
                    characterIcon: viewModel.selectedCharacter.icon,
                    isFree: viewModel.isFreeTier,
                    onTap: { showCharacterPicker = true }
                )

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            // Premium limit warning
                            if !viewModel.isFreeTier && viewModel.remainingFreeMessages > 0 && viewModel.remainingFreeMessages <= 3 {
                                FreeLimitWarning(remaining: viewModel.remainingFreeMessages)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input Bar
                ChatInputBar(
                    text: $viewModel.inputText,
                    isTyping: viewModel.isTyping,
                    canSend: viewModel.canSendMessage,
                    isFocused: $isInputFocused
                ) {
                    Task {
                        await viewModel.sendMessage(
                            userId: authViewModel.currentUser?.id,
                            isPremium: authViewModel.isPremium
                        )
                    }
                }
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            navigationCoordinator.navigateToConversationHistory()
                        } label: {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }

                        Button {
                            viewModel.clearChat()
                        } label: {
                            Label("Clear Chat", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showCharacterPicker) {
                CharacterPickerSheet(
                    selectedCharacter: viewModel.selectedCharacter,
                    onSelect: { character in
                        viewModel.selectCharacter(character, isPremium: authViewModel.isPremium)
                        showCharacterPicker = false
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $viewModel.showPaywall) {
                PaywallView()
            }
            .navigationDestination(for: ChatDestination.self) { destination in
                switch destination {
                case .conversation:
                    EmptyView()
                case .history:
                    ConversationHistoryView()
                case .search:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Character Header
struct CharacterHeaderView: View {
    let characterName: String
    let characterIcon: String
    let isFree: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: characterIcon)
                    .font(.title2)
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(characterName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(isFree ? "FREE & Unlimited" : "Premium")
                        .font(.caption)
                        .foregroundColor(isFree ? .green : .orange)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if message.isLoading {
                    TypingIndicator()
                } else {
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(message.isUser ? Color.purple : Color(.secondarySystemBackground))
                        .foregroundColor(message.isUser ? .white : .primary)
                        .cornerRadius(20)
                }

                if let createdAt = message.createdAt {
                    Text(createdAt, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if message.isAI { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animationOffset = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset == index ? -5 : 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever()) {
                animationOffset = (animationOffset + 1) % 3
            }
        }
    }
}

// MARK: - Chat Input Bar
struct ChatInputBar: View {
    @Binding var text: String
    let isTyping: Bool
    let canSend: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(24)
                .lineLimit(1...5)
                .focused(isFocused)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend ? .purple : .gray)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Free Limit Warning
struct FreeLimitWarning: View {
    let remaining: Int

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text("\(remaining) free message\(remaining == 1 ? "" : "s") remaining")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Character Picker Sheet
struct CharacterPickerSheet: View {
    let selectedCharacter: PredefinedCharacter
    let onSelect: (PredefinedCharacter) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(PredefinedCharacter.allCases) { character in
                    Button {
                        onSelect(character)
                    } label: {
                        HStack {
                            Image(systemName: character.icon)
                                .font(.title2)
                                .foregroundColor(.purple)
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(character.displayName)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    if character.isFree {
                                        Text("FREE")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green)
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                    }
                                }

                                Text(character.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if character == selectedCharacter {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Character")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(AuthViewModel())
        .environmentObject(NavigationCoordinator())
}
