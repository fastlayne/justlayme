import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    @State private var showCharacterPicker = false
    @State private var showModelPicker = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            AppColors.darkBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Character Selector
                characterSelector

                // Messages
                messagesView

                // Input
                inputView
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    chatViewModel.startNewConversation()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(AppColors.primary)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showModelPicker = true
                    } label: {
                        Label("Change Model", systemImage: "cpu")
                    }

                    Button(role: .destructive) {
                        chatViewModel.clearChat()
                    } label: {
                        Label("Clear Chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .sheet(isPresented: $showCharacterPicker) {
            CharacterPickerSheet(selectedCharacter: $chatViewModel.selectedCharacter)
        }
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet(selectedModel: $chatViewModel.selectedModel)
        }
        .sheet(isPresented: $chatViewModel.showPaywall) {
            SubscriptionView()
                .environmentObject(subscriptionViewModel)
        }
        .task {
            await chatViewModel.loadCharacters()
        }
    }

    // MARK: - Character Selector

    private var characterSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(chatViewModel.characters) { character in
                    CharacterChip(
                        character: character,
                        isSelected: chatViewModel.selectedCharacter?.id == character.id
                    ) {
                        chatViewModel.selectCharacter(character)
                    }
                }

                // Add Character Button
                Button {
                    showCharacterPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("More")
                    }
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColors.cardBackground)
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppColors.cardBackground.opacity(0.5))
    }

    // MARK: - Messages View

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if chatViewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(chatViewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .onChange(of: chatViewModel.messages.count) { _, _ in
                if let lastMessage = chatViewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textMuted.opacity(0.5))

            Text("Start a conversation")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.textSecondary)

            Text("Say hi to \(chatViewModel.characterName)!")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textMuted)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Input View

    private var inputView: some View {
        VStack(spacing: 8) {
            // Free messages remaining indicator
            if chatViewModel.isPremiumModel && chatViewModel.freeMessagesRemaining > 0 {
                Text("\(chatViewModel.freeMessagesRemaining) free messages remaining")
                    .font(AppFonts.small)
                    .foregroundColor(AppColors.warning)
            }

            HStack(spacing: 12) {
                // Text Input
                HStack(spacing: 8) {
                    TextField(
                        "",
                        text: $chatViewModel.inputText,
                        prompt: Text(chatViewModel.inputPlaceholder)
                            .foregroundColor(AppColors.textMuted),
                        axis: .vertical
                    )
                    .font(AppFonts.body)
                    .foregroundColor(.white)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColors.inputBackground)
                .cornerRadius(24)

                // Send Button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            chatViewModel.canSendMessage
                                ? AppColors.primaryGradient
                                : LinearGradient(colors: [AppColors.textMuted], startPoint: .top, endPoint: .bottom)
                        )
                }
                .disabled(!chatViewModel.canSendMessage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.cardBackground)
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        guard chatViewModel.canSendMessage else { return }
        isInputFocused = false

        Task {
            await chatViewModel.sendMessage()
        }
    }
}

// MARK: - Character Chip

struct CharacterChip: View {
    let character: Character
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: character.displayAvatar)
                    .font(.system(size: 16))

                Text(character.name)
                    .font(AppFonts.caption)

                if character.id == 1 {
                    Text("FREE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(AppColors.success)
                        .cornerRadius(4)
                }
            }
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? AppColors.primary
                    : AppColors.cardBackground
            )
            .cornerRadius(20)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 60)
            }

            if message.isLoading {
                loadingBubble
            } else {
                messageBubble
            }

            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
    }

    private var messageBubble: some View {
        VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
            if !message.isFromUser, let characterName = message.characterName {
                Text(characterName)
                    .font(AppFonts.small)
                    .foregroundColor(AppColors.textMuted)
            }

            Text(message.content)
                .font(AppFonts.body)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    message.isFromUser
                        ? AppColors.userMessageBackground
                        : AppColors.aiMessageBackground
                )
                .cornerRadius(20, corners: message.isFromUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])

            Text(message.timestamp, style: .time)
                .font(AppFonts.small)
                .foregroundColor(AppColors.textMuted)
        }
    }

    private var loadingBubble: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppColors.textMuted)
                    .frame(width: 8, height: 8)
                    .offset(y: loadingOffset(for: index))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.aiMessageBackground)
        .cornerRadius(20, corners: [.topLeft, .topRight, .bottomRight])
        .animation(.easeInOut(duration: 0.5).repeatForever(), value: UUID())
    }

    private func loadingOffset(for index: Int) -> CGFloat {
        let phase = Double(index) * 0.2
        return sin(Date().timeIntervalSinceReferenceDate * 5 + phase * .pi * 2) * 4
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatView()
            .environmentObject(ChatViewModel())
            .environmentObject(SubscriptionViewModel())
    }
    .preferredColorScheme(.dark)
}
