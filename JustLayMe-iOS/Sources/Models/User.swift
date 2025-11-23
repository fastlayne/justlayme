import Foundation

// MARK: - User Model
struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    var name: String?
    var googleId: String?
    var subscriptionStatus: SubscriptionStatus
    var subscriptionEnd: Date?
    var messageCount: Int
    var emailVerified: Bool
    var createdAt: Date?
    var lastLogin: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, name
        case googleId = "google_id"
        case subscriptionStatus = "subscription_status"
        case subscriptionEnd = "subscription_end"
        case messageCount = "message_count"
        case emailVerified = "email_verified"
        case createdAt = "created_at"
        case lastLogin = "last_login"
    }

    var isPremium: Bool {
        subscriptionStatus == .premium
    }

    var canAccessPremiumModels: Bool {
        isPremium || messageCount < AppConfig.freeMessageLimit
    }
}

enum SubscriptionStatus: String, Codable {
    case free
    case premium
}

// MARK: - Auth Responses
struct LoginResponse: Codable {
    let token: String
    let user: User
}

struct RegisterResponse: Codable {
    let message: String
    let email: String
    let requiresVerification: Bool
    let emailSent: Bool
}

struct VerifyTokenResponse: Codable {
    let id: String
    let email: String
}

struct ProfileUpdateRequest: Codable {
    let name: String?
    let avatarStyle: String?
    let themePreference: String?

    enum CodingKeys: String, CodingKey {
        case name
        case avatarStyle = "avatar_style"
        case themePreference = "theme_preference"
    }
}

struct ProfileUpdateResponse: Codable {
    let message: String
    let user: User
}

// MARK: - Google Auth
struct GoogleAuthRequest: Codable {
    let credential: String
}
