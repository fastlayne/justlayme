import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var defaultCharacter: String
    @Published var responseLength: String
    @Published var autoScroll: Bool
    @Published var soundNotifications: Bool
    @Published var saveConversations: Bool
    @Published var analyticsOptOut: Bool
    @Published var isLoading = false
    @Published var error: String?
    @Published var showClearConfirmation = false
    @Published var showExportSuccess = false

    private let settings = AppSettings.shared
    private let api = APIService.shared

    init() {
        defaultCharacter = settings.defaultCharacter
        responseLength = settings.responseLength
        autoScroll = settings.autoScroll
        soundNotifications = settings.soundNotifications
        saveConversations = settings.saveConversations
        analyticsOptOut = settings.analyticsOptOut
    }

    // MARK: - Public Methods

    func saveSettings() {
        settings.defaultCharacter = defaultCharacter
        settings.responseLength = responseLength
        settings.autoScroll = autoScroll
        settings.soundNotifications = soundNotifications
        settings.saveConversations = saveConversations
        settings.analyticsOptOut = analyticsOptOut
    }

    func exportData() async {
        isLoading = true
        error = nil

        do {
            let data = try await api.exportData()

            // Save to documents directory
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let fileName = "justlayme-data-\(dateFormatter.string(from: Date())).json"
            let fileURL = documentsPath.appendingPathComponent(fileName)

            try data.write(to: fileURL)
            showExportSuccess = true

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func clearAllData() async {
        isLoading = true
        error = nil

        do {
            _ = try await api.clearData()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    var characterOptions: [(String, String)] {
        [
            ("layme_v1", "Layme V1 (Free)"),
            ("uncensored_gpt", "Uncensored GPT"),
            ("roleplay", "Roleplay AI"),
            ("companion", "Intimate Companion")
        ]
    }

    var responseLengthOptions: [(String, String)] {
        [
            ("short", "Short"),
            ("medium", "Medium"),
            ("long", "Long")
        ]
    }
}
