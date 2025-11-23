import XCTest
import Combine
@testable import JustLayMe

@MainActor
final class SettingsViewModelTests: XCTestCase {

    var sut: SettingsViewModel!
    var mockUserDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        mockUserDefaults = UserDefaults(suiteName: "TestDefaults")!
        mockUserDefaults.removePersistentDomain(forName: "TestDefaults")
        sut = SettingsViewModel(userDefaults: mockUserDefaults)
    }

    override func tearDown() {
        mockUserDefaults.removePersistentDomain(forName: "TestDefaults")
        sut = nil
        mockUserDefaults = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testDefaultValues() {
        XCTAssertFalse(sut.isDarkMode)
        XCTAssertTrue(sut.useDynamicType)
        XCTAssertTrue(sut.enableNotifications)
        XCTAssertTrue(sut.notifyNewFeatures)
        XCTAssertFalse(sut.notifyPromotions)
        XCTAssertTrue(sut.autoSaveChats)
        XCTAssertTrue(sut.showTypingIndicator)
        XCTAssertTrue(sut.hapticFeedback)
        XCTAssertTrue(sut.messageSoundEnabled)
        XCTAssertTrue(sut.sendAnalytics)
        XCTAssertTrue(sut.showOnlineStatus)
        XCTAssertEqual(sut.defaultCharacterType, .laymeV1)
    }

    // MARK: - Persistence Tests

    func testDarkModePersistence() {
        // When
        sut.isDarkMode = true

        // Then - create new instance and verify persistence
        let newSut = SettingsViewModel(userDefaults: mockUserDefaults)
        XCTAssertTrue(newSut.isDarkMode)
    }

    func testUseDynamicTypePersistence() {
        // When
        sut.useDynamicType = false

        // Then
        let newSut = SettingsViewModel(userDefaults: mockUserDefaults)
        XCTAssertFalse(newSut.useDynamicType)
    }

    func testNotificationSettingsPersistence() {
        // When
        sut.enableNotifications = false
        sut.notifyNewFeatures = false
        sut.notifyPromotions = true

        // Then
        let newSut = SettingsViewModel(userDefaults: mockUserDefaults)
        XCTAssertFalse(newSut.enableNotifications)
        XCTAssertFalse(newSut.notifyNewFeatures)
        XCTAssertTrue(newSut.notifyPromotions)
    }

    func testChatSettingsPersistence() {
        // When
        sut.autoSaveChats = false
        sut.showTypingIndicator = false
        sut.hapticFeedback = false
        sut.messageSoundEnabled = false

        // Then
        let newSut = SettingsViewModel(userDefaults: mockUserDefaults)
        XCTAssertFalse(newSut.autoSaveChats)
        XCTAssertFalse(newSut.showTypingIndicator)
        XCTAssertFalse(newSut.hapticFeedback)
        XCTAssertFalse(newSut.messageSoundEnabled)
    }

    func testPrivacySettingsPersistence() {
        // When
        sut.sendAnalytics = false
        sut.showOnlineStatus = false

        // Then
        let newSut = SettingsViewModel(userDefaults: mockUserDefaults)
        XCTAssertFalse(newSut.sendAnalytics)
        XCTAssertFalse(newSut.showOnlineStatus)
    }

    func testDefaultCharacterTypePersistence() {
        // When
        sut.defaultCharacterType = .roleplay

        // Then
        let newSut = SettingsViewModel(userDefaults: mockUserDefaults)
        XCTAssertEqual(newSut.defaultCharacterType, .roleplay)
    }

    // MARK: - Reset to Defaults Tests

    func testResetToDefaults() {
        // Given - change all settings
        sut.isDarkMode = true
        sut.useDynamicType = false
        sut.enableNotifications = false
        sut.notifyNewFeatures = false
        sut.notifyPromotions = true
        sut.autoSaveChats = false
        sut.showTypingIndicator = false
        sut.hapticFeedback = false
        sut.messageSoundEnabled = false
        sut.sendAnalytics = false
        sut.showOnlineStatus = false
        sut.defaultCharacterType = .uncensoredGPT

        // When
        sut.resetToDefaults()

        // Then
        XCTAssertFalse(sut.isDarkMode)
        XCTAssertTrue(sut.useDynamicType)
        XCTAssertTrue(sut.enableNotifications)
        XCTAssertTrue(sut.notifyNewFeatures)
        XCTAssertFalse(sut.notifyPromotions)
        XCTAssertTrue(sut.autoSaveChats)
        XCTAssertTrue(sut.showTypingIndicator)
        XCTAssertTrue(sut.hapticFeedback)
        XCTAssertTrue(sut.messageSoundEnabled)
        XCTAssertTrue(sut.sendAnalytics)
        XCTAssertTrue(sut.showOnlineStatus)
        XCTAssertEqual(sut.defaultCharacterType, .laymeV1)
    }

    func testResetToDefaultsPersists() {
        // Given
        sut.isDarkMode = true
        sut.defaultCharacterType = .roleplay

        // When
        sut.resetToDefaults()

        // Then - verify persistence
        let newSut = SettingsViewModel(userDefaults: mockUserDefaults)
        XCTAssertFalse(newSut.isDarkMode)
        XCTAssertEqual(newSut.defaultCharacterType, .laymeV1)
    }

    // MARK: - All Character Types Tests

    func testAllCharacterTypes() {
        XCTAssertEqual(sut.allCharacterTypes, CharacterType.allCases)
        XCTAssertEqual(sut.allCharacterTypes.count, 4)
    }

    // MARK: - Settings Sections Tests

    func testSettingsSections() {
        let sections = SettingsSection.allCases
        XCTAssertEqual(sections.count, 5)
        XCTAssertTrue(sections.contains(.appearance))
        XCTAssertTrue(sections.contains(.notifications))
        XCTAssertTrue(sections.contains(.chat))
        XCTAssertTrue(sections.contains(.privacy))
        XCTAssertTrue(sections.contains(.about))
    }

    func testSettingsSectionIcons() {
        XCTAssertEqual(SettingsSection.appearance.iconName, "paintbrush.fill")
        XCTAssertEqual(SettingsSection.notifications.iconName, "bell.fill")
        XCTAssertEqual(SettingsSection.chat.iconName, "message.fill")
        XCTAssertEqual(SettingsSection.privacy.iconName, "lock.fill")
        XCTAssertEqual(SettingsSection.about.iconName, "info.circle.fill")
    }

    func testSettingsSectionIdentifiable() {
        let section = SettingsSection.appearance
        XCTAssertEqual(section.id, section.rawValue)
    }

    // MARK: - Multiple Changes Tests

    func testMultipleChangesPersist() {
        // When
        sut.isDarkMode = true
        sut.enableNotifications = false
        sut.autoSaveChats = false
        sut.defaultCharacterType = .companion

        // Then - all changes persisted
        let newSut = SettingsViewModel(userDefaults: mockUserDefaults)
        XCTAssertTrue(newSut.isDarkMode)
        XCTAssertFalse(newSut.enableNotifications)
        XCTAssertFalse(newSut.autoSaveChats)
        XCTAssertEqual(newSut.defaultCharacterType, .companion)
    }

    // MARK: - Settings Data Tests

    func testSettingsDataDefault() {
        let defaultData = SettingsData.default
        XCTAssertFalse(defaultData.isDarkMode)
        XCTAssertTrue(defaultData.useDynamicType)
        XCTAssertEqual(defaultData.defaultCharacterType, .laymeV1)
    }

    func testSettingsDataEquatable() {
        let data1 = SettingsData.default
        let data2 = SettingsData.default
        XCTAssertEqual(data1, data2)

        var data3 = SettingsData.default
        data3.isDarkMode = true
        XCTAssertNotEqual(data1, data3)
    }

    func testSettingsDataCodable() throws {
        let original = SettingsData.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SettingsData.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
