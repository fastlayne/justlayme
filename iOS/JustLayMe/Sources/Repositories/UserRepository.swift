import Foundation
import Combine

// MARK: - User Repository

class UserRepository: UserRepositoryProtocol, ObservableObject {
    static let shared = UserRepository()

    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated: Bool = false

    private let apiClient: APIClientProtocol
    private let keychain: KeychainServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        apiClient: APIClientProtocol = APIClient.shared,
        keychain: KeychainServiceProtocol = KeychainService.shared
    ) {
        self.apiClient = apiClient
        self.keychain = keychain
    }

    func setUser(_ user: User?) {
        currentUser = user
        isAuthenticated = user != nil
    }

    func updateSubscription(_ status: SubscriptionStatus, endDate: Date?) {
        guard var user = currentUser else { return }
        user.subscriptionStatus = status
        user.subscriptionEnd = endDate
        currentUser = user
    }

    func updateMessageCount(_ count: Int) {
        guard var user = currentUser else { return }
        user.messageCount = count
        currentUser = user
    }

    func incrementMessageCount() {
        guard var user = currentUser else { return }
        user.messageCount += 1
        currentUser = user
    }

    func clear() {
        currentUser = nil
        isAuthenticated = false
    }
}
