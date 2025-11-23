import Foundation
import Combine
import SwiftUI

// MARK: - Profile View Model

@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var user: User?
    @Published var name: String = ""
    @Published var email: String = ""

    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Settings
    @Published var hapticFeedbackEnabled: Bool = true
    @Published var notificationsEnabled: Bool = true
    @Published var darkModeEnabled: Bool = true

    // Data Management
    @Published var showExportConfirmation: Bool = false
    @Published var showClearDataConfirmation: Bool = false
    @Published var showLogoutConfirmation: Bool = false
    @Published var exportedData: Data?

    // MARK: - Properties

    private let apiService: APIServiceProtocol
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var isPremium: Bool {
        user?.isPremium ?? false
    }

    var subscriptionStatusText: String {
        guard let user = user else { return "Not logged in" }

        switch user.subscriptionStatus {
        case .free:
            return "Free Plan"
        case .premium:
            if let endDate = user.subscriptionEnd {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Premium until \(formatter.string(from: endDate))"
            }
            return "Premium"
        case .lifetime:
            return "Lifetime Premium"
        }
    }

    var memberSinceText: String {
        guard let user = user else { return "" }

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return "Member since \(formatter.string(from: user.createdAt))"
    }

    var hasUnsavedChanges: Bool {
        guard let user = user else { return false }
        return name != (user.name ?? "") || email != user.email
    }

    // MARK: - Initialization

    init(
        apiService: APIServiceProtocol = APIService.shared,
        authService: AuthService = .shared
    ) {
        self.apiService = apiService
        self.authService = authService

        loadSettings()
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        authService.$authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if case .authenticated(let user) = state {
                    self?.user = user
                    self?.name = user.name ?? ""
                    self?.email = user.email
                }
            }
            .store(in: &cancellables)
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard

        hapticFeedbackEnabled = defaults.bool(forKey: AppConfig.UserDefaultsKey.hapticFeedbackEnabled)
        notificationsEnabled = defaults.bool(forKey: AppConfig.UserDefaultsKey.notificationsEnabled)
        darkModeEnabled = defaults.bool(forKey: AppConfig.UserDefaultsKey.darkModeEnabled)

        // Set defaults if not set
        if defaults.object(forKey: AppConfig.UserDefaultsKey.hapticFeedbackEnabled) == nil {
            hapticFeedbackEnabled = true
        }
        if defaults.object(forKey: AppConfig.UserDefaultsKey.darkModeEnabled) == nil {
            darkModeEnabled = true
        }
    }

    // MARK: - Actions

    func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            let profile = try await apiService.getProfile()
            user = profile
            name = profile.name ?? ""
            email = profile.email
        } catch {
            errorMessage = "Failed to load profile"
        }

        isLoading = false
    }

    func saveProfile() async {
        guard hasUnsavedChanges else { return }

        isSaving = true
        errorMessage = nil

        do {
            let update = UserProfileUpdate(
                name: name.isEmpty ? nil : name,
                email: email != user?.email ? email : nil
            )

            let updatedUser = try await apiService.updateProfile(update)
            user = updatedUser
            successMessage = "Profile updated successfully"

            // Refresh auth state
            _ = try? await authService.refreshUser()
        } catch {
            errorMessage = "Failed to update profile"
        }

        isSaving = false
    }

    func exportData() async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await apiService.exportData()
            exportedData = data
            successMessage = "Data exported successfully"
        } catch {
            errorMessage = "Failed to export data"
        }

        isLoading = false
    }

    func clearAllData() async {
        isLoading = true
        errorMessage = nil

        do {
            try await apiService.clearData()
            successMessage = "All data cleared successfully"
        } catch {
            errorMessage = "Failed to clear data"
        }

        isLoading = false
    }

    func logout() {
        authService.logout()
    }

    // MARK: - Settings

    func toggleHapticFeedback() {
        hapticFeedbackEnabled.toggle()
        UserDefaults.standard.set(hapticFeedbackEnabled, forKey: AppConfig.UserDefaultsKey.hapticFeedbackEnabled)
    }

    func toggleNotifications() {
        notificationsEnabled.toggle()
        UserDefaults.standard.set(notificationsEnabled, forKey: AppConfig.UserDefaultsKey.notificationsEnabled)

        if notificationsEnabled {
            requestNotificationPermission()
        }
    }

    func toggleDarkMode() {
        darkModeEnabled.toggle()
        UserDefaults.standard.set(darkModeEnabled, forKey: AppConfig.UserDefaultsKey.darkModeEnabled)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if !granted {
                    self.notificationsEnabled = false
                    UserDefaults.standard.set(false, forKey: AppConfig.UserDefaultsKey.notificationsEnabled)
                }
            }
        }
    }

    // MARK: - Helpers

    func resetForm() {
        name = user?.name ?? ""
        email = user?.email ?? ""
    }
}

// MARK: - User Notifications

import UserNotifications
