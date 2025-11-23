import Foundation

// MARK: - App Configuration

enum AppConfig {
    // MARK: - Environment

    enum Environment {
        case development
        case staging
        case production

        var baseURL: String {
            switch self {
            case .development:
                return "http://localhost:3000"
            case .staging:
                return "https://staging.justlay.me"
            case .production:
                return "https://justlay.me"
            }
        }

        var webSocketURL: String {
            switch self {
            case .development:
                return "ws://localhost:3000"
            case .staging:
                return "wss://staging.justlay.me"
            case .production:
                return "wss://justlay.me"
            }
        }
    }

    // MARK: - Current Environment

    static var environment: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    // MARK: - API Configuration

    static var baseURL: String {
        environment.baseURL
    }

    static var webSocketURL: String {
        environment.webSocketURL
    }

    static var apiVersion: String {
        "v1"
    }

    // MARK: - Timeouts

    static var requestTimeout: TimeInterval {
        30.0
    }

    static var resourceTimeout: TimeInterval {
        60.0
    }

    // MARK: - Chat Configuration

    static var maxMessageLength: Int {
        4000
    }

    static var freeMessageLimit: Int {
        3
    }

    // MARK: - Keychain Keys

    enum KeychainKey {
        static let authToken = "com.justlayme.auth.token"
        static let refreshToken = "com.justlayme.auth.refresh"
        static let userId = "com.justlayme.auth.userId"
    }

    // MARK: - UserDefaults Keys

    enum UserDefaultsKey {
        static let isOnboarded = "isOnboarded"
        static let selectedCharacterId = "selectedCharacterId"
        static let selectedModelId = "selectedModelId"
        static let hapticFeedbackEnabled = "hapticFeedbackEnabled"
        static let notificationsEnabled = "notificationsEnabled"
        static let darkModeEnabled = "darkModeEnabled"
        static let lastSyncDate = "lastSyncDate"
    }

    // MARK: - App Store

    enum AppStore {
        static let appId = "XXXXXXXXXX" // Replace with actual App Store ID
        static let appStoreURL = "https://apps.apple.com/app/id\(appId)"
        static let reviewURL = "https://apps.apple.com/app/id\(appId)?action=write-review"
    }

    // MARK: - Google Sign-In

    enum GoogleSignIn {
        static let clientId = "YOUR_GOOGLE_CLIENT_ID" // Replace with actual client ID
    }

    // MARK: - Feature Flags

    enum Features {
        static let enableWebSocket = true
        static let enablePushNotifications = true
        static let enableAnalytics = true
        static let enableCrashReporting = true
    }
}

// MARK: - API Endpoints

enum APIEndpoint {
    // Auth
    case register
    case login
    case verify
    case verifyEmail(token: String)
    case resendVerification
    case googleAuth

    // Characters
    case characters
    case character(id: Int)
    case characterCustomization(id: Int)
    case characterPreviewPrompt(id: Int)

    // Chat
    case chat
    case chatWithCharacter(id: String)
    case feedback(memoryId: Int)

    // Models
    case models
    case modelTest
    case modelHealth
    case modelRecommendation(characterId: Int)

    // Conversations
    case conversations
    case conversation(id: Int)
    case conversationMessages(id: Int)
    case conversationSearch
    case conversationArchive(id: Int)
    case conversationExport(id: Int, format: String)

    // Profile
    case profile
    case exportData
    case clearData

    // Payment
    case createCheckoutSession
    case webhook

    // MARK: - Path

    var path: String {
        switch self {
        case .register:
            return "/api/register"
        case .login:
            return "/api/login"
        case .verify:
            return "/api/verify"
        case .verifyEmail(let token):
            return "/api/verify-email?token=\(token)"
        case .resendVerification:
            return "/api/resend-verification"
        case .googleAuth:
            return "/api/auth/google"
        case .characters:
            return "/api/characters"
        case .character(let id):
            return "/api/characters/\(id)"
        case .characterCustomization(let id):
            return "/api/characters/\(id)/customization-options"
        case .characterPreviewPrompt(let id):
            return "/api/characters/\(id)/preview-prompt"
        case .chat:
            return "/api/chat"
        case .chatWithCharacter(let id):
            return "/api/chat/\(id)"
        case .feedback(let memoryId):
            return "/api/feedback/\(memoryId)"
        case .models:
            return "/api/models"
        case .modelTest:
            return "/api/models/test"
        case .modelHealth:
            return "/api/models/health"
        case .modelRecommendation(let characterId):
            return "/api/models/recommendations/\(characterId)"
        case .conversations:
            return "/api/conversations"
        case .conversation(let id):
            return "/api/conversations/\(id)"
        case .conversationMessages(let id):
            return "/api/conversations/\(id)/messages"
        case .conversationSearch:
            return "/api/conversations/search"
        case .conversationArchive(let id):
            return "/api/conversations/\(id)/archive"
        case .conversationExport(let id, let format):
            return "/api/conversations/\(id)/export?format=\(format)"
        case .profile:
            return "/api/profile"
        case .exportData:
            return "/api/export-data"
        case .clearData:
            return "/api/clear-data"
        case .createCheckoutSession:
            return "/api/create-checkout-session"
        case .webhook:
            return "/api/webhook"
        }
    }

    // MARK: - Full URL

    var url: URL? {
        URL(string: AppConfig.baseURL + path)
    }
}
