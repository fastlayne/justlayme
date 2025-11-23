import Foundation

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    let container: UserDefaults = .standard

    var wrappedValue: T {
        get {
            container.object(forKey: key) as? T ?? defaultValue
        }
        set {
            container.set(newValue, forKey: key)
        }
    }
}

@propertyWrapper
struct CodableUserDefault<T: Codable> {
    let key: String
    let defaultValue: T
    let container: UserDefaults = .standard

    var wrappedValue: T {
        get {
            guard let data = container.data(forKey: key) else { return defaultValue }
            return (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                container.set(data, forKey: key)
            }
        }
    }
}

final class AppSettings {
    static let shared = AppSettings()

    @UserDefault(key: "defaultCharacter", defaultValue: "layme_v1")
    var defaultCharacter: String

    @UserDefault(key: "responseLength", defaultValue: "medium")
    var responseLength: String

    @UserDefault(key: "autoScroll", defaultValue: true)
    var autoScroll: Bool

    @UserDefault(key: "soundNotifications", defaultValue: false)
    var soundNotifications: Bool

    @UserDefault(key: "saveConversations", defaultValue: true)
    var saveConversations: Bool

    @UserDefault(key: "analyticsOptOut", defaultValue: false)
    var analyticsOptOut: Bool

    @UserDefault(key: "avatarStyle", defaultValue: "initials")
    var avatarStyle: String

    @UserDefault(key: "hasCompletedOnboarding", defaultValue: false)
    var hasCompletedOnboarding: Bool

    @UserDefault(key: "lastUsedCharacter", defaultValue: "layme_v1")
    var lastUsedCharacter: String

    private init() {}

    func resetToDefaults() {
        defaultCharacter = "layme_v1"
        responseLength = "medium"
        autoScroll = true
        soundNotifications = false
        saveConversations = true
        analyticsOptOut = false
        avatarStyle = "initials"
    }
}
