import Foundation
import SwiftUI

// MARK: - App Settings Keys
enum SettingsKey: String {
    case avatarStyle
    case themePreference
    case defaultCharacter
    case responseLength
    case autoScroll
    case soundNotifications
    case saveConversations
    case analyticsOptOut
    case onboardingCompleted
    case lastSelectedCharacter
}

// MARK: - Settings Manager
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    // MARK: - Published Properties
    @Published var avatarStyle: String {
        didSet { defaults.set(avatarStyle, forKey: SettingsKey.avatarStyle.rawValue) }
    }

    @Published var themePreference: ThemePreference {
        didSet { defaults.set(themePreference.rawValue, forKey: SettingsKey.themePreference.rawValue) }
    }

    @Published var defaultCharacter: String {
        didSet { defaults.set(defaultCharacter, forKey: SettingsKey.defaultCharacter.rawValue) }
    }

    @Published var responseLength: ResponseLength {
        didSet { defaults.set(responseLength.rawValue, forKey: SettingsKey.responseLength.rawValue) }
    }

    @Published var autoScroll: Bool {
        didSet { defaults.set(autoScroll, forKey: SettingsKey.autoScroll.rawValue) }
    }

    @Published var soundNotifications: Bool {
        didSet { defaults.set(soundNotifications, forKey: SettingsKey.soundNotifications.rawValue) }
    }

    @Published var saveConversations: Bool {
        didSet { defaults.set(saveConversations, forKey: SettingsKey.saveConversations.rawValue) }
    }

    @Published var analyticsOptOut: Bool {
        didSet { defaults.set(analyticsOptOut, forKey: SettingsKey.analyticsOptOut.rawValue) }
    }

    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: SettingsKey.onboardingCompleted.rawValue) }
    }

    @Published var lastSelectedCharacter: String? {
        didSet { defaults.set(lastSelectedCharacter, forKey: SettingsKey.lastSelectedCharacter.rawValue) }
    }

    private init() {
        // Load saved values or use defaults
        self.avatarStyle = defaults.string(forKey: SettingsKey.avatarStyle.rawValue) ?? "default"
        self.themePreference = ThemePreference(rawValue: defaults.string(forKey: SettingsKey.themePreference.rawValue) ?? "") ?? .system
        self.defaultCharacter = defaults.string(forKey: SettingsKey.defaultCharacter.rawValue) ?? PredefinedCharacter.laymeV1.rawValue
        self.responseLength = ResponseLength(rawValue: defaults.string(forKey: SettingsKey.responseLength.rawValue) ?? "") ?? .medium
        self.autoScroll = defaults.object(forKey: SettingsKey.autoScroll.rawValue) as? Bool ?? true
        self.soundNotifications = defaults.object(forKey: SettingsKey.soundNotifications.rawValue) as? Bool ?? true
        self.saveConversations = defaults.object(forKey: SettingsKey.saveConversations.rawValue) as? Bool ?? true
        self.analyticsOptOut = defaults.object(forKey: SettingsKey.analyticsOptOut.rawValue) as? Bool ?? false
        self.onboardingCompleted = defaults.object(forKey: SettingsKey.onboardingCompleted.rawValue) as? Bool ?? false
        self.lastSelectedCharacter = defaults.string(forKey: SettingsKey.lastSelectedCharacter.rawValue)
    }

    func resetToDefaults() {
        avatarStyle = "default"
        themePreference = .system
        defaultCharacter = PredefinedCharacter.laymeV1.rawValue
        responseLength = .medium
        autoScroll = true
        soundNotifications = true
        saveConversations = true
        analyticsOptOut = false
    }
}

// MARK: - Enums
enum ThemePreference: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum ResponseLength: String, CaseIterable {
    case short
    case medium
    case long

    var displayName: String {
        switch self {
        case .short: return "Short"
        case .medium: return "Medium"
        case .long: return "Long"
        }
    }
}
