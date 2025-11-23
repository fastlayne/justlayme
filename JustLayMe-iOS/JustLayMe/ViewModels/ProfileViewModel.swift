import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var avatarStyle: String = "initials"
    @Published var themePreference: ThemePreference = .auto
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var subscriptionEnd: Date?
    @Published var isLoading = false
    @Published var error: String?
    @Published var showSuccess = false

    private let authManager = AuthManager.shared
    private let api = APIService.shared
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadProfile()
    }

    // MARK: - Public Methods

    func loadProfile() {
        guard let user = authManager.currentUser else { return }

        name = user.name ?? ""
        email = user.email
        subscriptionStatus = user.subscriptionStatus
        subscriptionEnd = user.subscriptionEnd
        avatarStyle = settings.avatarStyle
    }

    func saveProfile() async {
        isLoading = true
        error = nil

        do {
            try await authManager.updateProfile(name: name.isEmpty ? nil : name)
            settings.avatarStyle = avatarStyle
            showSuccess = true
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    var isPremium: Bool {
        subscriptionStatus == .premium
    }

    var subscriptionEndFormatted: String? {
        guard let date = subscriptionEnd else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Until \(formatter.string(from: date))"
    }
}
