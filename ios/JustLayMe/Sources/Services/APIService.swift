// APIService.swift
// JustLayMe iOS - API Communication Layer
// Matches web implementation at justlay.me

import Foundation
import Combine

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case premiumRequired
    case messageLimitReached
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .decodingError(let error): return "Data error: \(error.localizedDescription)"
        case .serverError(let message): return message
        case .unauthorized: return "Please log in to continue"
        case .premiumRequired: return "Premium subscription required"
        case .messageLimitReached: return "Message limit reached. Upgrade to Premium for unlimited messages."
        case .unknown: return "An unknown error occurred"
        }
    }
}

// MARK: - API Service

class APIService: ObservableObject {
    static let shared = APIService()

    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isLoading = false

    private var baseURL: String
    private var authToken: String?
    private var sessionId: String?
    private var cancellables = Set<AnyCancellable>()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    init(baseURL: String = "https://justlay.me") {
        self.baseURL = baseURL
        loadAuthToken()
    }

    // MARK: - Configuration

    func configure(baseURL: String) {
        self.baseURL = baseURL
        checkConnection()
    }

    func setAuthToken(_ token: String?) {
        self.authToken = token
        if let token = token {
            UserDefaults.standard.set(token, forKey: "authToken")
        } else {
            UserDefaults.standard.removeObject(forKey: "authToken")
        }
    }

    private func loadAuthToken() {
        authToken = UserDefaults.standard.string(forKey: "authToken")
    }

    // MARK: - Connection Check

    func checkConnection() {
        connectionStatus = .connecting

        guard let url = URL(string: "\(baseURL)/api/models") else {
            connectionStatus = .error("Invalid URL")
            return
        }

        URLSession.shared.dataTaskPublisher(for: url)
            .map { _ in ConnectionStatus.connected }
            .catch { error -> Just<ConnectionStatus> in
                Just(.error(error.localizedDescription))
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.connectionStatus = status
            }
            .store(in: &cancellables)
    }

    // MARK: - Authentication

    func login(email: String, password: String) -> AnyPublisher<LoginResponse, APIError> {
        let body = ["email": email, "password": password]
        return post(endpoint: "/api/login", body: body)
            .handleEvents(receiveOutput: { [weak self] response in
                self?.setAuthToken(response.token)
            })
            .eraseToAnyPublisher()
    }

    func register(email: String, password: String) -> AnyPublisher<[String: Any], APIError> {
        let body = ["email": email, "password": password]
        return postRaw(endpoint: "/api/register", body: body)
    }

    func logout() {
        setAuthToken(nil)
        sessionId = nil
    }

    // MARK: - Chat

    func sendMessage(
        message: String,
        characterId: String,
        userId: String?
    ) -> AnyPublisher<ChatResponse, APIError> {
        var body: [String: Any] = [
            "message": message,
            "character_id": characterId
        ]

        if let userId = userId {
            body["user_id"] = userId
        }

        var headers: [String: String] = [:]
        if let sessionId = sessionId {
            headers["X-Session-ID"] = sessionId
        }

        return post(endpoint: "/api/chat", body: body, additionalHeaders: headers)
            .handleEvents(receiveOutput: { [weak self] response in
                if let newSessionId = response.sessionId {
                    self?.sessionId = newSessionId
                }
            })
            .eraseToAnyPublisher()
    }

    // MARK: - Streaming Chat (for future streaming implementation)

    func sendMessageStreaming(
        message: String,
        characterId: String,
        userId: String?,
        onChunk: @escaping (String) -> Void
    ) -> AnyPublisher<ChatResponse, APIError> {
        // Currently the web API doesn't support streaming
        // This is a placeholder for when streaming is implemented
        // For now, we'll just use the regular chat endpoint
        return sendMessage(message: message, characterId: characterId, userId: userId)
    }

    // MARK: - Models

    func getModels() -> AnyPublisher<ModelsResponse, APIError> {
        get(endpoint: "/api/models")
    }

    func testModel(modelName: String, prompt: String = "Hello") -> AnyPublisher<[String: Any], APIError> {
        let body = ["model": modelName, "prompt": prompt]
        return postRaw(endpoint: "/api/models/test", body: body)
    }

    // MARK: - Conversations

    func getConversations(
        page: Int = 1,
        limit: Int = 20,
        modelType: String? = nil,
        archived: Bool = false,
        search: String? = nil
    ) -> AnyPublisher<ConversationsResponse, APIError> {
        var queryParams: [String: String] = [
            "page": String(page),
            "limit": String(limit),
            "archived": String(archived)
        ]

        if let modelType = modelType {
            queryParams["model_type"] = modelType
        }

        if let search = search {
            queryParams["search"] = search
        }

        return get(endpoint: "/api/conversations", queryParams: queryParams)
    }

