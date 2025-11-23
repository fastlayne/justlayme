import Foundation
import Combine

// MARK: - Network Error

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case noData
    case unauthorized
    case forbidden
    case notFound
    case serverError
    case networkUnavailable
    case timeout
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return message ?? "HTTP Error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error. Please try again later."
        case .networkUnavailable:
            return "Network unavailable. Check your connection."
        case .timeout:
            return "Request timed out"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Network Service Protocol

protocol NetworkServiceProtocol {
    func request<T: Decodable>(
        endpoint: APIEndpoint,
        method: HTTPMethod,
        body: Encodable?,
        headers: [String: String]?
    ) async throws -> T

    func request(
        endpoint: APIEndpoint,
        method: HTTPMethod,
        body: Encodable?,
        headers: [String: String]?
    ) async throws -> Data
}

// MARK: - Network Service

final class NetworkService: NetworkServiceProtocol {
    // MARK: - Singleton

    static let shared = NetworkService()

    // MARK: - Properties

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Initialization

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = AppConfig.requestTimeout
        configuration.timeoutIntervalForResource = AppConfig.resourceTimeout
        configuration.waitsForConnectivity = true

        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try multiple date formats
            let formatters: [DateFormatter] = [
                ISO8601DateFormatter.withFractionalSeconds,
                ISO8601DateFormatter.standard,
                DateFormatter.apiDateFormatter
            ].compactMap { $0 as? DateFormatter }

            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            // Try ISO8601
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Public Methods

    func request<T: Decodable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        let data = try await request(
            endpoint: endpoint,
            method: method,
            body: body,
            headers: headers
        )

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    func request(
        endpoint: APIEndpoint,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) async throws -> Data {
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Set default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add auth token if available
        if let token = KeychainService.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Encode body
        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw NetworkError.encodingError(error)
            }
        }

        // Perform request
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw NetworkError.networkUnavailable
            case .timedOut:
                throw NetworkError.timeout
            default:
                throw NetworkError.unknown(error)
            }
        }

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            // Post notification for unauthorized
            NotificationCenter.default.post(name: .userDidLogout, object: nil)
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 500...599:
            throw NetworkError.serverError
        default:
            let message = try? decoder.decode(ErrorResponse.self, from: data).message
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

// MARK: - Error Response

struct ErrorResponse: Codable {
    let error: String?
    let message: String?
}

// MARK: - Date Formatters

private extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension DateFormatter {
    static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
