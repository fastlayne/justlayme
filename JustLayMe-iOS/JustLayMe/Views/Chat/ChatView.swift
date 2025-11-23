import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                character: viewModel.selectedCharacter
                            )
                            .id(message.id)
                        }

                        if viewModel.isLoading {
                            TypingIndicator(character: viewModel.selectedCharacter)
                                .id("typing")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        if let lastMessage = viewModel.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isLoading) { _, isLoading in
                    if isLoading {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }

            // Input Area
            ChatInputBar(
                text: $viewModel.inputText,
                isLoading: viewModel.isLoading,
                isFocused: $isInputFocused
            ) {
                Task {
                    await viewModel.sendMessage()
                }
            }
        }
        .background(Color.appDarkBg)
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView()
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let character: AICharacter

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !message.isUser {
                CharacterAvatar(character: character, size: 36)
            } else {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.isUser ?
                        AnyView(Color.appPrimary) :
                        AnyView(Color.appCardBg)
                    )
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(message.isUser ? Color.clear : Color.appBorder, lineWidth: 1)
                    )
            }

            if message.isUser {
                // User avatar placeholder
                Circle()
                    .fill(Color.appPrimary)
                    .frame(width: 36, height: 36)
            } else {
                Spacer(minLength: 60)
            }
        }
    }
}

struct TypingIndicator: View {
    let character: AICharacter
    @State private var animationPhase = 0

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CharacterAvatar(character: character, size: 36)

            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                            value: animationPhase
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appCardBg)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.appBorder, lineWidth: 1)
            )

            Spacer()
        }
        .onAppear {
            animationPhase = 1
        }
    }
}

struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Type your message...", text: $text)
                .font(.body)
                .foregroundColor(.appTextPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.appCardBg)
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
                .focused(isFocused)
                .onSubmit {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        isLoading || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                        AnyView(Color.gray) :
                        AnyView(Color.premiumGradient)
                    )
                    .cornerRadius(22)
            }
            .disabled(isLoading || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.appCardBg.opacity(0.9)
                .background(.ultraThinMaterial)
        )
    }
}

#Preview {
    ChatView(viewModel: ChatViewModel())
}