    func getConversationMessages(
        conversationId: String,
        page: Int = 1,
        limit: Int = 50
    ) -> AnyPublisher<MessagesResponse, APIError> {
        let queryParams: [String: String] = [
            "page": String(page),
            "limit": String(limit)
        ]

        return get(endpoint: "/api/conversations/\(conversationId)/messages", queryParams: queryParams)
    }

    func deleteConversation(conversationId: String) -> AnyPublisher<Bool, APIError> {
        delete(endpoint: "/api/conversations/\(conversationId)")
            .map { (_: [String: Any]) in true }
            .eraseToAnyPublisher()
    }

    func archiveConversation(conversationId: String, archive: Bool = true) -> AnyPublisher<Bool, APIError> {
        let body = ["archive": archive]
        return postRaw(endpoint: "/api/conversations/\(conversationId)/archive", body: body)
            .map { _ in true }
            .eraseToAnyPublisher()
    }

    func searchConversations(query: String) -> AnyPublisher<[ServerConversation], APIError> {
        get(endpoint: "/api/conversations/search", queryParams: ["q": query])
            .map { (response: [String: [ServerConversation]]) in
                response["results"] ?? []
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Profile

    func getProfile() -> AnyPublisher<User, APIError> {
        get(endpoint: "/api/profile")
    }

    func updateProfile(name: String, avatarStyle: String?, themePreference: String?) -> AnyPublisher<User, APIError> {
        var body: [String: Any] = ["name": name]
        if let avatarStyle = avatarStyle {
            body["avatar_style"] = avatarStyle
        }
        if let themePreference = themePreference {
            body["theme_preference"] = themePreference
        }

        return putRaw(endpoint: "/api/profile", body: body)
            .tryMap { dict -> User in
                guard let userData = dict["user"] as? [String: Any] else {
                    throw APIError.decodingError(NSError(domain: "", code: 0))
                }
                let data = try JSONSerialization.data(withJSONObject: userData)
                return try JSONDecoder().decode(User.self, from: data)
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError { return apiError }
                return .decodingError(error)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Data Management

    func exportData() -> AnyPublisher<Data, APIError> {
        getRaw(endpoint: "/api/export-data")
    }

    func clearAllData() -> AnyPublisher<Bool, APIError> {
        delete(endpoint: "/api/clear-data")
            .map { (_: [String: Any]) in true }
            .eraseToAnyPublisher()
    }

    // MARK: - Private Helpers

    private func get<T: Decodable>(
        endpoint: String,
        queryParams: [String: String] = [:]
    ) -> AnyPublisher<T, APIError> {
        guard var components = URLComponents(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        if !queryParams.isEmpty {
            components.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addCommonHeaders(to: &request)

        return performRequest(request)
    }

    private func getRaw(endpoint: String) -> AnyPublisher<Data, APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addCommonHeaders(to: &request)

        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .map(\.data)
            .eraseToAnyPublisher()
    }

    private func post<T: Decodable>(
        endpoint: String,
        body: [String: Any],
        additionalHeaders: [String: String] = [:]
    ) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)

        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: APIError.decodingError(error)).eraseToAnyPublisher()
        }

        return performRequest(request)
    }

    private func postRaw(
        endpoint: String,
        body: [String: Any]
    ) -> AnyPublisher<[String: Any], APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: APIError.decodingError(error)).eraseToAnyPublisher()
        }

        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .tryMap { data, response -> [String: Any] in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.unknown
                }

                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }

                if httpResponse.statusCode == 403 {
                    throw APIError.premiumRequired
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw APIError.decodingError(NSError(domain: "", code: 0))
                }

                return json
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError { return apiError }
                return .networkError(error)
            }
            .eraseToAnyPublisher()
    }

    private func putRaw(
        endpoint: String,
        body: [String: Any]
    ) -> AnyPublisher<[String: Any], APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        addCommonHeaders(to: &request)

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: APIError.decodingError(error)).eraseToAnyPublisher()
        }

        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .tryMap { data, _ -> [String: Any] in
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw APIError.decodingError(NSError(domain: "", code: 0))
                }
                return json
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError { return apiError }
                return .networkError(error)
            }
            .eraseToAnyPublisher()
    }

    private func delete<T: Decodable>(endpoint: String) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addCommonHeaders(to: &request)

        return performRequest(request)
    }

    private func addCommonHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) -> AnyPublisher<T, APIError> {
        URLSession.shared.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.unknown
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw APIError.unauthorized
                case 403:
                    // Check if it's a message limit error
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? String,
                       error.contains("limit") {
                        throw APIError.messageLimitReached
                    }
                    throw APIError.premiumRequired
                default:
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? String {
                        throw APIError.serverError(error)
                    }
                    throw APIError.serverError("Server error: \(httpResponse.statusCode)")
                }
            }
            .decode(type: T.self, decoder: decoder)
            .mapError { error -> APIError in
                if let apiError = error as? APIError { return apiError }
                if error is DecodingError { return .decodingError(error) }
                return .networkError(error)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
