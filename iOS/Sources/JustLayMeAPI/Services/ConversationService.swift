// MARK: - Conversation Service
// Handles chat history, conversations, and message management

import Foundation
import Combine

public final class ConversationService: ObservableObject {
    public static let shared = ConversationService()

    private let client: APIClient
    private var cancellables = Set<AnyCancellable>()

    @Published public private(set) var conversations: [Conversation] = []
    @Published public private(set) var pagination: Pagination?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var searchResults: [ConversationSearchResult] = []

    public init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Fetch Conversations

    /// Get user's conversations with pagination and filters
    public func fetchConversations(
        page: Int = 1,
        limit: Int = 20,
        modelType: String? = nil,
        archived: Bool = false,
        search: String? = nil,
        orderBy: String = "updated_at",
        orderDirection: String = "DESC"
    ) -> AnyPublisher<ConversationsResponse, APIError> {
        isLoading = true

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "archived", value: String(archived)),
            URLQueryItem(name: "order_by", value: orderBy),
            URLQueryItem(name: "order_dir", value: orderDirection)
        ]

        if let modelType = modelType {
            queryItems.append(URLQueryItem(name: "model_type", value: modelType))
        }

        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }

        return client.request(.conversations, queryItems: queryItems)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    if page == 1 {
                        self?.conversations = response.conversations
                    } else {
                        self?.conversations.append(contentsOf: response.conversations)
                    }
                    self?.pagination = response.pagination
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func fetchConversations(
        page: Int = 1,
        limit: Int = 20,
        modelType: String? = nil,
        archived: Bool = false,
        search: String? = nil,
        orderBy: String = "updated_at",
        orderDirection: String = "DESC"
    ) async throws -> ConversationsResponse {
        isLoading = true
        defer { isLoading = false }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "archived", value: String(archived)),
            URLQueryItem(name: "order_by", value: orderBy),
            URLQueryItem(name: "order_dir", value: orderDirection)
        ]

        if let modelType = modelType {
            queryItems.append(URLQueryItem(name: "model_type", value: modelType))
        }

        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }

        let response: ConversationsResponse = try await client.request(.conversations, queryItems: queryItems)

        if page == 1 {
            conversations = response.conversations
        } else {
            conversations.append(contentsOf: response.conversations)
        }
        pagination = response.pagination

        return response
    }

    // MARK: - Get Conversation Messages

    /// Get messages for a specific conversation
    public func fetchMessages(
        conversationId: String,
        page: Int = 1,
        limit: Int = 50,
        orderDirection: String = "ASC"
    ) -> AnyPublisher<[Message], APIError> {
        isLoading = true

        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "order_dir", value: orderDirection)
        ]

        return client.request(.conversationMessages(conversationId), queryItems: queryItems)
            .map { (response: MessagesResponse) in response.messages }
            .handleEvents(
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func fetchMessages(
        conversationId: String,
        page: Int = 1,
        limit: Int = 50,
        orderDirection: String = "ASC"
    ) async throws -> [Message] {
        isLoading = true
        defer { isLoading = false }

        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "order_dir", value: orderDirection)
        ]

        let response: MessagesResponse = try await client.request(.conversationMessages(conversationId), queryItems: queryItems)
        return response.messages
    }

    // MARK: - Search Conversations

    /// Search across all conversations
    public func search(query: String) -> AnyPublisher<[ConversationSearchResult], APIError> {
        isLoading = true

        let queryItems = [URLQueryItem(name: "q", value: query)]

        return client.request(.searchConversations, queryItems: queryItems)
            .map { (response: SearchConversationsResponse) in response.results }
            .handleEvents(
                receiveOutput: { [weak self] results in
                    self?.searchResults = results
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func search(query: String) async throws -> [ConversationSearchResult] {
        isLoading = true
        defer { isLoading = false }

        let queryItems = [URLQueryItem(name: "q", value: query)]
        let response: SearchConversationsResponse = try await client.request(.searchConversations, queryItems: queryItems)
        searchResults = response.results
        return response.results
    }

    // MARK: - Archive Conversation

    /// Archive or unarchive a conversation
    public func archiveConversation(
        _ conversationId: String,
        archive: Bool = true
    ) -> AnyPublisher<ArchiveConversationResponse, APIError> {
        let request = ArchiveConversationRequest(archive: archive)

        return client.request(.archiveConversation(conversationId), body: request)
            .handleEvents(
                receiveOutput: { [weak self] _ in
                    self?.conversations.removeAll { $0.id == conversationId }
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func archiveConversation(
        _ conversationId: String,
        archive: Bool = true
    ) async throws -> ArchiveConversationResponse {
        let request = ArchiveConversationRequest(archive: archive)
        let response: ArchiveConversationResponse = try await client.request(.archiveConversation(conversationId), body: request)
        conversations.removeAll { $0.id == conversationId }
        return response
    }

    // MARK: - Delete Conversation

    /// Delete a conversation (soft delete)
    public func deleteConversation(_ conversationId: String) -> AnyPublisher<SuccessResponse, APIError> {
        return client.request(.deleteConversation(conversationId))
            .handleEvents(
                receiveOutput: { [weak self] _ in
                    self?.conversations.removeAll { $0.id == conversationId }
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func deleteConversation(_ conversationId: String) async throws -> SuccessResponse {
        let response: SuccessResponse = try await client.request(.deleteConversation(conversationId))
        conversations.removeAll { $0.id == conversationId }
        return response
    }

    // MARK: - Export Conversation

    /// Export a conversation (premium only)
    public func exportConversation(
        _ conversationId: String,
        format: ExportFormat = .json
    ) -> AnyPublisher<Data, APIError> {
        let queryItems = [URLQueryItem(name: "format", value: format.rawValue)]
        return client.requestData(.exportConversation(conversationId), queryItems: queryItems)
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func exportConversation(
        _ conversationId: String,
        format: ExportFormat = .json
    ) async throws -> Data {
        let queryItems = [URLQueryItem(name: "format", value: format.rawValue)]

        guard var urlComponents = URLComponents(
            url: client.baseURL.appendingPathComponent("/api/conversations/\(conversationId)/export"),
            resolvingAgainstBaseURL: true
        ) else {
            throw APIError.invalidURL
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let token = client.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, message: nil)
        }

        return data
    }

    // MARK: - Helper Methods

    /// Load more conversations (next page)
    public func loadMore() -> AnyPublisher<ConversationsResponse, APIError> {
        guard let currentPagination = pagination,
              currentPagination.page < currentPagination.totalPages else {
            return Empty().eraseToAnyPublisher()
        }

        return fetchConversations(page: currentPagination.page + 1)
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func loadMore() async throws -> ConversationsResponse? {
        guard let currentPagination = pagination,
              currentPagination.page < currentPagination.totalPages else {
            return nil
        }

        return try await fetchConversations(page: currentPagination.page + 1)
    }

    /// Clear local data
    public func clearCache() {
        conversations.removeAll()
        searchResults.removeAll()
        pagination = nil
    }
}

// MARK: - Export Format

public enum ExportFormat: String {
    case json
    case txt
    case markdown
}

// MARK: - Conversation Extension

extension Conversation {
    /// Get formatted last activity time
    public var formattedLastActivity: String? {
        guard let updatedAt = updatedAt else { return nil }

        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: updatedAt) else { return nil }

        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .abbreviated
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// Check if conversation has messages
    public var hasMessages: Bool {
        (messageCount ?? 0) > 0 || (totalMessages ?? 0) > 0
    }
}
