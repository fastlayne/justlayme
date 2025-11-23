// ChatView.swift
// JustLayMe iOS - Chat Interface
// Message bubbles with streaming animation, matching web behavior

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss

    let conversation: Conversation

    @State private var messageText = ""
    @State private var showModelPicker = false
    @State private var showMessageActions = false
    @State private var selectedMessage: ChatMessage?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            // Background
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
                // Messages area
                messagesScrollView

                // Input area
                inputArea
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                modelBadge
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showModelPicker = true }) {
                        Label("Change Model", systemImage: "cpu")
                    }

                    Button(action: {
                        Task { await viewModel.regenerateLastMessage() }
                    }) {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }

                    Divider()

                    Button(role: .destructive, action: {
                        viewModel.deleteConversation(conversation)
                        dismiss()
                    }) {
                        Label("Delete Chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet(selectedModel: $viewModel.selectedModel)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showMessageActions) {
            if let message = selectedMessage {
                MessageActionsSheet(message: message)
                    .environmentObject(viewModel)
            }
        }
        .onAppear {
            viewModel.selectConversation(conversation)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Model Badge

    private var modelBadge: some View {
        Button(action: { showModelPicker = true }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(modelGradient)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(viewModel.selectedModel.emoji == "free" ? "V" : viewModel.selectedModel.emoji)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )

                Text(viewModel.selectedModel.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)
        }
    }

    private var modelGradient: LinearGradient {
        let colors = viewModel.selectedModel.gradientColors
        return LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: colors.0),
                Color(hex: colors.1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Messages Scroll View

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.currentConversation?.messages ?? []) { message in
                        MessageBubble(
                            message: message,
                            modelType: viewModel.selectedModel
                        )
                        .id(message.id)
                        .onLongPressGesture {
                            selectedMessage = message
                            showMessageActions = true
                        }
                    }

                    // Scroll anchor
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding()
            }
            .onChange(of: viewModel.currentConversation?.messages.count) { _ in
                if viewModel.settings.autoScroll {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            // Connection status indicator
            if !viewModel.connectionStatus.isConnected {
                ConnectionStatusBanner(status: viewModel.connectionStatus)
            }

            // Input field
            HStack(spacing: 12) {
                // Text field
                HStack {
                    TextField("Type your message...", text: $messageText, axis: .vertical)
                        .foregroundColor(.white)
                        .focused($isInputFocused)
                        .lineLimit(1...5)
                        .onSubmit {
                            sendMessage()
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(24)

                // Send button
                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "667eea"),
                                        Color(hex: "764ba2")
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        if viewModel.isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
                .opacity(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(
                Color(hex: "0a0a0f")
                    .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
            )
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messageText = ""
        isInputFocused = false

        Task {
            await viewModel.sendMessage(text)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let modelType: AIModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                // AI Avatar
                aiAvatar
            }

            // Message content
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Content
                if message.isStreaming && message.content.isEmpty {
                    // Loading dots animation
                    LoadingDotsView()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                } else {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            message.isUser ?
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "667eea"),
                                    Color(hex: "764ba2")
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(20)

                    if message.isStreaming {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Generating...")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }

                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }

    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(modelGradient)
                .frame(width: 32, height: 32)

            Text(modelType.emoji == "free" ? "V" : modelType.emoji)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var modelGradient: LinearGradient {
        let colors = modelType.gradientColors
        return LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: colors.0),
                Color(hex: colors.1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Loading Dots View

struct LoadingDotsView: View {
    @State private var animatingDot = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(animatingDot == index ? 1 : 0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                animatingDot = (animatingDot + 1) % 3
            }
        }
    }
}

// MARK: - Connection Status Banner

struct ConnectionStatusBanner: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)

            Text(status.statusText)
                .font(.caption)
                .foregroundColor(statusColor)

            Spacer()

            if case .connecting = status {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.1))
    }

    private var statusIcon: String {
        switch status {
        case .connected: return "wifi"
        case .connecting: return "wifi.exclamationmark"
        case .disconnected: return "wifi.slash"
        case .error: return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected, .error: return .red
        }
    }
}

// MARK: - Model Picker Sheet

struct ModelPickerSheet: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss
    @Binding var selectedModel: AIModel

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0a0a0f")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(AIModel.allCases) { model in
                            Button(action: {
                                selectedModel = model
                                viewModel.selectModel(model)
                                dismiss()
                            }) {
                                HStack {
                                    ModelSelectionCard(model: model) { }
                                        .disabled(true)

                                    if model == selectedModel {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(hex: "6b46ff"))
                                            .padding(.trailing)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "6b46ff"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Message Actions Sheet

struct MessageActionsSheet: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss
    let message: ChatMessage

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0a0a0f")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Preview
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding()

                    // Actions
                    VStack(spacing: 0) {
                        ActionButton(
                            icon: "doc.on.doc",
                            title: "Copy",
                            color: .white
                        ) {
                            viewModel.copyMessage(message)
                            dismiss()
                        }

                        Divider()
                            .background(Color.white.opacity(0.1))

                        if !message.isUser {
                            ActionButton(
                                icon: "arrow.clockwise",
                                title: "Regenerate",
                                color: .white
                            ) {
                                Task {
                                    await viewModel.regenerateLastMessage()
                                }
                                dismiss()
                            }

                            Divider()
                                .background(Color.white.opacity(0.1))
                        }

                        ActionButton(
                            icon: "trash",
                            title: "Delete",
                            color: .red
                        ) {
                            viewModel.deleteMessage(message)
                            dismiss()
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Message Actions")
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
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .foregroundColor(color)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Preview

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ChatViewModel(persistence: PersistenceController.preview)
        let conversation = Conversation(modelType: .laymeV1, title: "Test Chat")

        NavigationView {
            ChatView(conversation: conversation)
                .environmentObject(viewModel)
        }
    }
}
