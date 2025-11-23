import Foundation
import Combine

// MARK: - Conversation History ViewModel
@MainActor
final class ConversationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var conversations: [Conversation] = []
    @Published var selectedConversation: Conversation?
    @Published var messages: [Message] = []
    @Published var searchQuery = ""
    @Published var searchResults: [Conversation] = []

    @Published var isLoading = false
    @Published var isLoadingMessages = false
    @Published var isSearching = false
    @Published var errorMessage: String?

    // Pagination
    @Published var currentPage = 1
    @Published var hasMorePages = true
    private let pageSize = 20

    // MARK: - Services
    private let conversationService = ConversationService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var displayedConversations: [Conversation] {
        searchQuery.isEmpty ? conversations : searchResults
    }

    var hasConversations: Bool {
        !conversations.isEmpty
    }

    // MARK: - Initialization
    init() {
        setupSearchDebounce()
    }

    // MARK: - Load Conversations
    func loadConversations(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMorePages = true
        }

        guard hasMorePages else { return }
        isLoading = true

        do {
            let newConversations = try await conversationService.getConversations(
                page: currentPage,
                limit: pageSize
            )

            if refresh {
                conversations = newConversations
            } else {
                conversations.append(contentsOf: newConversations)
            }

            hasMorePages = newConversations.count == pageSize
            currentPage += 1
        } catch {
            errorMessage = "Failed to load conversations"
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading && hasMorePages else { return }
        await loadConversations()
    }

    // MARK: - Load Messages
    func loadMessages(for conversation: Conversation) async {
        selectedConversation = conversation
        isLoadingMessages = true
        messages = []

        do {
            messages = try await conversationService.getMessages(conversationId: conversation.id)
        } catch {
            errorMessage = "Failed to load messages"
        }

        isLoadingMessages = false
    }

    // MARK: - Search
    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                Task {
                    await self.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        do {
            searchResults = try await conversationService.searchConversations(query: query)
        } catch {
            errorMessage = "Search failed"
        }

        isSearching = false
    }

    // MARK: - Archive/Delete
    func archiveConversation(_ conversation: Conversation) async {
        do {
            try await conversationService.archiveConversation(id: conversation.id)
            conversations.removeAll { $0.id == conversation.id }
        } catch {
            errorMessage = "Failed to archive conversation"
        }
    }

    func deleteConversation(_ conversation: Conversation) async {
        do {
            try await conversationService.deleteConversation(id: conversation.id)
            conversations.removeAll { $0.id == conversation.id }

            if selectedConversation?.id == conversation.id {
                selectedConversation = nil
                messages = []
            }
        } catch {
            errorMessage = "Failed to delete conversation"
        }
    }

    // MARK: - Export
    func exportConversation(_ conversation: Conversation) async -> Data? {
        do {
            return try await conversationService.exportConversation(id: conversation.id)
        } catch {
            errorMessage = "Failed to export conversation"
            return nil
        }
    }

    // MARK: - Clear Selection
    func clearSelection() {
        selectedConversation = nil
        messages = []
    }
}
