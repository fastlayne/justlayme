import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    var name: String?
    var subscriptionStatus: SubscriptionStatus
    var subscriptionEnd: Date?
    var emailVerified: Bool
    var messageCount: Int
    var createdAt: Date?
    var lastLogin: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, name
        case subscriptionStatus = "subscription_status"
        case subscriptionEnd = "subscription_end"
        case emailVerified = "email_verified"
        case messageCount = "message_count"
        case createdAt = "created_at"
        case lastLogin = "last_login"
    }

    var isPremium: Bool {
        subscriptionStatus == .premium
    }

    var initials: String {
        guard let name = name, !name.isEmpty else {
            return String(email.prefix(1)).uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }
}

enum SubscriptionStatus: String, Codable {
    case free
    case premium
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct RegisterResponse: Codable {
    let message: String
    let email: String
    let requiresVerification: Bool
    let emailSent: Bool?
}

struct VerificationResponse: Codable {
    let message: String
    let email: String?
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
