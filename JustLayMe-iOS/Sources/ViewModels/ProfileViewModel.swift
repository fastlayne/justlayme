import Foundation
import Combine

// MARK: - Profile ViewModel
@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var user: User?
    @Published var name = ""
    @Published var avatarStyle = "default"

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Data Export
    @Published var exportedData: ExportedData?
    @Published var isExporting = false
    @Published var showExportSheet = false

    // Clear Data
    @Published var showClearDataConfirmation = false
    @Published var isClearing = false

    // MARK: - Services
    private let profileService = ProfileService.shared

    // MARK: - Computed Properties
    var isPremium: Bool {
        user?.isPremium ?? false
    }

    var subscriptionStatusText: String {
        guard let user = user else { return "Not logged in" }
        if user.isPremium {
            if let endDate = user.subscriptionEnd {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Premium (expires \(formatter.string(from: endDate)))"
            }
            return "Premium (Lifetime)"
        }
        return "Free"
    }

    var memberSinceText: String {
        guard let createdAt = user?.createdAt else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: createdAt)
    }

    // MARK: - Load Profile
    func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            user = try await profileService.getProfile()
            name = user?.name ?? ""
        } catch {
            errorMessage = "Failed to load profile"
        }

        isLoading = false
    }

    // MARK: - Update Profile
    func updateProfile() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            user = try await profileService.updateProfile(
                name: name.isEmpty ? nil : name,
                avatarStyle: avatarStyle,
                theme: nil
            )
            successMessage = "Profile updated successfully"
        } catch {
            errorMessage = "Failed to update profile"
        }

        isSaving = false
    }

    // MARK: - Export Data
    func exportData() async {
        isExporting = true
        errorMessage = nil

        do {
            exportedData = try await profileService.exportData()
            showExportSheet = true
        } catch {
            errorMessage = "Failed to export data"
        }

        isExporting = false
    }

    func getExportJSON() -> String? {
        guard let data = exportedData else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        if let jsonData = try? encoder.encode(data) {
            return String(data: jsonData, encoding: .utf8)
        }
        return nil
    }

    // MARK: - Clear Data
    func clearAllData() async {
        isClearing = true
        errorMessage = nil

        do {
            try await profileService.clearAllData()
            successMessage = "All data cleared successfully"
            showClearDataConfirmation = false
        } catch {
            errorMessage = "Failed to clear data"
        }

        isClearing = false
    }
}

// MARK: - Settings ViewModel
@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var settings: SettingsManager

    @Published var showLogoutConfirmation = false
    @Published var showResetConfirmation = false

    // App Info
    let appVersion: String
    let buildNumber: String

    // MARK: - Initialization
    init() {
        self.settings = SettingsManager.shared
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Actions
    func resetToDefaults() {
        settings.resetToDefaults()
    }

    // MARK: - Computed Properties
    var versionString: String {
        "Version \(appVersion) (\(buildNumber))"
    }
}
