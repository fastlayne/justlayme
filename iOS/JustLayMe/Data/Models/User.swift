import Foundation

// MARK: - User Model
/// Represents a JustLayMe user account
/// Matches backend: character-api.js users table

struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    var name: String?
    var googleId: String?
    var subscriptionStatus: SubscriptionStatus
    var subscriptionEnd: Date?
    var messageCount: Int
    var emailVerified: Bool
    var verificationToken: String?
    var verificationExpires: Date?
    var createdAt: Date
    var lastLogin: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case googleId = "google_id"
        case subscriptionStatus = "subscription_status"
        case subscriptionEnd = "subscription_end"
        case messageCount = "message_count"
        case emailVerified = "email_verified"
        case verificationToken = "verification_token"
        case verificationExpires = "verification_expires"
        case createdAt = "created_at"
        case lastLogin = "last_login"
    }

    init(
        id: String = UUID().uuidString,
        email: String,
        name: String? = nil,
        googleId: String? = nil,
        subscriptionStatus: SubscriptionStatus = .free,
        subscriptionEnd: Date? = nil,
        messageCount: Int = 0,
        emailVerified: Bool = false,
        verificationToken: String? = nil,
        verificationExpires: Date? = nil,
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
        self.verificationToken = verificationToken
        self.verificationExpires = verificationExpires
        self.createdAt = createdAt
        self.lastLogin = lastLogin
    }
}

// MARK: - Subscription Status
enum SubscriptionStatus: String, Codable, CaseIterable {
    case free = "free"
    case premium = "premium"
    case lifetime = "lifetime"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .lifetime: return "Lifetime"
        }
    }

    var isPremium: Bool {
        return self != .free
    }

    var messageLimit: Int? {
        switch self {
        case .free: return 100
        case .premium, .lifetime: return nil
        }
    }
}

// MARK: - Authentication Response
struct AuthResponse: Codable {
    let token: String
    let user: User
}

// MARK: - Login Request
struct LoginRequest: Codable {
    let email: String
    let password: String
}

// MARK: - Registration Request
struct RegistrationRequest: Codable {
    let email: String
    let password: String
}

// MARK: - Registration Response
struct RegistrationResponse: Codable {
    let message: String
    let email: String
    let requiresVerification: Bool
    let emailSent: Bool
}

// MARK: - Google Auth Request
struct GoogleAuthRequest: Codable {
    let credential: String
}

// MARK: - User Profile Update
struct UserProfileUpdate: Codable {
    var name: String?
    var avatarStyle: String?
    var themePreference: String?

    enum CodingKeys: String, CodingKey {
        case name
        case avatarStyle = "avatar_style"
        case themePreference = "theme_preference"
    }
}
