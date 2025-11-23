import SwiftUI

struct ConversationHistoryView: View {
    @StateObject private var viewModel = ConversationViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.conversations.isEmpty {
                ProgressView("Loading conversations...")
            } else if viewModel.conversations.isEmpty {
                EmptyConversationsView()
            } else {
                List {
                    ForEach(viewModel.displayedConversations) { conversation in
                        ConversationRow(conversation: conversation)
                            .onTapGesture {
                                Task {
                                    await viewModel.loadMessages(for: conversation)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteConversation(conversation)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    Task {
                                        await viewModel.archiveConversation(conversation)
                                    }
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
                            .onAppear {
                                // Load more when reaching end
                                if conversation == viewModel.conversations.last {
                                    Task {
                                        await viewModel.loadMore()
                                    }
                                }
                            }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.loadConversations(refresh: true)
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchQuery, prompt: "Search conversations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isSearching {
                    ProgressView()
                }
            }
        }
        .sheet(item: $viewModel.selectedConversation) { conversation in
            ConversationDetailView(
                conversation: conversation,
                messages: viewModel.messages,
                isLoading: viewModel.isLoadingMessages
            )
        }
        .task {
            await viewModel.loadConversations()
        }
    }
}

// MARK: - Conversation Row
struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(conversation.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(conversation.lastActivityFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Label(conversation.modelType, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(conversation.messageCount) messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let tags = conversation.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.1))
                                .foregroundColor(.purple)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Conversation Detail View
struct ConversationDetailView: View {
    let conversation: Conversation
    let messages: [Message]
    let isLoading: Bool

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading messages...")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(conversation.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: messagesAsText(),
                        subject: Text(conversation.displayTitle),
                        message: Text("Conversation from JustLayMe")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private func messagesAsText() -> String {
        messages.map { message in
            let sender = message.isUser ? "You" : "AI"
            return "[\(sender)]: \(message.content)"
        }.joined(separator: "\n\n")
    }
}

// MARK: - Empty State
struct EmptyConversationsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("No Conversations Yet")
                .font(.title2)
                .fontWeight(.medium)

            Text("Start chatting to see your conversation history here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// Make Conversation identifiable for sheet
extension Conversation: Identifiable {}

#Preview {
    NavigationStack {
        ConversationHistoryView()
    }
}
