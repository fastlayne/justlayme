import Foundation
import SwiftData
import Combine

// MARK: - Cache Manager
/// Manages caching strategies for analyses, messages, and model configurations

@MainActor
final class CacheManager: ObservableObject {
    // MARK: - Singleton

    static let shared = CacheManager()

    // MARK: - Published Properties

    @Published private(set) var cacheStats: CacheStats = CacheStats()
    @Published private(set) var isCleaningCache = false

    // MARK: - Private Properties

    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()

    // Cache configuration
    private let maxMessageCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let maxAnalysisCacheAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    private let maxModelCacheAge: TimeInterval = 24 * 60 * 60 // 24 hours
    private let maxCachedConversations: Int = 100
    private let maxCachedMessagesPerConversation: Int = 500

    // MARK: - Initialization

    private init(modelContext: ModelContext = DataContainer.shared.mainContext) {
        self.modelContext = modelContext
        setupAutoCleanup()
    }

    // MARK: - Cache Stats

    struct CacheStats {
        var conversationCount: Int = 0
        var messageCount: Int = 0
        var characterCount: Int = 0
        var memoryCount: Int = 0
        var modelCacheCount: Int = 0
        var estimatedSize: Int64 = 0
        var lastCleanup: Date?

        var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: estimatedSize)
        }
    }

    /// Refresh cache statistics
    func refreshStats() async throws {
        let conversationCount = try modelContext.fetchCount(FetchDescriptor<ConversationEntity>())
        let messageCount = try modelContext.fetchCount(FetchDescriptor<MessageEntity>())
        let characterCount = try modelContext.fetchCount(FetchDescriptor<CharacterEntity>())
        let memoryCount = try modelContext.fetchCount(FetchDescriptor<CharacterMemoryEntity>())
        let modelCacheCount = try modelContext.fetchCount(FetchDescriptor<CachedModelInfo>())

        // Estimate size (rough calculation)
        let estimatedSize = Int64(
            (conversationCount * 500) +  // ~500 bytes per conversation
            (messageCount * 1000) +       // ~1KB per message
            (characterCount * 2000) +     // ~2KB per character
            (memoryCount * 500) +         // ~500 bytes per memory
            (modelCacheCount * 200)       // ~200 bytes per model cache
        )

        cacheStats = CacheStats(
            conversationCount: conversationCount,
            messageCount: messageCount,
            characterCount: characterCount,
            memoryCount: memoryCount,
            modelCacheCount: modelCacheCount,
            estimatedSize: estimatedSize,
            lastCleanup: UserDefaults.standard.object(forKey: "lastCacheCleanup") as? Date
        )
    }

    // MARK: - Auto Cleanup

    private func setupAutoCleanup() {
        // Run cleanup on app launch if not done in last 24 hours
        let lastCleanup = UserDefaults.standard.object(forKey: "lastCacheCleanup") as? Date ?? .distantPast

        if Date().timeIntervalSince(lastCleanup) > 24 * 60 * 60 {
            Task {
                try? await performCleanup()
            }
        }
    }

    /// Perform automatic cache cleanup
    func performCleanup() async throws {
        guard !isCleaningCache else { return }

        isCleaningCache = true
        defer { isCleaningCache = false }

        // Clean expired model cache
        try await cleanExpiredModelCache()

        // Clean old messages beyond limit
        try await cleanOldMessages()

        // Clean orphaned data
        try await cleanOrphanedData()

        // Update last cleanup time
        UserDefaults.standard.set(Date(), forKey: "lastCacheCleanup")

        // Refresh stats
        try await refreshStats()
    }

    // MARK: - Cache Cleanup Methods

    /// Clean expired model cache entries
    func cleanExpiredModelCache() async throws {
        let descriptor = CachedModelInfo.expiredCacheDescriptor()
        let expired = try modelContext.fetch(descriptor)

        for item in expired {
            modelContext.delete(item)
        }

        try modelContext.save()
    }

    /// Clean old messages beyond the limit per conversation
    func cleanOldMessages() async throws {
        // Get all conversations
        let conversations = try modelContext.fetch(FetchDescriptor<ConversationEntity>())

        for conversation in conversations {
            guard let messages = conversation.messages, messages.count > maxCachedMessagesPerConversation else {
                continue
            }

            // Sort by date and get messages to delete
            let sortedMessages = messages.sorted { $0.createdAt < $1.createdAt }
            let messagesToDelete = sortedMessages.prefix(messages.count - maxCachedMessagesPerConversation)

            for message in messagesToDelete {
                modelContext.delete(message)
            }
        }

        try modelContext.save()
    }

    /// Clean orphaned data (messages without conversations, etc.)
    func cleanOrphanedData() async throws {
        // Find messages with no conversation reference
        let allMessages = try modelContext.fetch(FetchDescriptor<MessageEntity>())
        let orphanedMessages = allMessages.filter { $0.conversation == nil }

        for message in orphanedMessages {
            modelContext.delete(message)
        }

        // Find memories with no character reference
        let allMemories = try modelContext.fetch(FetchDescriptor<CharacterMemoryEntity>())
        let orphanedMemories = allMemories.filter { $0.character == nil }

        for memory in orphanedMemories {
            modelContext.delete(memory)
        }

        // Find learnings with no character reference
        let allLearnings = try modelContext.fetch(FetchDescriptor<CharacterLearningEntity>())
        let orphanedLearnings = allLearnings.filter { $0.character == nil }

        for learning in orphanedLearnings {
            modelContext.delete(learning)
        }

        try modelContext.save()
    }

    // MARK: - Manual Cache Control

    /// Clear all cached data
    func clearAllCache() async throws {
        try modelContext.delete(model: CachedModelInfo.self)
        try modelContext.save()

        try await refreshStats()
    }

    /// Clear message cache for a specific conversation
    func clearMessageCache(conversationId: String) async throws {
        let predicate = #Predicate<MessageEntity> { $0.conversationId == conversationId }
        try modelContext.delete(model: MessageEntity.self, where: predicate)
        try modelContext.save()

        try await refreshStats()
    }

    /// Clear all local data (for logout)
    func clearAllData() async throws {
        try modelContext.delete(model: MessageEntity.self)
        try modelContext.delete(model: ConversationEntity.self)
        try modelContext.delete(model: CharacterMemoryEntity.self)
        try modelContext.delete(model: CharacterLearningEntity.self)
        try modelContext.delete(model: CharacterEntity.self)
        try modelContext.delete(model: ConversationTagEntity.self)
        try modelContext.delete(model: CachedModelInfo.self)
        try modelContext.delete(model: UserPreferencesEntity.self)
        try modelContext.delete(model: UserEntity.self)

        try modelContext.save()

        cacheStats = CacheStats()
    }

    // MARK: - Cache Invalidation

    /// Invalidate model cache (force refresh on next request)
    func invalidateModelCache() async throws {
        try modelContext.delete(model: CachedModelInfo.self)
        try modelContext.save()
    }

    /// Invalidate conversation cache for a user
    func invalidateConversationCache(userId: String) async throws {
        let predicate = #Predicate<ConversationEntity> { $0.userId == userId }
        let conversations = try modelContext.fetch(FetchDescriptor<ConversationEntity>(predicate: predicate))

        for conversation in conversations {
            conversation.needsSync = true
        }

        try modelContext.save()
    }

    // MARK: - Cache Preloading

    /// Preload recent analyses for offline access
    func preloadRecentAnalyses(characterId: String, limit: Int = 10) async throws -> [CharacterMemory] {
        let predicate = #Predicate<CharacterMemoryEntity> { $0.characterId == characterId }
        var descriptor = FetchDescriptor<CharacterMemoryEntity>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        descriptor.fetchLimit = limit

        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.toModel() }
    }

    /// Preload message history for offline access
    func preloadMessageHistory(conversationId: String, limit: Int = 100) async throws -> [Message] {
        let predicate = #Predicate<MessageEntity> { $0.conversationId == conversationId }
        var descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        descriptor.fetchLimit = limit

        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.toModel() }.reversed()
    }

    // MARK: - Cache Status

    /// Check if model cache is valid
    func isModelCacheValid() async throws -> Bool {
        let validCount = try modelContext.fetchCount(CachedModelInfo.validCacheDescriptor())
        return validCount > 0
    }

    /// Check if conversation needs sync
    func needsSync(conversationId: String) async throws -> Bool {
        let predicate = #Predicate<ConversationEntity> { $0.id == conversationId }
        var descriptor = FetchDescriptor<ConversationEntity>(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let conversation = try modelContext.fetch(descriptor).first else {
            return true
        }

        return conversation.needsSync
    }

    /// Get total pending sync count
    func getPendingSyncCount() async throws -> Int {
        let conversationCount = try modelContext.fetchCount(ConversationEntity.needsSyncDescriptor())
        let messageCount = try modelContext.fetchCount(MessageEntity.needsSyncDescriptor())
        return conversationCount + messageCount
    }
}

