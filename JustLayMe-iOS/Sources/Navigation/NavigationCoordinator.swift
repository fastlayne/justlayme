import SwiftUI
import Combine

// MARK: - Navigation Coordinator
@MainActor
final class NavigationCoordinator: ObservableObject {
    @Published var chatPath = NavigationPath()
    @Published var characterPath = NavigationPath()
    @Published var profilePath = NavigationPath()

    @Published var presentedSheet: SheetDestination?
    @Published var presentedFullScreen: FullScreenDestination?

    @Published var alertItem: AlertItem?

    // MARK: - Chat Navigation
    func navigateToChat(characterId: String) {
        chatPath.append(ChatDestination.conversation(characterId: characterId))
    }

    func navigateToConversationHistory() {
        chatPath.append(ChatDestination.history)
    }

    // MARK: - Character Navigation
    func navigateToCharacterDetail(_ character: AICharacter) {
        characterPath.append(CharacterDestination.detail(character))
    }

    func navigateToCharacterCustomization(_ character: AICharacter) {
        characterPath.append(CharacterDestination.customize(character))
    }

    // MARK: - Sheet Presentation
    func presentPaywall() {
        presentedSheet = .paywall
    }

    func presentSettings() {
        presentedSheet = .settings
    }

    func presentProfile() {
        presentedSheet = .profile
    }

    func presentCharacterCreator() {
        presentedSheet = .characterCreator
    }

    func presentExportData() {
        presentedSheet = .exportData
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    // MARK: - Full Screen Presentation
    func presentOnboarding() {
        presentedFullScreen = .onboarding
    }

    func presentAuth() {
        presentedFullScreen = .auth
    }

    func dismissFullScreen() {
        presentedFullScreen = nil
    }

    // MARK: - Alerts
    func showAlert(title: String, message: String, primaryAction: AlertAction? = nil) {
        alertItem = AlertItem(
            title: title,
            message: message,
            primaryAction: primaryAction
        )
    }

    func dismissAlert() {
        alertItem = nil
    }

    // MARK: - Pop Navigation
    func popToRoot(tab: Tab) {
        switch tab {
        case .chat:
            chatPath = NavigationPath()
        case .characters:
            characterPath = NavigationPath()
        case .profile:
            profilePath = NavigationPath()
        case .settings:
            break
        }
    }

    func pop(tab: Tab) {
        switch tab {
        case .chat:
            if !chatPath.isEmpty { chatPath.removeLast() }
        case .characters:
            if !characterPath.isEmpty { characterPath.removeLast() }
        case .profile:
            if !profilePath.isEmpty { profilePath.removeLast() }
        case .settings:
            break
        }
    }
}

// MARK: - Navigation Destinations
enum Tab: Hashable {
    case chat
    case characters
    case profile
    case settings
}

enum ChatDestination: Hashable {
    case conversation(characterId: String)
    case history
    case search
}

enum CharacterDestination: Hashable {
    case detail(AICharacter)
    case customize(AICharacter)
    case create
}

enum SheetDestination: Identifiable {
    case paywall
    case settings
    case profile
    case characterCreator
    case exportData
    case conversationExport(conversationId: String)

    var id: String {
        switch self {
        case .paywall: return "paywall"
        case .settings: return "settings"
        case .profile: return "profile"
        case .characterCreator: return "characterCreator"
        case .exportData: return "exportData"
        case .conversationExport(let id): return "conversationExport-\(id)"
        }
    }
}

enum FullScreenDestination: Identifiable {
    case onboarding
    case auth

    var id: String {
        switch self {
        case .onboarding: return "onboarding"
        case .auth: return "auth"
        }
    }
}

// MARK: - Alert Item
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryAction: AlertAction?
}

struct AlertAction {
    let title: String
    let role: ButtonRole?
    let action: () -> Void

    init(title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }
}
