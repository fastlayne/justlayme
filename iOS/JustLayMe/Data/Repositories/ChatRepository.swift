import Foundation
import SwiftData
import Combine

// MARK: - Chat Repository Protocol
/// Protocol defining chat data operations

protocol ChatRepositoryProtocol {
    // Conversations
    func getConversations(userId: String, options: ConversationQueryOptions) -> AnyPublisher<[Conversation], Error>
    func getConversation(id: String) -> AnyPublisher<Conversation?, Error>
    func createConversation(_ conversation: Conversation) -> AnyPublisher<Conversation, Error>
    func updateConversation(_ conversation: Conversation) -> AnyPublisher<Conversation, Error>
    func deleteConversation(id: String) -> AnyPublisher<Void, Error>
    func archiveConversation(id: String, archive: Bool) -> AnyPublisher<Conversation, Error>

    // Messages
    func getMessages(conversationId: String, options: MessageQueryOptions) -> AnyPublisher<[Message], Error>
    func addMessage(_ message: Message) -> AnyPublisher<Message, Error>
    func deleteMessage(id: String) -> AnyPublisher<Void, Error>

    // Search
    func searchConversations(userId: String, query: String) -> AnyPublisher<[Conversation], Error>

    // Sync
    func syncConversations(userId: String) -> AnyPublisher<Void, Error>
    func getPendingSyncItems() -> AnyPublisher<Int, Error>
}

// MARK: - Chat Repository
/// Repository for managing chat conversations and messages

