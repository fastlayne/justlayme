import Foundation
import Combine

// MARK: - Character State

enum CharacterState: Equatable {
    case idle
    case loading
    case loaded([AICharacter])
    case error(CharacterError)
}

enum CharacterError: Error, Equatable, LocalizedError {
    case limitReached
    case premiumRequired
    case notFound
    case saveFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .limitReached:
            return "Free users can only create 1 character. Upgrade to Premium for unlimited characters."
        case .premiumRequired:
            return "Character customization requires a Premium subscription."
        case .notFound:
            return "Character not found."
        case .saveFailed(let message):
            return "Failed to save character: \(message)"
        case .networkError(let message):
            return message
        }
    }
}

// MARK: - Character ViewModel

@MainActor
class CharacterViewModel: ObservableObject {
    @Published private(set) var state: CharacterState = .idle
    @Published private(set) var characters: [AICharacter] = []
    @Published private(set) var customizationOptions: CustomizationOptions?
    @Published var selectedCharacter: AICharacter?

    // Character creation form
    @Published var characterName: String = ""
    @Published var characterBackstory: String = ""
    @Published var selectedTraits: [String: Int] = [:]
    @Published var speechPatterns: [String] = []

    private let apiClient: APIClientProtocol
    private let userRepository: UserRepositoryProtocol?
    private var cancellables = Set<AnyCancellable>()

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var canCreateCharacter: Bool {
        guard let user = userRepository?.currentUser else { return false }
        if user.subscriptionStatus.isPremium { return true }
        return characters.count < 1
    }

    var isFormValid: Bool {
        !characterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        apiClient: APIClientProtocol = APIClient.shared,
        userRepository: UserRepositoryProtocol? = nil
    ) {
        self.apiClient = apiClient
        self.userRepository = userRepository
    }

    func loadCharacters() async {
        state = .loading

        do {
            let loadedCharacters: [AICharacter] = try await apiClient.request(.getCharacters())
            characters = loadedCharacters
            state = .loaded(loadedCharacters)
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            state = .error(.networkError(error.localizedDescription))
        }
    }

    func loadCustomizationOptions(for characterId: String) async {
        do {
            customizationOptions = try await apiClient.request(
                .customizationOptions(characterId: characterId)
            )
        } catch {
            // Silently fail for customization options
        }
    }

    func createCharacter() async -> Bool {
        guard isFormValid else { return false }
        guard canCreateCharacter else {
            state = .error(.limitReached)
            return false
        }

        state = .loading

        do {
            let newCharacter: AICharacter = try await apiClient.request(
                .createCharacter(
                    name: characterName.trimmingCharacters(in: .whitespacesAndNewlines),
                    backstory: characterBackstory.isEmpty ? nil : characterBackstory,
                    traits: selectedTraits.isEmpty ? nil : selectedTraits,
                    patterns: speechPatterns.isEmpty ? nil : speechPatterns
                )
            )

            characters.append(newCharacter)
            clearForm()
            state = .loaded(characters)
            return true
        } catch let error as APIError {
            handleAPIError(error)
            return false
        } catch {
            state = .error(.networkError(error.localizedDescription))
            return false
        }
    }

    func updateCharacter(_ character: AICharacter) async -> Bool {
        state = .loading

        do {
            let updatedCharacter: AICharacter = try await apiClient.request(
                .updateCharacter(
                    id: character.id,
                    backstory: character.backstory,
                    traits: character.personalityTraits,
                    patterns: character.speechPatterns
                )
            )

            if let index = characters.firstIndex(where: { $0.id == character.id }) {
                characters[index] = updatedCharacter
            }

            state = .loaded(characters)
            return true
        } catch let error as APIError {
            handleAPIError(error)
            return false
        } catch {
            state = .error(.networkError(error.localizedDescription))
            return false
        }
    }

    func selectCharacter(_ character: AICharacter) {
        selectedCharacter = character
        characterName = character.name
        characterBackstory = character.backstory ?? ""
        selectedTraits = character.personalityTraits ?? [:]
        speechPatterns = character.speechPatterns ?? []
    }

    func addTrait(_ trait: String, value: Int) {
        selectedTraits[trait] = min(max(value, 1), 10)
    }

    func removeTrait(_ trait: String) {
        selectedTraits.removeValue(forKey: trait)
    }

    func addSpeechPattern(_ pattern: String) {
        guard !pattern.isEmpty, !speechPatterns.contains(pattern) else { return }
        speechPatterns.append(pattern)
    }

    func removeSpeechPattern(_ pattern: String) {
        speechPatterns.removeAll { $0 == pattern }
    }

    func clearForm() {
        characterName = ""
        characterBackstory = ""
        selectedTraits = [:]
        speechPatterns = []
        selectedCharacter = nil
    }

    func clearError() {
        if case .error = state {
            state = characters.isEmpty ? .idle : .loaded(characters)
        }
    }

    // MARK: - Private Methods

    private func handleAPIError(_ error: APIError) {
        switch error {
        case .forbidden(let message):
            if message.contains("1 character") || message.contains("limit") {
                state = .error(.limitReached)
            } else {
                state = .error(.premiumRequired)
            }
        case .notFound:
            state = .error(.notFound)
        case .badRequest(let message):
            state = .error(.saveFailed(message))
        default:
            state = .error(.networkError(error.localizedDescription ?? "Unknown error"))
        }
    }
}
