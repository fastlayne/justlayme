import Foundation
import Combine

// MARK: - Conversation View Model

@MainActor
final class ConversationViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var conversations: [Conversation] = []
    @Published var selectedConversation: Conversation?
    @Published var messages: [Message] = []

    @Published var searchQuery: String = ""
    @Published var searchResults: [ConversationSearchResponse.SearchResult] = []

    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?

    @Published var currentPage: Int = 1
    @Published var hasMorePages: Bool = true
    @Published var totalConversations: Int = 0

    // MARK: - Properties

    private let apiService: APIServiceProtocol
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    private let pageSize = 20

    // MARK: - Computed Properties

    var canLoadMore: Bool {
        hasMorePages && !isLoadingMore
    }

    var filteredConversations: [Conversation] {
        if searchQuery.isEmpty {
            return conversations
        }
        return conversations.filter { conversation in
            conversation.displayTitle.localizedCaseInsensitiveContains(searchQuery) ||
            (conversation.tags?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }

    var activeConversations: [Conversation] {
        conversations.filter { !$0.isArchived }
    }

    var archivedConversations: [Conversation] {
        conversations.filter { $0.isArchived }
    }

    // MARK: - Initialization

    init(
        apiService: APIServiceProtocol = APIService.shared,
        authService: AuthService = .shared
    ) {
        self.apiService = apiService
        self.authService = authService

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Debounce search
        $searchQuery
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                if !query.isEmpty {
                    Task {
                        await self?.search(query: query)
                    }
                } else {
                    self?.searchResults = []
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func loadConversations() async {
        isLoading = true
        errorMessage = nil
        currentPage = 1

        do {
            let response = try await apiService.getConversations(page: currentPage, limit: pageSize)
            conversations = response.conversations
            totalConversations = response.total
            hasMorePages = response.hasMore
        } catch {
            errorMessage = "Failed to load conversations"
        }

        isLoading = false
    }

    func loadMoreConversations() async {
        guard canLoadMore else { return }

        isLoadingMore = true

        do {
            let response = try await apiService.getConversations(page: currentPage + 1, limit: pageSize)
            conversations.append(contentsOf: response.conversations)
            currentPage += 1
            hasMorePages = response.hasMore
        } catch {
            // Silently fail for pagination
        }

        isLoadingMore = false
    }

    func loadMessages(for conversation: Conversation) async {
        isLoading = true
        errorMessage = nil
        selectedConversation = conversation

        do {
            let response = try await apiService.getConversationMessages(id: conversation.id)
            messages = response.messages
        } catch {
            errorMessage = "Failed to load messages"
        }

        isLoading = false
    }

    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        do {
            let response = try await apiService.searchConversations(query: query)
            searchResults = response.results
        } catch {
            // Silently fail for search
        }
    }

    func archiveConversation(_ conversation: Conversation) async -> Bool {
        do {
            try await apiService.archiveConversation(id: conversation.id)

            // Update local state
            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations[index].isArchived = true
            }

            return true
        } catch {
            errorMessage = "Failed to archive conversation"
            return false
        }
    }

    func deleteConversation(_ conversation: Conversation) async -> Bool {
        do {
            try await apiService.deleteConversation(id: conversation.id)

            // Remove from local state
            conversations.removeAll { $0.id == conversation.id }

            if selectedConversation?.id == conversation.id {
                selectedConversation = nil
                messages = []
            }

            return true
        } catch {
            errorMessage = "Failed to delete conversation"
            return false
        }
    }

    func exportConversation(_ conversation: Conversation, format: ExportFormat) async -> Data? {
        do {
            return try await apiService.exportConversation(id: conversation.id, format: format)
        } catch {
            errorMessage = "Failed to export conversation"
            return nil
        }
    }

    func refresh() async {
        await loadConversations()
    }

    func clearSelection() {
        selectedConversation = nil
        messages = []
    }
}

// MARK: - Conversation Grouping

extension ConversationViewModel {
    struct ConversationGroup: Identifiable {
        let id: String
        let title: String
        let conversations: [Conversation]
    }

    var groupedConversations: [ConversationGroup] {
        let calendar = Calendar.current
        let now = Date()

        var today: [Conversation] = []
        var yesterday: [Conversation] = []
        var thisWeek: [Conversation] = []
        var thisMonth: [Conversation] = []
        var older: [Conversation] = []

        for conversation in activeConversations {
            if calendar.isDateInToday(conversation.updatedAt) {
                today.append(conversation)
            } else if calendar.isDateInYesterday(conversation.updatedAt) {
                yesterday.append(conversation)
            } else if calendar.isDate(conversation.updatedAt, equalTo: now, toGranularity: .weekOfYear) {
                thisWeek.append(conversation)
            } else if calendar.isDate(conversation.updatedAt, equalTo: now, toGranularity: .month) {
                thisMonth.append(conversation)
            } else {
                older.append(conversation)
            }
        }

        var groups: [ConversationGroup] = []

        if !today.isEmpty {
            groups.append(ConversationGroup(id: "today", title: "Today", conversations: today))
        }
        if !yesterday.isEmpty {
            groups.append(ConversationGroup(id: "yesterday", title: "Yesterday", conversations: yesterday))
        }
        if !thisWeek.isEmpty {
            groups.append(ConversationGroup(id: "week", title: "This Week", conversations: thisWeek))
        }
        if !thisMonth.isEmpty {
            groups.append(ConversationGroup(id: "month", title: "This Month", conversations: thisMonth))
        }
        if !older.isEmpty {
            groups.append(ConversationGroup(id: "older", title: "Older", conversations: older))
        }

        return groups
    }
}
