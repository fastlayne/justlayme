import Foundation
import SwiftData

// MARK: - Conversation Tag Entity
/// SwiftData persistent model for ConversationTag

@Model
final class ConversationTagEntity {
    // MARK: - Properties

    @Attribute(.unique)
    var id: String

    var userId: String
    var tagName: String
    var color: String
    var createdAt: Date

    // MARK: - Relationships

    var conversations: [ConversationEntity]?

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        userId: String,
        tagName: String,
        color: String = "#6B46FF",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.tagName = tagName
        self.color = color
        self.createdAt = createdAt
    }

    // MARK: - Conversion

    /// Convert from API model
    convenience init(from tag: ConversationTag) {
        self.init(
            id: tag.id,
            userId: tag.userId,
            tagName: tag.tagName,
            color: tag.color,
            createdAt: tag.createdAt
        )
    }

    /// Convert to API model
    func toModel() -> ConversationTag {
        return ConversationTag(
            id: id,
            userId: userId,
            tagName: tagName,
            color: color,
            createdAt: createdAt
        )
    }

    // MARK: - Computed Properties

    /// Number of conversations with this tag
    var conversationCount: Int {
        return conversations?.count ?? 0
    }
}

// MARK: - Cached Model Info Entity
/// Cache for AI model information

@Model
final class CachedModelInfo {
    @Attribute(.unique)
    var name: String

    var size: Int64?
    var capabilitiesJSON: Data?
    var recommendedFor: [String]?
    var cachedAt: Date

    // Cache expiration (24 hours)
    var expiresAt: Date

    init(
        name: String,
        size: Int64? = nil,
        capabilities: ModelCapabilities? = nil,
        recommendedFor: [String]? = nil
    ) {
        self.name = name
        self.size = size
        self.recommendedFor = recommendedFor
        self.cachedAt = Date()
        self.expiresAt = Date().addingTimeInterval(24 * 60 * 60)

        if let capabilities = capabilities {
            self.capabilitiesJSON = try? JSONEncoder().encode(capabilities)
        }
    }

    /// Convert from API model
    convenience init(from modelInfo: ModelInfo) {
        self.init(
            name: modelInfo.name,
            size: modelInfo.size,
            capabilities: modelInfo.capabilities,
            recommendedFor: modelInfo.recommendedFor
        )
    }

    /// Convert to API model
    func toModel() -> ModelInfo {
        return ModelInfo(
            name: name,
            size: size,
            capabilities: capabilities ?? ModelCapabilities(),
            recommendedFor: recommendedFor
        )
    }

    /// Decoded capabilities
    var capabilities: ModelCapabilities? {
        guard let data = capabilitiesJSON else { return nil }
        return try? JSONDecoder().decode(ModelCapabilities.self, from: data)
    }

    /// Check if cache is still valid
    var isValid: Bool {
        return Date() < expiresAt
    }

    /// Refresh cache expiration
    func refresh() {
        self.cachedAt = Date()
        self.expiresAt = Date().addingTimeInterval(24 * 60 * 60)
    }
}

// MARK: - Fetch Descriptors
extension ConversationTagEntity {

    /// Fetch descriptor for user's tags
    static func fetchDescriptor(userId: String) -> FetchDescriptor<ConversationTagEntity> {
        let predicate = #Predicate<ConversationTagEntity> { $0.userId == userId }
        var descriptor = FetchDescriptor<ConversationTagEntity>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.tagName, order: .forward)]
        return descriptor
    }
}

extension CachedModelInfo {

    /// Fetch descriptor for valid cached models
    static func validCacheDescriptor() -> FetchDescriptor<CachedModelInfo> {
        let now = Date()
        let predicate = #Predicate<CachedModelInfo> { $0.expiresAt > now }
        return FetchDescriptor<CachedModelInfo>(predicate: predicate)
    }

    /// Fetch descriptor for expired cache entries
    static func expiredCacheDescriptor() -> FetchDescriptor<CachedModelInfo> {
        let now = Date()
        let predicate = #Predicate<CachedModelInfo> { $0.expiresAt <= now }
        return FetchDescriptor<CachedModelInfo>(predicate: predicate)
    }
}
