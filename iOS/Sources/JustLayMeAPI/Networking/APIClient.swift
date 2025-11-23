// MARK: - JustLayMe API Client
// Production-ready URLSession + Combine networking layer

import Foundation
import Combine

// MARK: - API Configuration

public struct APIConfiguration {
    public let baseURL: URL
    public let webSocketURL: URL
    public var authToken: String?
    public var sessionId: String?

    public static let production = APIConfiguration(
        baseURL: URL(string: "https://justlay.me")!,
        webSocketURL: URL(string: "wss://justlay.me")!
    )

    public static let development = APIConfiguration(
        baseURL: URL(string: "http://localhost:3000")!,
        webSocketURL: URL(string: "ws://localhost:3000")!
    )

    public init(baseURL: URL, webSocketURL: URL, authToken: String? = nil, sessionId: String? = nil) {
        self.baseURL = baseURL
        self.webSocketURL = webSocketURL
        self.authToken = authToken
        self.sessionId = sessionId
    }
}

// MARK: - HTTP Method

public enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
    case PATCH
}

// MARK: - API Error

public enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData
    case unauthorized
    case forbidden(String)
    case notFound
    case serverError(statusCode: Int, message: String?)
    case networkError(Error)
    case decodingError(Error)
    case encodingError(Error)
    case emailNotVerified(email: String)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidData:
            return "Invalid data received"
        case .unauthorized:
            return "Authentication required"
        case .forbidden(let message):
            return message
        case .notFound:
            return "Resource not found"
        case .serverError(let code, let message):
            return message ?? "Server error (code: \(code))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Request encoding error: \(error.localizedDescription)"
        case .emailNotVerified(let email):
            return "Email \(email) is not verified"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// MARK: - API Endpoint

public struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let requiresAuth: Bool

    init(_ path: String, method: HTTPMethod = .GET, requiresAuth: Bool = false) {
        self.path = path
        self.method = method
        self.requiresAuth = requiresAuth
    }

    // Authentication
    static let register = APIEndpoint("/api/register", method: .POST)
    static let login = APIEndpoint("/api/login", method: .POST)
    static let verify = APIEndpoint("/api/verify", requiresAuth: true)
    static let verifyEmail = APIEndpoint("/api/verify-email")
    static let resendVerification = APIEndpoint("/api/resend-verification", method: .POST)
    static let googleAuth = APIEndpoint("/api/auth/google", method: .POST)

    // Chat
    static let chat = APIEndpoint("/api/chat", method: .POST)
    static func chatWithCharacter(_ characterId: String) -> APIEndpoint {
        APIEndpoint("/api/chat/\(characterId)", method: .POST, requiresAuth: true)
    }

    // Characters
    static let characters = APIEndpoint("/api/characters", requiresAuth: true)
    static let createCharacter = APIEndpoint("/api/characters", method: .POST, requiresAuth: true)
    static func updateCharacter(_ id: String) -> APIEndpoint {
        APIEndpoint("/api/characters/\(id)", method: .PUT, requiresAuth: true)
    }
    static func customizationOptions(_ id: String) -> APIEndpoint {
        APIEndpoint("/api/characters/\(id)/customization-options")
    }
    static func customizeCharacter(_ id: String) -> APIEndpoint {
        APIEndpoint("/api/characters/\(id)/customize", method: .POST)
    }
    static func previewPrompt(_ id: String) -> APIEndpoint {
        APIEndpoint("/api/characters/\(id)/preview-prompt")
    }

    // Models
    static let models = APIEndpoint("/api/models")
    static let testModel = APIEndpoint("/api/models/test", method: .POST)
    static let modelsHealth = APIEndpoint("/api/models/health")
    static func modelRecommendations(_ characterId: String) -> APIEndpoint {
        APIEndpoint("/api/models/recommendations/\(characterId)")
    }

    // Conversations
    static let conversations = APIEndpoint("/api/conversations", requiresAuth: true)
    static func conversationMessages(_ id: String) -> APIEndpoint {
        APIEndpoint("/api/conversations/\(id)/messages", requiresAuth: true)
    }
    static let searchConversations = APIEndpoint("/api/conversations/search", requiresAuth: true)
    static func archiveConversation(_ id: String) -> APIEndpoint {
        APIEndpoint("/api/conversations/\(id)/archive", method: .POST, requiresAuth: true)
    }
    static func deleteConversation(_ id: String) -> APIEndpoint {
        APIEndpoint("/api/conversations/\(id)", method: .DELETE, requiresAuth: true)
    }
    static func exportConversation(_ id: String) -> APIEndpoint {
        APIEndpoint("/api/conversations/\(id)/export", requiresAuth: true)
    }

    // Profile
    static let profile = APIEndpoint("/api/profile", requiresAuth: true)
    static let updateProfile = APIEndpoint("/api/profile", method: .PUT, requiresAuth: true)
    static let exportData = APIEndpoint("/api/export-data", requiresAuth: true)
    static let clearData = APIEndpoint("/api/clear-data", method: .DELETE, requiresAuth: true)

    // Feedback
    static func feedback(_ memoryId: String) -> APIEndpoint {
        APIEndpoint("/api/feedback/\(memoryId)", method: .POST, requiresAuth: true)
    }

    // Payment
    static let createCheckoutSession = APIEndpoint("/api/create-checkout-session", method: .POST)
}

