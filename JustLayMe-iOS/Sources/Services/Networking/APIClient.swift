import Foundation
import Alamofire
import Combine

// MARK: - API Client
final class APIClient {
    static let shared = APIClient()

    private let session: Session
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        self.baseURL = URL(string: AppConfig.baseURL)!

        // Configure session with interceptor
        let interceptor = AuthInterceptor()
        self.session = Session(interceptor: interceptor)

        // Configure decoder for snake_case and dates
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let formatters = [
                ISO8601DateFormatter(),
                {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    return f
                }(),
                {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd"
                    return f
                }()
            ] as [Any]

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

        // Configure encoder
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Generic Request Methods
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint.path)

        var request = try URLRequest(url: url, method: endpoint.method)
        request.headers = endpoint.headers

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // Add session ID if available
        if let sessionId = SessionManager.shared.sessionId {
            request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
        }

        let response = await session.request(request)
            .validate()
            .serializingDecodable(T.self, decoder: decoder)
            .response

        switch response.result {
        case .success(let data):
            return data
        case .failure(let error):
            throw APIError.from(afError: error, response: response.response)
        }
    }

    func requestData(_ endpoint: APIEndpoint) async throws -> Data {
        let url = baseURL.appendingPathComponent(endpoint.path)

        var request = try URLRequest(url: url, method: endpoint.method)
        request.headers = endpoint.headers

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let response = await session.request(request)
            .validate()
            .serializingData()
            .response

        switch response.result {
        case .success(let data):
            return data
        case .failure(let error):
            throw APIError.from(afError: error, response: response.response)
        }
    }

    func requestEmpty(_ endpoint: APIEndpoint) async throws {
        let url = baseURL.appendingPathComponent(endpoint.path)

        var request = try URLRequest(url: url, method: endpoint.method)
        request.headers = endpoint.headers

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let response = await session.request(request)
            .validate()
            .serializingData()
            .response

        if case .failure(let error) = response.result {
            throw APIError.from(afError: error, response: response.response)
        }
    }
}

// MARK: - Auth Interceptor
final class AuthInterceptor: RequestInterceptor {
    func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        var request = urlRequest

        if let token = TokenManager.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        completion(.success(request))
    }

    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        guard let response = request.task?.response as? HTTPURLResponse,
              response.statusCode == 401 else {
            completion(.doNotRetry)
            return
        }

        // Token expired - clear and don't retry
        TokenManager.shared.clearToken()
        completion(.doNotRetry)
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case networkError(Error)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please log in to continue"
        case .forbidden:
            return "You don't have permission to access this resource"
        case .notFound:
            return "The requested resource was not found"
        case .serverError(let code):
            return "Server error (code: \(code))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to process response: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred"
        }
    }

    static func from(afError: AFError, response: HTTPURLResponse?) -> APIError {
        if let statusCode = response?.statusCode {
            switch statusCode {
            case 401: return .unauthorized
            case 403: return .forbidden
            case 404: return .notFound
            case 500...599: return .serverError(statusCode)
            default: break
            }
        }

        if case .responseSerializationFailed(let reason) = afError,
           case .decodingFailed(let error) = reason {
            return .decodingError(error)
        }

        return .networkError(afError)
    }
}

// MARK: - Session Manager
final class SessionManager {
    static let shared = SessionManager()
    private init() {}

    var sessionId: String? {
        get { UserDefaults.standard.string(forKey: "sessionId") }
        set { UserDefaults.standard.set(newValue, forKey: "sessionId") }
    }

    func generateNewSession() -> String {
        let id = UUID().uuidString
        sessionId = id
        return id
    }
}
