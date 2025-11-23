import Foundation
import Combine

// MARK: - Settings ViewModel

@MainActor
class SettingsViewModel: ObservableObject {
    // Appearance
    @Published var isDarkMode: Bool {
        didSet { saveSettings() }
    }
    @Published var useDynamicType: Bool {
        didSet { saveSettings() }
    }

    // Notifications
    @Published var enableNotifications: Bool {
        didSet { saveSettings() }
    }
    @Published var notifyNewFeatures: Bool {
        didSet { saveSettings() }
    }
    @Published var notifyPromotions: Bool {
        didSet { saveSettings() }
    }

    // Chat Settings
    @Published var autoSaveChats: Bool {
        didSet { saveSettings() }
    }
    @Published var showTypingIndicator: Bool {
        didSet { saveSettings() }
    }
    @Published var hapticFeedback: Bool {
        didSet { saveSettings() }
    }
    @Published var messageSoundEnabled: Bool {
        didSet { saveSettings() }
    }

    // Privacy
    @Published var sendAnalytics: Bool {
        didSet { saveSettings() }
    }
    @Published var showOnlineStatus: Bool {
        didSet { saveSettings() }
    }

    // Default Character
    @Published var defaultCharacterType: CharacterType {
        didSet { saveSettings() }
    }

    private let userDefaults: UserDefaults
    private let settingsKey = "com.justlayme.settings"

    var allCharacterTypes: [CharacterType] {
        CharacterType.allCases
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // Load saved settings or use defaults
        let settings = Self.loadSettings(from: userDefaults)
        self.isDarkMode = settings.isDarkMode
        self.useDynamicType = settings.useDynamicType
        self.enableNotifications = settings.enableNotifications
        self.notifyNewFeatures = settings.notifyNewFeatures
        self.notifyPromotions = settings.notifyPromotions
        self.autoSaveChats = settings.autoSaveChats
        self.showTypingIndicator = settings.showTypingIndicator
        self.hapticFeedback = settings.hapticFeedback
        self.messageSoundEnabled = settings.messageSoundEnabled
        self.sendAnalytics = settings.sendAnalytics
        self.showOnlineStatus = settings.showOnlineStatus
        self.defaultCharacterType = settings.defaultCharacterType
    }

    func resetToDefaults() {
        isDarkMode = false
        useDynamicType = true
        enableNotifications = true
        notifyNewFeatures = true
        notifyPromotions = false
        autoSaveChats = true
        showTypingIndicator = true
        hapticFeedback = true
        messageSoundEnabled = true
        sendAnalytics = true
        showOnlineStatus = true
        defaultCharacterType = .laymeV1
    }

    private func saveSettings() {
        let settings = SettingsData(
            isDarkMode: isDarkMode,
            useDynamicType: useDynamicType,
            enableNotifications: enableNotifications,
            notifyNewFeatures: notifyNewFeatures,
            notifyPromotions: notifyPromotions,
            autoSaveChats: autoSaveChats,
            showTypingIndicator: showTypingIndicator,
            hapticFeedback: hapticFeedback,
            messageSoundEnabled: messageSoundEnabled,
            sendAnalytics: sendAnalytics,
            showOnlineStatus: showOnlineStatus,
            defaultCharacterType: defaultCharacterType
        )

        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }

    private static func loadSettings(from userDefaults: UserDefaults) -> SettingsData {
        guard let data = userDefaults.data(forKey: "com.justlayme.settings"),
              let settings = try? JSONDecoder().decode(SettingsData.self, from: data) else {
            return SettingsData.default
        }
        return settings
    }
}

// MARK: - Settings Data

struct SettingsData: Codable, Equatable {
    var isDarkMode: Bool
    var useDynamicType: Bool
    var enableNotifications: Bool
    var notifyNewFeatures: Bool
    var notifyPromotions: Bool
    var autoSaveChats: Bool
    var showTypingIndicator: Bool
    var hapticFeedback: Bool
    var messageSoundEnabled: Bool
    var sendAnalytics: Bool
    var showOnlineStatus: Bool
    var defaultCharacterType: CharacterType

    static let `default` = SettingsData(
        isDarkMode: false,
        useDynamicType: true,
        enableNotifications: true,
        notifyNewFeatures: true,
        notifyPromotions: false,
        autoSaveChats: true,
        showTypingIndicator: true,
        hapticFeedback: true,
        messageSoundEnabled: true,
        sendAnalytics: true,
        showOnlineStatus: true,
        defaultCharacterType: .laymeV1
    )
}

// MARK: - Settings Section

enum SettingsSection: String, CaseIterable, Identifiable {
    case appearance = "Appearance"
    case notifications = "Notifications"
    case chat = "Chat"
    case privacy = "Privacy"
    case about = "About"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .appearance: return "paintbrush.fill"
        case .notifications: return "bell.fill"
        case .chat: return "message.fill"
        case .privacy: return "lock.fill"
        case .about: return "info.circle.fill"
        }
    }
}
