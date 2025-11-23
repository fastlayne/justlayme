import Foundation
import Combine

// MARK: - Settings Keys

public enum SettingsKey: String, CaseIterable {
    // User
    case currentUserId = "currentUserId"
    case authToken = "authToken"
    case tokenExpiry = "tokenExpiry"

    // Preferences
    case theme = "theme"
    case fontSize = "fontSize"
    case notificationsEnabled = "notificationsEnabled"
    case soundEnabled = "soundEnabled"
    case hapticFeedbackEnabled = "hapticFeedbackEnabled"

    // Chat Settings
    case defaultModelType = "defaultModelType"
    case autoSaveConversations = "autoSaveConversations"
    case showTimestamps = "showTimestamps"
    case messagePreviewLength = "messagePreviewLength"

    // Privacy
    case analyticsEnabled = "analyticsEnabled"
    case crashReportingEnabled = "crashReportingEnabled"

    // Sync
    case lastSyncDate = "lastSyncDate"
    case autoSyncEnabled = "autoSyncEnabled"
    case syncOnWifiOnly = "syncOnWifiOnly"

    // Cache
    case cacheEnabled = "cacheEnabled"
    case maxCacheSize = "maxCacheSize"

    // App State
    case hasCompletedOnboarding = "hasCompletedOnboarding"
    case lastOpenedVersion = "lastOpenedVersion"
    case appLaunchCount = "appLaunchCount"
    case firstLaunchDate = "firstLaunchDate"

    // Feature Flags
    case premiumFeaturesUnlocked = "premiumFeaturesUnlocked"
    case betaFeaturesEnabled = "betaFeaturesEnabled"
}

// MARK: - Theme

public enum AppTheme: String, Codable, CaseIterable {
    case system
    case light
    case dark

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// MARK: - Font Size

public enum FontSize: String, Codable, CaseIterable {
    case small
    case medium
    case large
    case extraLarge

    public var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    public var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.15
        case .extraLarge: return 1.3
        }
    }
}

// MARK: - User Defaults Manager

@propertyWrapper
public struct UserDefault<T> {
    let key: SettingsKey
    let defaultValue: T
    let userDefaults: UserDefaults

    public var wrappedValue: T {
        get {
            userDefaults.object(forKey: key.rawValue) as? T ?? defaultValue
        }
        set {
            if let optional = newValue as? OptionalProtocol, optional.isNil {
                userDefaults.removeObject(forKey: key.rawValue)
            } else {
                userDefaults.set(newValue, forKey: key.rawValue)
            }
        }
    }

    public init(key: SettingsKey, defaultValue: T, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }
}

// Protocol to check for nil optional values
private protocol OptionalProtocol {
    var isNil: Bool { get }
}

extension Optional: OptionalProtocol {
    var isNil: Bool { self == nil }
}

// MARK: - Settings Manager

