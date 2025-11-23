import Foundation

// MARK: - API Client

protocol APIClientProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
    func requestVoid(_ endpoint: APIEndpoint) async throws
}

class APIClient: APIClientProtocol {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private var authToken: String?
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://justlay.me")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let formatters = [
                ISO8601DateFormatter(),
                Self.makeFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSZ"),
                Self.makeFormatter("yyyy-MM-dd'T'HH:mm:ssZ"),
                Self.makeFormatter("yyyy-MM-dd")
            ]

            for formatter in formatters {
                if let iso = formatter as? ISO8601DateFormatter,
                   let date = iso.date(from: dateString) {
                    return date
                }
                if let df = formatter as? DateFormatter,
                   let date = df.date(from: dateString) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
    }

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let request = try buildRequest(for: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        try validateResponse(httpResponse, data: data)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    func requestVoid(_ endpoint: APIEndpoint) async throws {
        let request = try buildRequest(for: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        try validateResponse(httpResponse, data: data)
    }

    private func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)

        if let queryItems = endpoint.queryItems {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIError.invalidURL(endpoint.path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if endpoint.requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let sessionId = endpoint.sessionId {
            request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
        }

        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }

    private func validateResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 400:
            throw APIError.badRequest(parseErrorMessage(from: data))
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden(parseErrorMessage(from: data))
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError(response.statusCode)
        default:
            throw APIError.unknown(response.statusCode)
        }
    }

    private func parseErrorMessage(from data: Data) -> String {
        if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
            return errorResponse.error
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}

// MARK: - Error Response

struct ErrorResponse: Decodable {
    let error: String
}

// MARK: - API Error

enum APIError: Error, Equatable, LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case badRequest(String)
    case unauthorized
    case forbidden(String)
    case notFound
    case serverError(Int)
    case unknown(Int)
    case decodingFailed(Error)
    case networkError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            return "Invalid URL: \(path)"
        case .invalidResponse:
            return "Invalid server response"
        case .badRequest(let message):
            return message
        case .unauthorized:
            return "Please log in to continue"
        case .forbidden(let message):
            return message
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error (\(code))"
        case .unknown(let code):
            return "Unknown error (\(code))"
        case .decodingFailed(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        }
    }

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL(let l), .invalidURL(let r)): return l == r
        case (.invalidResponse, .invalidResponse): return true
        case (.badRequest(let l), .badRequest(let r)): return l == r
        case (.unauthorized, .unauthorized): return true
        case (.forbidden(let l), .forbidden(let r)): return l == r
        case (.notFound, .notFound): return true
        case (.serverError(let l), .serverError(let r)): return l == r
        case (.unknown(let l), .unknown(let r)): return l == r
        case (.noData, .noData): return true
        default: return false
        }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
    case PATCH
}

// MARK: - API Endpoint

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let body: Encodable?
    let queryItems: [URLQueryItem]?
    let requiresAuth: Bool
    let sessionId: String?

    init(
        path: String,
        method: HTTPMethod = .GET,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = false,
        sessionId: String? = nil
    ) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
        self.requiresAuth = requiresAuth
        self.sessionId = sessionId
    }
}

// MARK: - Endpoint Definitions

extension APIEndpoint {
    // Auth endpoints
    static func register(email: String, password: String) -> APIEndpoint {
        struct Body: Encodable { let email: String; let password: String }
        return APIEndpoint(path: "/api/register", method: .POST, body: Body(email: email, password: password))
    }

    static func login(email: String, password: String) -> APIEndpoint {
        struct Body: Encodable { let email: String; let password: String }
        return APIEndpoint(path: "/api/login", method: .POST, body: Body(email: email, password: password))
    }

    static func verifyToken() -> APIEndpoint {
        APIEndpoint(path: "/api/verify", requiresAuth: true)
    }

    static func verifyEmail(token: String) -> APIEndpoint {
        APIEndpoint(path: "/api/verify-email", queryItems: [URLQueryItem(name: "token", value: token)])
    }

    static func resendVerification(email: String) -> APIEndpoint {
        struct Body: Encodable { let email: String }
        return APIEndpoint(path: "/api/resend-verification", method: .POST, body: Body(email: email))
    }

