import Foundation
import SwiftData

// MARK: - User Entity
/// SwiftData persistent model for User
/// Stores user account information locally

@Model
final class UserEntity {
    // MARK: - Properties

    @Attribute(.unique)
    var id: String

    @Attribute(.unique)
    var email: String

    var name: String?
    var googleId: String?
    var subscriptionStatus: String
    var subscriptionEnd: Date?
    var messageCount: Int
    var emailVerified: Bool
    var createdAt: Date
    var lastLogin: Date?
    var lastSyncedAt: Date?

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \ConversationEntity.user)
    var conversations: [ConversationEntity]?

    @Relationship(deleteRule: .cascade, inverse: \CharacterEntity.user)
    var characters: [CharacterEntity]?

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        email: String,
        name: String? = nil,
        googleId: String? = nil,
        subscriptionStatus: String = "free",
        subscriptionEnd: Date? = nil,
        messageCount: Int = 0,
        emailVerified: Bool = false,
        createdAt: Date = Date(),
        lastLogin: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.googleId = googleId
        self.subscriptionStatus = subscriptionStatus
        self.subscriptionEnd = subscriptionEnd
        self.messageCount = messageCount
        self.emailVerified = emailVerified
        self.createdAt = createdAt
        self.lastLogin = lastLogin
        self.lastSyncedAt = Date()
    }

    // MARK: - Conversion

    /// Convert from API model
    convenience init(from user: User) {
        self.init(
            id: user.id,
            email: user.email,
            name: user.name,
            googleId: user.googleId,
            subscriptionStatus: user.subscriptionStatus.rawValue,
            subscriptionEnd: user.subscriptionEnd,
            messageCount: user.messageCount,
            emailVerified: user.emailVerified,
            createdAt: user.createdAt,
            lastLogin: user.lastLogin
        )
    }

    /// Convert to API model
    func toModel() -> User {
        return User(
            id: id,
            email: email,
            name: name,
            googleId: googleId,
            subscriptionStatus: SubscriptionStatus(rawValue: subscriptionStatus) ?? .free,
            subscriptionEnd: subscriptionEnd,
            messageCount: messageCount,
            emailVerified: emailVerified,
            createdAt: createdAt,
            lastLogin: lastLogin
        )
    }

    // MARK: - Computed Properties

    var isPremium: Bool {
        let status = SubscriptionStatus(rawValue: subscriptionStatus) ?? .free
        return status.isPremium
    }

    var displayName: String {
        return name ?? email.components(separatedBy: "@").first ?? "User"
    }
}

// MARK: - User Preferences Entity
/// Stores local user preferences that don't sync to server

@Model
final class UserPreferencesEntity {
    @Attribute(.unique)
    var userId: String

    var themeMode: String // "light", "dark", "system"
    var hapticFeedback: Bool
    var notificationsEnabled: Bool
    var defaultModelType: String
    var autoSaveConversations: Bool
    var showTypingIndicator: Bool
    var messageFontSize: Int

    // Privacy settings
    var analyticsEnabled: Bool
    var crashReportingEnabled: Bool

    var createdAt: Date
    var updatedAt: Date

    init(
        userId: String,
        themeMode: String = "system",
        hapticFeedback: Bool = true,
        notificationsEnabled: Bool = true,
        defaultModelType: String = "layme_v1",
        autoSaveConversations: Bool = true,
        showTypingIndicator: Bool = true,
        messageFontSize: Int = 16,
        analyticsEnabled: Bool = true,
        crashReportingEnabled: Bool = true
    ) {
        self.userId = userId
        self.themeMode = themeMode
        self.hapticFeedback = hapticFeedback
        self.notificationsEnabled = notificationsEnabled
        self.defaultModelType = defaultModelType
        self.autoSaveConversations = autoSaveConversations
        self.showTypingIndicator = showTypingIndicator
        self.messageFontSize = messageFontSize
        self.analyticsEnabled = analyticsEnabled
        self.crashReportingEnabled = crashReportingEnabled
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