// MARK: - API Client

public final class APIClient {
    public static let shared = APIClient()

    private var configuration: APIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public var authToken: String? {
        get { configuration.authToken }
        set { configuration.authToken = newValue }
    }

    public var sessionId: String? {
        get { configuration.sessionId }
        set { configuration.sessionId = newValue }
    }

    public var baseURL: URL {
        configuration.baseURL
    }

    public init(configuration: APIConfiguration = .production, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public func configure(with configuration: APIConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Generic Request Methods

    public func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil
    ) -> AnyPublisher<T, APIError> {
        guard var urlComponents = URLComponents(url: configuration.baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true) else {
            return Fail(error: .invalidURL).eraseToAnyPublisher()
        }

        if let queryItems = queryItems, !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            return Fail(error: .invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add auth token if required
        if endpoint.requiresAuth {
            guard let token = authToken else {
                return Fail(error: .unauthorized).eraseToAnyPublisher()
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let token = authToken {
            // Add token even for non-required endpoints if available
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add session ID if available
        if let sessionId = sessionId {
            request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
        }

        // Encode body
        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                return Fail(error: .encodingError(error)).eraseToAnyPublisher()
            }
        }

        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response in
                try self?.handleResponse(data: data, response: response) ?? data
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return .networkError(error)
            }
            .flatMap { [weak self] data -> AnyPublisher<T, APIError> in
                guard let self = self else {
                    return Fail(error: .unknown).eraseToAnyPublisher()
                }
                do {
                    let decoded = try self.decoder.decode(T.self, from: data)
                    return Just(decoded)
                        .setFailureType(to: APIError.self)
                        .eraseToAnyPublisher()
                } catch {
                    return Fail(error: .decodingError(error)).eraseToAnyPublisher()
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Async/Await Support

    @available(iOS 15.0, macOS 12.0, *)
    public func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        guard var urlComponents = URLComponents(url: configuration.baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true) else {
            throw APIError.invalidURL
        }

        if let queryItems = queryItems, !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if endpoint.requiresAuth {
            guard let token = authToken else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let sessionId = sessionId {
            request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
        }

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        let validatedData = try handleResponse(data: data, response: response)
        return try decoder.decode(T.self, from: validatedData)
    }

    // MARK: - Raw Data Request

    public func requestData(
        _ endpoint: APIEndpoint,
        queryItems: [URLQueryItem]? = nil
    ) -> AnyPublisher<Data, APIError> {
        guard var urlComponents = URLComponents(url: configuration.baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true) else {
            return Fail(error: .invalidURL).eraseToAnyPublisher()
        }

        if let queryItems = queryItems, !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            return Fail(error: .invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        if endpoint.requiresAuth {
            guard let token = authToken else {
                return Fail(error: .unauthorized).eraseToAnyPublisher()
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response in
                try self?.handleResponse(data: data, response: response) ?? data
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return .networkError(error)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Response Handling

    private func handleResponse(data: Data, response: URLResponse) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Extract session ID from response headers
        if let newSessionId = httpResponse.value(forHTTPHeaderField: "X-Session-ID") {
            self.sessionId = newSessionId
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data

        case 401:
            throw APIError.unauthorized

        case 403:
            // Check for email verification error
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                if errorResponse.requiresVerification == true, let email = errorResponse.email {
                    throw APIError.emailNotVerified(email: email)
                }
                throw APIError.forbidden(errorResponse.error)
            }
            throw APIError.forbidden("Access forbidden")

        case 404:
            throw APIError.notFound

        case 400...499:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorResponse.error)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: nil)

        case 500...599:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorResponse.error)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Internal server error")

        default:
            throw APIError.unknown
        }
    }
}

// MARK: - Request Builder (Fluent API)

public class RequestBuilder<T: Decodable> {
    private let client: APIClient
    private let endpoint: APIEndpoint
    private var body: Encodable?
    private var queryItems: [URLQueryItem] = []

    init(client: APIClient, endpoint: APIEndpoint) {
        self.client = client
        self.endpoint = endpoint
    }

    @discardableResult
    public func body(_ body: Encodable) -> Self {
        self.body = body
        return self
    }

    @discardableResult
    public func query(_ items: [URLQueryItem]) -> Self {
        self.queryItems.append(contentsOf: items)
        return self
    }

    @discardableResult
    public func query(_ key: String, _ value: String?) -> Self {
        if let value = value {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        return self
    }

    public func execute() -> AnyPublisher<T, APIError> {
        client.request(endpoint, body: body, queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func execute() async throws -> T {
        try await client.request(endpoint, body: body, queryItems: queryItems.isEmpty ? nil : queryItems)
    }
}

// MARK: - APIClient Extension for Fluent API

extension APIClient {
    public func request<T: Decodable>(_ endpoint: APIEndpoint) -> RequestBuilder<T> {
        RequestBuilder(client: self, endpoint: endpoint)
    }
}
