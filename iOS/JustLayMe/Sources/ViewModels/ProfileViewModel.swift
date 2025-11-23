import Foundation
import Combine

// MARK: - Profile State

enum ProfileState: Equatable {
    case idle
    case loading
    case loaded(User)
    case exporting
    case exported(URL)
    case error(ProfileError)
}

enum ProfileError: Error, Equatable, LocalizedError {
    case loadFailed
    case updateFailed(String)
    case exportFailed
    case clearDataFailed
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "Failed to load profile"
        case .updateFailed(let message):
            return "Failed to update profile: \(message)"
        case .exportFailed:
            return "Failed to export data"
        case .clearDataFailed:
            return "Failed to clear data"
        case .notAuthenticated:
            return "Please log in to access your profile"
        }
    }
}

// MARK: - Profile ViewModel

@MainActor
class ProfileViewModel: ObservableObject {
    @Published private(set) var state: ProfileState = .idle
    @Published private(set) var user: User?
    @Published var editableName: String = ""
    @Published var showClearDataConfirmation: Bool = false

    private let apiClient: APIClientProtocol
    private var cancellables = Set<AnyCancellable>()

    var isLoading: Bool {
        if case .loading = state { return true }
        if case .exporting = state { return true }
        return false
    }

    var hasChanges: Bool {
        guard let user = user else { return false }
        return editableName != (user.name ?? "")
    }

    var memberSince: String {
        guard let date = user?.createdAt else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var lastActive: String {
        guard let date = user?.lastLogin else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    func loadProfile() async {
        state = .loading

        do {
            let loadedUser: User = try await apiClient.request(.getProfile())
            user = loadedUser
            editableName = loadedUser.name ?? ""
            state = .loaded(loadedUser)
        } catch let error as APIError {
            if case .unauthorized = error {
                state = .error(.notAuthenticated)
            } else {
                state = .error(.loadFailed)
            }
        } catch {
            state = .error(.loadFailed)
        }
    }

    func updateProfile() async -> Bool {
        guard hasChanges else { return true }

        state = .loading

        do {
            try await apiClient.requestVoid(
                .updateProfile(name: editableName.isEmpty ? nil : editableName)
            )

            if var updatedUser = user {
                updatedUser.name = editableName.isEmpty ? nil : editableName
                user = updatedUser
                state = .loaded(updatedUser)
            }

            return true
        } catch let error as APIError {
            state = .error(.updateFailed(error.localizedDescription ?? "Unknown error"))
            return false
        } catch {
            state = .error(.updateFailed(error.localizedDescription))
            return false
        }
    }

    func exportData() async -> URL? {
        state = .exporting

        do {
            let exportData: ExportData = try await apiClient.request(.exportData())

            // Save to temp file
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(exportData)

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("justlayme-export-\(Date().timeIntervalSince1970).json")

            try data.write(to: tempURL)
            state = .exported(tempURL)
            return tempURL
        } catch {
            state = .error(.exportFailed)
            return nil
        }
    }

    func clearAllData() async -> Bool {
        state = .loading

        do {
            try await apiClient.requestVoid(.clearData())
            state = user.map { .loaded($0) } ?? .idle
            return true
        } catch {
            state = .error(.clearDataFailed)
            return false
        }
    }

    func resetChanges() {
        editableName = user?.name ?? ""
    }

    func clearError() {
        if case .error = state {
            state = user.map { .loaded($0) } ?? .idle
        }
    }
}

// MARK: - Export Data Model

struct ExportData: Codable, Equatable {
    let user: User
    let conversations: [Conversation]
    let characters: [AICharacter]
    let exportedAt: String

    enum CodingKeys: String, CodingKey {
        case user, conversations, characters
        case exportedAt = "exported_at"
    }
}
