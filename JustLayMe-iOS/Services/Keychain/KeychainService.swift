import Foundation
import Security

// MARK: - Keychain Service

final class KeychainService {
    // MARK: - Singleton

    static let shared = KeychainService()

    // MARK: - Keys

    private enum Keys {
        static let authToken = AppConfig.KeychainKey.authToken
        static let refreshToken = AppConfig.KeychainKey.refreshToken
        static let userId = AppConfig.KeychainKey.userId
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Auth Token

    func saveAuthToken(_ token: String) {
        save(key: Keys.authToken, value: token)
    }

    func getAuthToken() -> String? {
        return get(key: Keys.authToken)
    }

    func deleteAuthToken() {
        delete(key: Keys.authToken)
    }

    // MARK: - Refresh Token

    func saveRefreshToken(_ token: String) {
        save(key: Keys.refreshToken, value: token)
    }

    func getRefreshToken() -> String? {
        return get(key: Keys.refreshToken)
    }

    func deleteRefreshToken() {
        delete(key: Keys.refreshToken)
    }

    // MARK: - User ID

    func saveUserId(_ userId: String) {
        save(key: Keys.userId, value: userId)
    }

    func getUserId() -> String? {
        return get(key: Keys.userId)
    }

    func deleteUserId() {
        delete(key: Keys.userId)
    }

    // MARK: - Clear All Auth Data

    func clearAuthData() {
        deleteAuthToken()
        deleteRefreshToken()
        deleteUserId()
    }

    // MARK: - Generic Methods

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("Keychain save error for key \(key): \(status)")
        }
    }

    private func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    func exists(key: String) -> Bool {
        return get(key: key) != nil
    }

    func update(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            save(key: key, value: value)
        } else if status != errSecSuccess {
            print("Keychain update error for key \(key): \(status)")
        }
    }
}

// MARK: - Keychain Error

enum KeychainError: LocalizedError {
    case saveError(OSStatus)
    case readError(OSStatus)
    case deleteError(OSStatus)
    case dataConversionError

    var errorDescription: String? {
        switch self {
        case .saveError(let status):
            return "Failed to save to keychain: \(status)"
        case .readError(let status):
            return "Failed to read from keychain: \(status)"
        case .deleteError(let status):
            return "Failed to delete from keychain: \(status)"
        case .dataConversionError:
            return "Failed to convert data"
        }
    }
}
