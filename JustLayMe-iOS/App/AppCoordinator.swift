import SwiftUI
import Combine

// MARK: - Navigation Destination

enum AppDestination: Hashable {
    case auth
    case main
    case chat(characterId: String?)
    case characterDetail(Character)
    case characterCreator
    case profile
    case settings
    case subscription
    case conversationHistory
    case conversationDetail(Conversation)
}

// MARK: - App Tab

enum AppTab: Int, CaseIterable, Identifiable {
    case chat = 0
    case characters = 1
    case profile = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .characters: return "Characters"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .characters: return "person.2.fill"
        case .profile: return "person.circle.fill"
        }
    }
}

// MARK: - App Coordinator

@MainActor
final class AppCoordinator: ObservableObject {
    // MARK: - Published Properties

    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    @Published var selectedTab: AppTab = .chat
    @Published var navigationPath = NavigationPath()
    @Published var presentedSheet: AppDestination?
    @Published var presentedFullScreen: AppDestination?
    @Published var alertItem: AlertItem?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let keychainService = KeychainService.shared
    private let userDefaults = UserDefaults.standard

    // MARK: - State Keys

    private enum StateKeys {
        static let selectedTab = "selectedTab"
        static let lastViewedCharacter = "lastViewedCharacter"
    }

    // MARK: - Initialization

    init() {
        loadSavedState()
        setupBindings()
    }

    // MARK: - Navigation Methods

    func navigate(to destination: AppDestination) {
        navigationPath.append(destination)
    }

    func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    func navigateToRoot() {
        navigationPath = NavigationPath()
    }

    func presentSheet(_ destination: AppDestination) {
        presentedSheet = destination
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func presentFullScreen(_ destination: AppDestination) {
        presentedFullScreen = destination
    }

    func dismissFullScreen() {
        presentedFullScreen = nil
    }

    // MARK: - Alert Methods

    func showAlert(_ alert: AlertItem) {
        alertItem = alert
    }

    func showError(_ error: Error) {
        alertItem = AlertItem(
            title: "Error",
            message: error.localizedDescription
        )
    }

    func dismissAlert() {
        alertItem = nil
    }

    // MARK: - Auth State

    func handleAuthStateChange(isAuthenticated: Bool) {
        self.isAuthenticated = isAuthenticated

        if !isAuthenticated {
            // Reset navigation on logout
            navigateToRoot()
            selectedTab = .chat
        }
    }

    // MARK: - State Persistence

    func saveState() {
        userDefaults.set(selectedTab.rawValue, forKey: StateKeys.selectedTab)
    }

    private func loadSavedState() {
        if let tabRawValue = userDefaults.object(forKey: StateKeys.selectedTab) as? Int,
           let tab = AppTab(rawValue: tabRawValue) {
            selectedTab = tab
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Listen for auth notifications
        NotificationCenter.default.publisher(for: .userDidLogin)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAuthStateChange(isAuthenticated: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .userDidLogout)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAuthStateChange(isAuthenticated: false)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Alert Item

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var primaryButton: AlertButton?
    var secondaryButton: AlertButton?

    struct AlertButton {
        let title: String
        let role: ButtonRole?
        let action: () -> Void

        init(title: String, role: ButtonRole? = nil, action: @escaping () -> Void = {}) {
            self.title = title
            self.role = role
            self.action = action
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userDidLogin = Notification.Name("userDidLogin")
    static let userDidLogout = Notification.Name("userDidLogout")
    static let subscriptionDidUpdate = Notification.Name("subscriptionDidUpdate")
    static let characterDidUpdate = Notification.Name("characterDidUpdate")
}
