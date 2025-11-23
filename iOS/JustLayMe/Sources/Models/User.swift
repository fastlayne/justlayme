import Foundation

// MARK: - User Models

struct User: Codable, Equatable, Identifiable {
    let id: String
    let email: String
    var name: String?
    var subscriptionStatus: SubscriptionStatus
    var subscriptionEnd: Date?
    var emailVerified: Bool
    var isProfessionalEmail: Bool?
    var messageCount: Int
    var createdAt: Date?
    var lastLogin: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, name
        case subscriptionStatus = "subscription_status"
        case subscriptionEnd = "subscription_end"
        case emailVerified = "email_verified"
        case isProfessionalEmail = "is_professional_email"
        case messageCount = "message_count"
        case createdAt = "created_at"
        case lastLogin = "last_login"
    }
}

enum SubscriptionStatus: String, Codable, Equatable {
    case free
    case premium
    case lifetime

    var isPremium: Bool {
        self != .free
    }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .lifetime: return "Lifetime Premium"
        }
    }
}

struct AuthResponse: Codable, Equatable {
    let token: String
    let user: User
}

struct RegistrationResponse: Codable, Equatable {
    let message: String
    let email: String
    let requiresVerification: Bool
    let emailSent: Bool

    enum CodingKeys: String, CodingKey {
        case message, email
        case requiresVerification = "requiresVerification"
        case emailSent = "emailSent"
    }
}

struct VerificationResponse: Codable, Equatable {
    let message: String
    let email: String?
}

struct LoginCredentials: Equatable {
    let email: String
    let password: String

    var isValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6
    }
}

struct RegistrationCredentials: Equatable {
    let email: String
    let password: String
    let confirmPassword: String

    var isValid: Bool {
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword
    }

    var passwordsMatch: Bool {
        password == confirmPassword
    }
}
