import Foundation
import KeychainSwift

// MARK: - Token Manager
final class TokenManager {
    static let shared = TokenManager()

    private let keychain = KeychainSwift()
    private let tokenKey = "authToken"
    private let userKey = "currentUser"

    private init() {
        keychain.synchronizable = false
    }

    // MARK: - Auth Token
    var authToken: String? {
        get { keychain.get(tokenKey) }
        set {
            if let token = newValue {
                keychain.set(token, forKey: tokenKey)
            } else {
                keychain.delete(tokenKey)
            }
        }
    }

    var isAuthenticated: Bool {
        authToken != nil
    }

    func clearToken() {
        keychain.delete(tokenKey)
    }

    // MARK: - Current User
    var currentUser: User? {
        get {
            guard let data = UserDefaults.standard.data(forKey: userKey) else { return nil }
            return try? JSONDecoder().decode(User.self, from: data)
        }
        set {
            if let user = newValue,
               let data = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(data, forKey: userKey)
            } else {
                UserDefaults.standard.removeObject(forKey: userKey)
            }
        }
    }

    func clearUser() {
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    // MARK: - Full Logout
    func clearAll() {
        clearToken()
        clearUser()
        SessionManager.shared.sessionId = nil
    }
}

// MARK: - JWT Decoder (for extracting expiry)
extension TokenManager {
    struct JWTPayload: Codable {
        let id: String?
        let email: String?
        let exp: Int?
        let iat: Int?
    }

    func decodeToken(_ token: String) -> JWTPayload? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        var base64 = String(parts[1])
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        // Replace URL-safe characters
        base64 = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(JWTPayload.self, from: data)
    }

    var isTokenExpired: Bool {
        guard let token = authToken,
              let payload = decodeToken(token),
              let exp = payload.exp else {
            return true
        }
        return Date(timeIntervalSince1970: TimeInterval(exp)) < Date()
    }
}