// MARK: - Cache Policy
enum CachePolicy {
    case cacheFirst       // Return cached data, then fetch fresh
    case networkFirst     // Fetch fresh data, fallback to cache
    case cacheOnly        // Only return cached data
    case networkOnly      // Only fetch from network
    case cacheIfFresh     // Return cache if not expired, otherwise fetch

    func shouldUseCache(lastCached: Date?, maxAge: TimeInterval) -> Bool {
        switch self {
        case .cacheFirst, .cacheOnly:
            return true
        case .networkFirst, .networkOnly:
            return false
        case .cacheIfFresh:
            guard let lastCached = lastCached else { return false }
            return Date().timeIntervalSince(lastCached) < maxAge
        }
    }
}

// MARK: - Cache Key
struct CacheKey: Hashable {
    let type: String
    let id: String
    let userId: String?

    init(type: String, id: String, userId: String? = nil) {
        self.type = type
        self.id = id
        self.userId = userId
    }

    static func conversation(_ id: String, userId: String) -> CacheKey {
        return CacheKey(type: "conversation", id: id, userId: userId)
    }

    static func messages(_ conversationId: String) -> CacheKey {
        return CacheKey(type: "messages", id: conversationId)
    }

    static func character(_ id: String, userId: String) -> CacheKey {
        return CacheKey(type: "character", id: id, userId: userId)
    }

    static func modelInfo(_ name: String) -> CacheKey {
        return CacheKey(type: "model", id: name)
    }
}
