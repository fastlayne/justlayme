import Foundation

// MARK: - User Model

struct User: Codable, Identifiable, Equatable {
    let id: Int
    let email: String
    var name: String?
    var googleId: String?
    var subscriptionStatus: SubscriptionStatus
    var subscriptionEnd: Date?
    var messageCount: Int
    var emailVerified: Bool
    var createdAt: Date
    var lastLogin: Date?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case googleId = "google_id"
        case subscriptionStatus = "subscription_status"
        case subscriptionEnd = "subscription_end"
        case messageCount = "message_count"
        case emailVerified = "email_verified"
        case createdAt = "created_at"
        case lastLogin = "last_login"
    }

    // MARK: - Computed Properties

    var isPremium: Bool {
        switch subscriptionStatus {
        case .premium, .lifetime:
            if subscriptionStatus == .lifetime {
                return true
            }
            guard let endDate = subscriptionEnd else { return false }
            return endDate > Date()
        case .free:
            return false
        }
    }

    var displayName: String {
        name ?? email.components(separatedBy: "@").first ?? "User"
    }

    var initials: String {
        let components = displayName.components(separatedBy: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    // MARK: - Static

    static let guest = User(
        id: 0,
        email: "guest@justlay.me",
        name: "Guest",
        googleId: nil,
        subscriptionStatus: .free,
        subscriptionEnd: nil,
        messageCount: 0,
        emailVerified: false,
        createdAt: Date(),
        lastLogin: nil
    )
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

    var icon: String {
        switch self {
        case .free: return "star"
        case .premium: return "star.fill"
        case .lifetime: return "crown.fill"
        }
    }
}

// MARK: - User Profile Update

struct UserProfileUpdate: Codable {
    var name: String?
    var email: String?
}

// MARK: - Auth Response

struct AuthResponse: Codable {
    let token: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case token
        case user
    }
}

// MARK: - Login Request

struct LoginRequest: Codable {
    let email: String
    let password: String
}

// MARK: - Register Request

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let name: String?
}

// MARK: - Google Auth Request

struct GoogleAuthRequest: Codable {
    let idToken: String

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
    }
}
