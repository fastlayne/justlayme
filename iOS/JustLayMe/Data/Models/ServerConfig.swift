import Foundation

// MARK: - Server Configuration
/// Configuration for connecting to JustLayMe backend

struct ServerConfig {
    /// Base URL for the API
    let baseURL: URL

    /// WebSocket URL for real-time updates
    let websocketURL: URL

    /// Stripe publishable key
    let stripePublishableKey: String?

    /// API timeout in seconds
    let timeout: TimeInterval

    /// Enable debug logging
    let debugMode: Bool

    // MARK: - Singleton Instance

    /// Shared configuration instance
    static var shared: ServerConfig = .production

    // MARK: - Preset Configurations

    /// Production configuration
    static let production = ServerConfig(
        baseURL: URL(string: "https://justlay.me")!,
        websocketURL: URL(string: "wss://justlay.me")!,
        stripePublishableKey: nil, // Set from environment
        timeout: 30,
        debugMode: false
    )

    /// Development configuration
    static let development = ServerConfig(
        baseURL: URL(string: "http://localhost:3000")!,
        websocketURL: URL(string: "ws://localhost:3000")!,
        stripePublishableKey: nil,
        timeout: 60,
        debugMode: true
    )

    // MARK: - API Endpoints

    enum Endpoint: String {
        // Auth
        case register = "/api/register"
        case login = "/api/login"
        case verify = "/api/verify"
        case verifyEmail = "/api/verify-email"
        case resendVerification = "/api/resend-verification"
        case googleAuth = "/api/auth/google"

        // Chat
        case chat = "/api/chat"

        // Characters
        case characters = "/api/characters"
        case customizationOptions = "/api/characters/%@/customization-options"
        case customize = "/api/characters/%@/customize"
        case previewPrompt = "/api/characters/%@/preview-prompt"

        // Conversations
        case conversations = "/api/conversations"
        case conversationMessages = "/api/conversations/%@/messages"
        case conversationSearch = "/api/conversations/search"
        case conversationArchive = "/api/conversations/%@/archive"
        case conversationExport = "/api/conversations/%@/export"

        // Models
        case models = "/api/models"
        case modelTest = "/api/models/test"
        case modelHealth = "/api/models/health"
        case modelRecommendations = "/api/models/recommendations/%@"

        // Profile
        case profile = "/api/profile"

        // Data Management
        case exportData = "/api/export-data"
        case clearData = "/api/clear-data"

        // Feedback
        case feedback = "/api/feedback/%@"

        // Stripe
        case createCheckoutSession = "/api/create-checkout-session"

        // Tags
        case tags = "/api/tags"
        case conversationTags = "/api/conversations/%@/tags"

        /// Build full URL with base
        func url(baseURL: URL, pathParams: String...) -> URL {
            var path = self.rawValue
            for param in pathParams {
                if let range = path.range(of: "%@") {
                    path.replaceSubrange(range, with: param)
                }
            }
            return baseURL.appendingPathComponent(path)
        }
    }

    /// Build URL for endpoint
    func url(for endpoint: Endpoint, pathParams: String...) -> URL {
        var path = endpoint.rawValue
        for param in pathParams {
            if let range = path.range(of: "%@") {
                path.replaceSubrange(range, with: param)
            }
        }
        return baseURL.appendingPathComponent(path)
    }

    /// Build URL with query parameters
    func url(for endpoint: Endpoint, queryItems: [URLQueryItem], pathParams: String...) -> URL {
        var components = URLComponents(url: url(for: endpoint, pathParams: pathParams), resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url!
    }
}

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
    case unauthorized
    case forbidden
    case notFound
    case serverError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return message ?? "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error. Please try again later."
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - API Response Wrapper
struct APIResponse<T: Codable>: Codable {
    let data: T?
    let error: String?
    let message: String?
    let success: Bool?
}

// MARK: - Pricing Configuration
/// Stripe pricing configuration
struct PricingConfig {
    let monthly: PricingTier
    let yearly: PricingTier
    let lifetime: PricingTier

    static let `default` = PricingConfig(
        monthly: PricingTier(
            id: "monthly",
            name: "Monthly Premium",
            price: 9.99,
            description: "Monthly subscription"
        ),
        yearly: PricingTier(
            id: "yearly",
            name: "Yearly Premium",
            price: 79.99,
            description: "Save 33% with yearly",
            savings: "33%"
        ),
        lifetime: PricingTier(
            id: "lifetime",
            name: "Lifetime Premium",
            price: 199.00,
            description: "One-time purchase, forever access"
        )
    )
}

// MARK: - Pricing Tier
struct PricingTier: Identifiable {
    let id: String
    let name: String
    let price: Double
    let description: String
    var savings: String?

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }
}

// MARK: - Checkout Session Request
struct CheckoutSessionRequest: Codable {
    let plan: String
    let userId: String?
    let userEmail: String?

    enum CodingKeys: String, CodingKey {
        case plan
        case userId = "user_id"
        case userEmail = "user_email"
    }
}

// MARK: - Checkout Session Response
struct CheckoutSessionResponse: Codable {
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "sessionId"
    }
}