public final class SettingsManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = SettingsManager()

    // MARK: - User Defaults

    private let userDefaults: UserDefaults
    private let keychain: KeychainManager

    // MARK: - Publishers

    private var cancellables = Set<AnyCancellable>()

    // MARK: - User Settings

    @Published public var currentUserId: UUID? {
        didSet {
            if let id = currentUserId {
                userDefaults.set(id.uuidString, forKey: SettingsKey.currentUserId.rawValue)
            } else {
                userDefaults.removeObject(forKey: SettingsKey.currentUserId.rawValue)
            }
        }
    }

    public var authToken: String? {
        get { keychain.get(key: SettingsKey.authToken.rawValue) }
        set {
            if let value = newValue {
                keychain.set(value, key: SettingsKey.authToken.rawValue)
            } else {
                keychain.delete(key: SettingsKey.authToken.rawValue)
            }
            objectWillChange.send()
        }
    }

    @Published public var tokenExpiry: Date? {
        didSet { userDefaults.set(tokenExpiry, forKey: SettingsKey.tokenExpiry.rawValue) }
    }

    // MARK: - Appearance Settings

    @Published public var theme: AppTheme = .system {
        didSet { userDefaults.set(theme.rawValue, forKey: SettingsKey.theme.rawValue) }
    }

    @Published public var fontSize: FontSize = .medium {
        didSet { userDefaults.set(fontSize.rawValue, forKey: SettingsKey.fontSize.rawValue) }
    }

    // MARK: - Notification Settings

    @Published public var notificationsEnabled: Bool = true {
        didSet { userDefaults.set(notificationsEnabled, forKey: SettingsKey.notificationsEnabled.rawValue) }
    }

    @Published public var soundEnabled: Bool = true {
        didSet { userDefaults.set(soundEnabled, forKey: SettingsKey.soundEnabled.rawValue) }
    }

    @Published public var hapticFeedbackEnabled: Bool = true {
        didSet { userDefaults.set(hapticFeedbackEnabled, forKey: SettingsKey.hapticFeedbackEnabled.rawValue) }
    }

    // MARK: - Chat Settings

    @Published public var defaultModelType: ModelType = .layme_v1 {
        didSet { userDefaults.set(defaultModelType.rawValue, forKey: SettingsKey.defaultModelType.rawValue) }
    }

    @Published public var autoSaveConversations: Bool = true {
        didSet { userDefaults.set(autoSaveConversations, forKey: SettingsKey.autoSaveConversations.rawValue) }
    }

    @Published public var showTimestamps: Bool = true {
        didSet { userDefaults.set(showTimestamps, forKey: SettingsKey.showTimestamps.rawValue) }
    }

    @Published public var messagePreviewLength: Int = 100 {
        didSet { userDefaults.set(messagePreviewLength, forKey: SettingsKey.messagePreviewLength.rawValue) }
    }

    // MARK: - Privacy Settings

    @Published public var analyticsEnabled: Bool = true {
        didSet { userDefaults.set(analyticsEnabled, forKey: SettingsKey.analyticsEnabled.rawValue) }
    }

    @Published public var crashReportingEnabled: Bool = true {
        didSet { userDefaults.set(crashReportingEnabled, forKey: SettingsKey.crashReportingEnabled.rawValue) }
    }

    // MARK: - Sync Settings

    @Published public var lastSyncDate: Date? {
        didSet { userDefaults.set(lastSyncDate, forKey: SettingsKey.lastSyncDate.rawValue) }
    }

    @Published public var autoSyncEnabled: Bool = true {
        didSet { userDefaults.set(autoSyncEnabled, forKey: SettingsKey.autoSyncEnabled.rawValue) }
    }

    @Published public var syncOnWifiOnly: Bool = false {
        didSet { userDefaults.set(syncOnWifiOnly, forKey: SettingsKey.syncOnWifiOnly.rawValue) }
    }

    // MARK: - Cache Settings

    @Published public var cacheEnabled: Bool = true {
        didSet { userDefaults.set(cacheEnabled, forKey: SettingsKey.cacheEnabled.rawValue) }
    }

    @Published public var maxCacheSize: Int64 = 50 * 1024 * 1024 { // 50 MB
        didSet { userDefaults.set(maxCacheSize, forKey: SettingsKey.maxCacheSize.rawValue) }
    }

    // MARK: - App State

    @Published public var hasCompletedOnboarding: Bool = false {
        didSet { userDefaults.set(hasCompletedOnboarding, forKey: SettingsKey.hasCompletedOnboarding.rawValue) }
    }

    @Published public var lastOpenedVersion: String? {
        didSet { userDefaults.set(lastOpenedVersion, forKey: SettingsKey.lastOpenedVersion.rawValue) }
    }

    @Published public var appLaunchCount: Int = 0 {
        didSet { userDefaults.set(appLaunchCount, forKey: SettingsKey.appLaunchCount.rawValue) }
    }

    @Published public var firstLaunchDate: Date? {
        didSet { userDefaults.set(firstLaunchDate, forKey: SettingsKey.firstLaunchDate.rawValue) }
    }

    // MARK: - Feature Flags

    @Published public var premiumFeaturesUnlocked: Bool = false {
        didSet { userDefaults.set(premiumFeaturesUnlocked, forKey: SettingsKey.premiumFeaturesUnlocked.rawValue) }
    }

    @Published public var betaFeaturesEnabled: Bool = false {
        didSet { userDefaults.set(betaFeaturesEnabled, forKey: SettingsKey.betaFeaturesEnabled.rawValue) }
    }

    // MARK: - Initialization

    private init(userDefaults: UserDefaults = .standard, keychain: KeychainManager = .shared) {
        self.userDefaults = userDefaults
        self.keychain = keychain
        loadSettings()
    }

    private func loadSettings() {
        // User
        if let idString = userDefaults.string(forKey: SettingsKey.currentUserId.rawValue) {
            currentUserId = UUID(uuidString: idString)
        }
        tokenExpiry = userDefaults.object(forKey: SettingsKey.tokenExpiry.rawValue) as? Date

        // Appearance
        if let themeRaw = userDefaults.string(forKey: SettingsKey.theme.rawValue) {
            theme = AppTheme(rawValue: themeRaw) ?? .system
        }
        if let fontRaw = userDefaults.string(forKey: SettingsKey.fontSize.rawValue) {
            fontSize = FontSize(rawValue: fontRaw) ?? .medium
        }

        // Notifications
        notificationsEnabled = userDefaults.object(forKey: SettingsKey.notificationsEnabled.rawValue) as? Bool ?? true
        soundEnabled = userDefaults.object(forKey: SettingsKey.soundEnabled.rawValue) as? Bool ?? true
        hapticFeedbackEnabled = userDefaults.object(forKey: SettingsKey.hapticFeedbackEnabled.rawValue) as? Bool ?? true

        // Chat
        if let modelRaw = userDefaults.string(forKey: SettingsKey.defaultModelType.rawValue) {
            defaultModelType = ModelType(rawValue: modelRaw) ?? .layme_v1
        }
        autoSaveConversations = userDefaults.object(forKey: SettingsKey.autoSaveConversations.rawValue) as? Bool ?? true
        showTimestamps = userDefaults.object(forKey: SettingsKey.showTimestamps.rawValue) as? Bool ?? true
        messagePreviewLength = userDefaults.object(forKey: SettingsKey.messagePreviewLength.rawValue) as? Int ?? 100

        // Privacy
        analyticsEnabled = userDefaults.object(forKey: SettingsKey.analyticsEnabled.rawValue) as? Bool ?? true
        crashReportingEnabled = userDefaults.object(forKey: SettingsKey.crashReportingEnabled.rawValue) as? Bool ?? true

        // Sync
        lastSyncDate = userDefaults.object(forKey: SettingsKey.lastSyncDate.rawValue) as? Date
        autoSyncEnabled = userDefaults.object(forKey: SettingsKey.autoSyncEnabled.rawValue) as? Bool ?? true
        syncOnWifiOnly = userDefaults.object(forKey: SettingsKey.syncOnWifiOnly.rawValue) as? Bool ?? false

        // Cache
        cacheEnabled = userDefaults.object(forKey: SettingsKey.cacheEnabled.rawValue) as? Bool ?? true
        maxCacheSize = userDefaults.object(forKey: SettingsKey.maxCacheSize.rawValue) as? Int64 ?? (50 * 1024 * 1024)

        // App State
        hasCompletedOnboarding = userDefaults.object(forKey: SettingsKey.hasCompletedOnboarding.rawValue) as? Bool ?? false
        lastOpenedVersion = userDefaults.string(forKey: SettingsKey.lastOpenedVersion.rawValue)
        appLaunchCount = userDefaults.object(forKey: SettingsKey.appLaunchCount.rawValue) as? Int ?? 0
        firstLaunchDate = userDefaults.object(forKey: SettingsKey.firstLaunchDate.rawValue) as? Date

        // Features
        premiumFeaturesUnlocked = userDefaults.object(forKey: SettingsKey.premiumFeaturesUnlocked.rawValue) as? Bool ?? false
        betaFeaturesEnabled = userDefaults.object(forKey: SettingsKey.betaFeaturesEnabled.rawValue) as? Bool ?? false
    }

    // MARK: - Authentication

    public var isLoggedIn: Bool {
        authToken != nil && currentUserId != nil
    }

    public var isTokenValid: Bool {
        guard authToken != nil else { return false }
        guard let expiry = tokenExpiry else { return true }
        return expiry > Date()
    }

    public func setAuth(token: String, userId: UUID, expiry: Date? = nil) {
        authToken = token
        currentUserId = userId
        tokenExpiry = expiry
    }

    public func clearAuth() {
        authToken = nil
        currentUserId = nil
        tokenExpiry = nil
    }

    // MARK: - Reset

    public func resetToDefaults() {
        // Clear all settings except auth
        theme = .system
        fontSize = .medium
        notificationsEnabled = true
        soundEnabled = true
        hapticFeedbackEnabled = true
        defaultModelType = .layme_v1
        autoSaveConversations = true
        showTimestamps = true
        messagePreviewLength = 100
        analyticsEnabled = true
        crashReportingEnabled = true
        autoSyncEnabled = true
        syncOnWifiOnly = false
        cacheEnabled = true
        maxCacheSize = 50 * 1024 * 1024
        betaFeaturesEnabled = false
    }

    public func clearAllData() {
        // Clear everything
        for key in SettingsKey.allCases {
            userDefaults.removeObject(forKey: key.rawValue)
        }
        keychain.deleteAll()
        loadSettings()
    }

    // MARK: - App Launch Tracking

    public func recordAppLaunch() {
        appLaunchCount += 1

        if firstLaunchDate == nil {
            firstLaunchDate = Date()
        }

        if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            lastOpenedVersion = currentVersion
        }
    }

    // MARK: - Export Settings

    public func exportSettings() -> [String: Any] {
        var settings: [String: Any] = [:]

        settings["theme"] = theme.rawValue
        settings["fontSize"] = fontSize.rawValue
        settings["notificationsEnabled"] = notificationsEnabled
        settings["soundEnabled"] = soundEnabled
        settings["hapticFeedbackEnabled"] = hapticFeedbackEnabled
        settings["defaultModelType"] = defaultModelType.rawValue
        settings["autoSaveConversations"] = autoSaveConversations
        settings["showTimestamps"] = showTimestamps
        settings["messagePreviewLength"] = messagePreviewLength
        settings["analyticsEnabled"] = analyticsEnabled
        settings["crashReportingEnabled"] = crashReportingEnabled
        settings["autoSyncEnabled"] = autoSyncEnabled
        settings["syncOnWifiOnly"] = syncOnWifiOnly
        settings["cacheEnabled"] = cacheEnabled
        settings["maxCacheSize"] = maxCacheSize

        return settings
    }

    public func importSettings(_ settings: [String: Any]) {
        if let themeRaw = settings["theme"] as? String, let theme = AppTheme(rawValue: themeRaw) {
            self.theme = theme
        }
        if let fontRaw = settings["fontSize"] as? String, let fontSize = FontSize(rawValue: fontRaw) {
            self.fontSize = fontSize
        }
        if let value = settings["notificationsEnabled"] as? Bool { notificationsEnabled = value }
        if let value = settings["soundEnabled"] as? Bool { soundEnabled = value }
        if let value = settings["hapticFeedbackEnabled"] as? Bool { hapticFeedbackEnabled = value }
        if let modelRaw = settings["defaultModelType"] as? String, let model = ModelType(rawValue: modelRaw) {
            defaultModelType = model
        }
        if let value = settings["autoSaveConversations"] as? Bool { autoSaveConversations = value }
        if let value = settings["showTimestamps"] as? Bool { showTimestamps = value }
        if let value = settings["messagePreviewLength"] as? Int { messagePreviewLength = value }
        if let value = settings["analyticsEnabled"] as? Bool { analyticsEnabled = value }
        if let value = settings["crashReportingEnabled"] as? Bool { crashReportingEnabled = value }
        if let value = settings["autoSyncEnabled"] as? Bool { autoSyncEnabled = value }
        if let value = settings["syncOnWifiOnly"] as? Bool { syncOnWifiOnly = value }
        if let value = settings["cacheEnabled"] as? Bool { cacheEnabled = value }
        if let value = settings["maxCacheSize"] as? Int64 { maxCacheSize = value }
    }
}

// MARK: - Keychain Manager

public final class KeychainManager {

    public static let shared = KeychainManager()

    private let service = "com.justlayme.app"

    private init() {}

    public func set(_ value: String, key: String) {
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    public func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    public func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    public func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        SecItemDelete(query as CFDictionary)
    }
}