    static func googleAuth(credential: String) -> APIEndpoint {
        struct Body: Encodable { let credential: String }
        return APIEndpoint(path: "/api/auth/google", method: .POST, body: Body(credential: credential))
    }

    // Chat endpoints
    static func chat(message: String, characterId: String, userId: String?, sessionId: String?) -> APIEndpoint {
        struct Body: Encodable {
            let message: String
            let character_id: String
            let user_id: String?
        }
        return APIEndpoint(
            path: "/api/chat",
            method: .POST,
            body: Body(message: message, character_id: characterId, user_id: userId),
            sessionId: sessionId
        )
    }

    // Character endpoints
    static func getCharacters() -> APIEndpoint {
        APIEndpoint(path: "/api/characters", requiresAuth: true)
    }

    static func createCharacter(name: String, backstory: String?, traits: [String: Int]?, patterns: [String]?) -> APIEndpoint {
        struct Body: Encodable {
            let name: String
            let backstory: String?
            let personality_traits: [String: Int]?
            let speech_patterns: [String]?
        }
        return APIEndpoint(
            path: "/api/characters",
            method: .POST,
            body: Body(name: name, backstory: backstory, personality_traits: traits, speech_patterns: patterns),
            requiresAuth: true
        )
    }

    static func updateCharacter(id: String, backstory: String?, traits: [String: Int]?, patterns: [String]?) -> APIEndpoint {
        struct Body: Encodable {
            let backstory: String?
            let personality_traits: [String: Int]?
            let speech_patterns: [String]?
        }
        return APIEndpoint(
            path: "/api/characters/\(id)",
            method: .PUT,
            body: Body(backstory: backstory, personality_traits: traits, speech_patterns: patterns),
            requiresAuth: true
        )
    }

    static func customizationOptions(characterId: String) -> APIEndpoint {
        APIEndpoint(path: "/api/characters/\(characterId)/customization-options")
    }

    // Conversation endpoints
    static func getConversations() -> APIEndpoint {
        APIEndpoint(path: "/api/conversations", requiresAuth: true)
    }

    static func getConversationMessages(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/conversations/\(id)/messages", requiresAuth: true)
    }

    static func searchConversations(query: String) -> APIEndpoint {
        APIEndpoint(
            path: "/api/conversations/search",
            queryItems: [URLQueryItem(name: "q", value: query)],
            requiresAuth: true
        )
    }

    static func archiveConversation(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/conversations/\(id)/archive", method: .POST, requiresAuth: true)
    }

    static func deleteConversation(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/conversations/\(id)", method: .DELETE, requiresAuth: true)
    }

    static func exportConversation(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/conversations/\(id)/export", requiresAuth: true)
    }

    // Profile endpoints
    static func getProfile() -> APIEndpoint {
        APIEndpoint(path: "/api/profile", requiresAuth: true)
    }

    static func updateProfile(name: String?) -> APIEndpoint {
        struct Body: Encodable { let name: String? }
        return APIEndpoint(path: "/api/profile", method: .PUT, body: Body(name: name), requiresAuth: true)
    }

    static func exportData() -> APIEndpoint {
        APIEndpoint(path: "/api/export-data", requiresAuth: true)
    }

    static func clearData() -> APIEndpoint {
        APIEndpoint(path: "/api/clear-data", method: .DELETE, requiresAuth: true)
    }

    // Model endpoints
    static func getModels() -> APIEndpoint {
        APIEndpoint(path: "/api/models")
    }

    static func getModelRecommendations(characterId: String, userId: String?) -> APIEndpoint {
        var queryItems = [URLQueryItem]()
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: userId))
        }
        return APIEndpoint(
            path: "/api/models/recommendations/\(characterId)",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    // Payment endpoints
    static func createCheckoutSession(plan: String, userId: String?, email: String?) -> APIEndpoint {
        struct Body: Encodable {
            let plan: String
            let user_id: String?
            let user_email: String?
        }
        return APIEndpoint(
            path: "/api/create-checkout-session",
            method: .POST,
            body: Body(plan: plan, user_id: userId, user_email: email)
        )
    }
}