@MainActor
final class ChatRepository: ChatRepositoryProtocol, ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var currentConversation: Conversation?
    @Published private(set) var messages: [Message] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    // MARK: - Private Properties

    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Publishers

    /// Publisher for conversation updates
    var conversationsPublisher: AnyPublisher<[Conversation], Never> {
        $conversations.eraseToAnyPublisher()
    }

    /// Publisher for current conversation messages
    var messagesPublisher: AnyPublisher<[Message], Never> {
        $messages.eraseToAnyPublisher()
    }

    /// Publisher for loading state
    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }

    /// Publisher for errors
    var errorPublisher: AnyPublisher<Error?, Never> {
        $error.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(modelContext: ModelContext = DataContainer.shared.mainContext) {
        self.modelContext = modelContext
    }

    // MARK: - Conversation Operations

    func getConversations(userId: String, options: ConversationQueryOptions = ConversationQueryOptions()) -> AnyPublisher<[Conversation], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    self.isLoading = true

                    let descriptor = ConversationEntity.fetchDescriptor(
                        userId: userId,
                        isArchived: options.isArchived,
                        modelType: options.modelType
                    )

                    let entities = try self.modelContext.fetch(descriptor)
                    let conversations = entities.map { $0.toModel() }

                    self.conversations = conversations
                    self.isLoading = false

                    promise(.success(conversations))
                } catch {
                    self.error = error
                    self.isLoading = false
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func getConversation(id: String) -> AnyPublisher<Conversation?, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let predicate = #Predicate<ConversationEntity> { $0.id == id }
                    var descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    let entities = try self.modelContext.fetch(descriptor)
                    let conversation = entities.first?.toModel()

                    self.currentConversation = conversation

                    promise(.success(conversation))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func createConversation(_ conversation: Conversation) -> AnyPublisher<Conversation, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let entity = ConversationEntity(from: conversation)
                    entity.needsSync = true
                    entity.isLocalOnly = true

                    self.modelContext.insert(entity)
                    try self.modelContext.save()

                    let created = entity.toModel()
                    self.conversations.insert(created, at: 0)
                    self.currentConversation = created

                    promise(.success(created))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func updateConversation(_ conversation: Conversation) -> AnyPublisher<Conversation, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let predicate = #Predicate<ConversationEntity> { $0.id == conversation.id }
                    var descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    guard let entity = try self.modelContext.fetch(descriptor).first else {
                        throw RepositoryError.notFound
                    }

                    // Update properties
                    entity.title = conversation.title
                    entity.isArchived = conversation.isArchived
                    entity.tags = conversation.tags
                    entity.updatedAt = Date()
                    entity.needsSync = true

                    try self.modelContext.save()

                    let updated = entity.toModel()

                    // Update local cache
                    if let index = self.conversations.firstIndex(where: { $0.id == updated.id }) {
                        self.conversations[index] = updated
                    }

                    promise(.success(updated))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteConversation(id: String) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let predicate = #Predicate<ConversationEntity> { $0.id == id }
                    var descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    guard let entity = try self.modelContext.fetch(descriptor).first else {
                        throw RepositoryError.notFound
                    }

                    self.modelContext.delete(entity)
                    try self.modelContext.save()

                    // Update local cache
                    self.conversations.removeAll { $0.id == id }
                    if self.currentConversation?.id == id {
                        self.currentConversation = nil
                    }

                    promise(.success(()))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func archiveConversation(id: String, archive: Bool) -> AnyPublisher<Conversation, Error> {
        return getConversation(id: id)
            .flatMap { [weak self] conversation -> AnyPublisher<Conversation, Error> in
                guard let self = self, var conversation = conversation else {
                    return Fail(error: RepositoryError.notFound).eraseToAnyPublisher()
                }

                var updated = conversation
                updated = Conversation(
                    id: conversation.id,
                    userId: conversation.userId,
                    modelType: conversation.modelType,
                    title: conversation.title,
                    messageCount: conversation.messageCount,
                    isArchived: archive,
                    tags: conversation.tags,
                    createdAt: conversation.createdAt,
                    updatedAt: Date()
                )

                return self.updateConversation(updated)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Message Operations

    func getMessages(conversationId: String, options: MessageQueryOptions = MessageQueryOptions()) -> AnyPublisher<[Message], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    self.isLoading = true

                    let descriptor = MessageEntity.fetchDescriptor(conversationId: conversationId)
                    let entities = try self.modelContext.fetch(descriptor)
                    let messages = entities.map { $0.toModel() }

                    self.messages = messages
                    self.isLoading = false

                    promise(.success(messages))
                } catch {
                    self.error = error
                    self.isLoading = false
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func addMessage(_ message: Message) -> AnyPublisher<Message, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let entity = MessageEntity(from: message)
                    entity.needsSync = true
                    entity.isLocalOnly = true

                    self.modelContext.insert(entity)

                    // Update conversation message count
                    let conversationId = message.conversationId
                    let predicate = #Predicate<ConversationEntity> { $0.id == conversationId }
                    var descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    if let conversation = try self.modelContext.fetch(descriptor).first {
                        conversation.updateStats()
                        entity.conversation = conversation
                    }

                    try self.modelContext.save()

                    let added = entity.toModel()
                    self.messages.append(added)

                    promise(.success(added))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteMessage(id: String) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let predicate = #Predicate<MessageEntity> { $0.id == id }
                    var descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
                    descriptor.fetchLimit = 1

                    guard let entity = try self.modelContext.fetch(descriptor).first else {
                        throw RepositoryError.notFound
                    }

                    // Soft delete
                    entity.isDeleted = true
                    entity.needsSync = true

                    try self.modelContext.save()

                    // Update local cache
                    self.messages.removeAll { $0.id == id }

                    promise(.success(()))
                } catch {
                    self.error = error
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Search

    func searchConversations(userId: String, query: String) -> AnyPublisher<[Conversation], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    self.isLoading = true

                    // Search in titles
                    let predicate = #Predicate<ConversationEntity> {
                        $0.userId == userId &&
                        ($0.title?.localizedStandardContains(query) ?? false)
                    }

                    var descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
                    descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]

                    let entities = try self.modelContext.fetch(descriptor)
                    let conversations = entities.map { $0.toModel() }

                    self.isLoading = false

                    promise(.success(conversations))
                } catch {
                    self.error = error
                    self.isLoading = false
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Sync

    func syncConversations(userId: String) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                // This would typically call the API service
                // For now, just mark as synced
                do {
                    let descriptor = ConversationEntity.needsSyncDescriptor()
                    let entities = try self.modelContext.fetch(descriptor)

                    for entity in entities {
                        entity.markAsSynced()
                    }

                    try self.modelContext.save()
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func getPendingSyncItems() -> AnyPublisher<Int, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.instanceDeallocated))
                return
            }

            Task { @MainActor in
                do {
                    let conversationCount = try self.modelContext.fetchCount(
                        ConversationEntity.needsSyncDescriptor()
                    )
                    let messageCount = try self.modelContext.fetchCount(
                        MessageEntity.needsSyncDescriptor()
                    )

                    promise(.success(conversationCount + messageCount))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Helpers

    /// Clear all local data
    func clearLocalData() async throws {
        try modelContext.delete(model: MessageEntity.self)
        try modelContext.delete(model: ConversationEntity.self)
        try modelContext.save()

        conversations = []
        messages = []
        currentConversation = nil
    }

    /// Set current conversation and load messages
    func setCurrentConversation(_ conversation: Conversation) {
        currentConversation = conversation
        _ = getMessages(conversationId: conversation.id)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            )
    }
}

// MARK: - Repository Errors
enum RepositoryError: LocalizedError {
    case notFound
    case invalidData
    case saveFailed
    case instanceDeallocated
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Item not found"
        case .invalidData:
            return "Invalid data"
        case .saveFailed:
            return "Failed to save data"
        case .instanceDeallocated:
            return "Repository instance was deallocated"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}
