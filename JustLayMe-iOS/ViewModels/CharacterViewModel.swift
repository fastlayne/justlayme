import Foundation
import Combine
import SwiftUI

// MARK: - Character View Model

@MainActor
final class CharacterViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var characters: [Character] = []
    @Published var userCharacters: [Character] = []
    @Published var publicCharacters: [Character] = []

    @Published var selectedCharacter: Character?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Character Creator
    @Published var creatorName: String = ""
    @Published var creatorBackstory: String = ""
    @Published var creatorIsPublic: Bool = false
    @Published var creatorPersonality = PersonalityTraits.default
    @Published var creatorSpeechPatterns: [String] = []
    @Published var isCreating: Bool = false

    // MARK: - Properties

    private let apiService: APIServiceProtocol
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var canCreateCharacter: Bool {
        authService.currentUser?.isPremium ?? false
    }

    var isFormValid: Bool {
        !creatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Initialization

    init(
        apiService: APIServiceProtocol = APIService.shared,
        authService: AuthService = .shared
    ) {
        self.apiService = apiService
        self.authService = authService

        // Add preset characters immediately
        characters = Character.presetCharacters
        publicCharacters = Character.presetCharacters
    }

    // MARK: - Actions

    func loadCharacters() async {
        isLoading = true
        errorMessage = nil

        do {
            let loaded = try await apiService.getCharacters()

            // Combine preset and loaded characters
            let allCharacters = Character.presetCharacters + loaded

            characters = allCharacters
            userCharacters = loaded.filter { $0.userId == authService.currentUser?.id }
            publicCharacters = Character.presetCharacters + loaded.filter { $0.isPublic }
        } catch {
            errorMessage = "Failed to load characters"
            // Keep preset characters
            characters = Character.presetCharacters
            publicCharacters = Character.presetCharacters
        }

        isLoading = false
    }

    func createCharacter() async -> Character? {
        guard isFormValid else {
            errorMessage = "Please enter a character name"
            return nil
        }

        guard canCreateCharacter else {
            errorMessage = "Premium subscription required to create characters"
            return nil
        }

        isCreating = true
        errorMessage = nil

        do {
            let request = CharacterCreateRequest(
                name: creatorName.trimmingCharacters(in: .whitespacesAndNewlines),
                backstory: creatorBackstory.isEmpty ? nil : creatorBackstory,
                personalityTraits: creatorPersonality,
                speechPatterns: creatorSpeechPatterns.isEmpty ? nil : creatorSpeechPatterns,
                isPublic: creatorIsPublic
            )

            let character = try await apiService.createCharacter(request)

            // Add to lists
            characters.append(character)
            userCharacters.append(character)
            if character.isPublic {
                publicCharacters.append(character)
            }

            // Clear form
            resetCreatorForm()

            // Post notification
            NotificationCenter.default.post(name: .characterDidUpdate, object: character)

            isCreating = false
            return character
        } catch {
            errorMessage = "Failed to create character"
            isCreating = false
            return nil
        }
    }

    func updateCharacter(_ character: Character, with request: CharacterUpdateRequest) async -> Character? {
        isLoading = true
        errorMessage = nil

        do {
            let updated = try await apiService.updateCharacter(id: character.id, request)

            // Update in lists
            if let index = characters.firstIndex(where: { $0.id == character.id }) {
                characters[index] = updated
            }
            if let index = userCharacters.firstIndex(where: { $0.id == character.id }) {
                userCharacters[index] = updated
            }
            if let index = publicCharacters.firstIndex(where: { $0.id == character.id }) {
                publicCharacters[index] = updated
            }

            // Post notification
            NotificationCenter.default.post(name: .characterDidUpdate, object: updated)

            isLoading = false
            return updated
        } catch {
            errorMessage = "Failed to update character"
            isLoading = false
            return nil
        }
    }

    func deleteCharacter(_ character: Character) async -> Bool {
        guard !character.isSystemCharacter else {
            errorMessage = "Cannot delete system characters"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            try await apiService.deleteCharacter(id: character.id)

            // Remove from lists
            characters.removeAll { $0.id == character.id }
            userCharacters.removeAll { $0.id == character.id }
            publicCharacters.removeAll { $0.id == character.id }

            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to delete character"
            isLoading = false
            return false
        }
    }

    func selectCharacter(_ character: Character) {
        selectedCharacter = character
    }

    // MARK: - Creator Form

    func resetCreatorForm() {
        creatorName = ""
        creatorBackstory = ""
        creatorIsPublic = false
        creatorPersonality = PersonalityTraits.default
        creatorSpeechPatterns = []
    }

    func addSpeechPattern(_ pattern: String) {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !creatorSpeechPatterns.contains(trimmed) else { return }
        creatorSpeechPatterns.append(trimmed)
    }

    func removeSpeechPattern(_ pattern: String) {
        creatorSpeechPatterns.removeAll { $0 == pattern }
    }

    // MARK: - Personality Slider Bindings

    func friendlinessBinding() -> Binding<Double> {
        Binding(
            get: { self.creatorPersonality.friendliness ?? 0.5 },
            set: { self.creatorPersonality.friendliness = $0 }
        )
    }

    func creativityBinding() -> Binding<Double> {
        Binding(
            get: { self.creatorPersonality.creativity ?? 0.5 },
            set: { self.creatorPersonality.creativity = $0 }
        )
    }

    func assertivenessBinding() -> Binding<Double> {
        Binding(
            get: { self.creatorPersonality.assertiveness ?? 0.5 },
            set: { self.creatorPersonality.assertiveness = $0 }
        )
    }

    func humorBinding() -> Binding<Double> {
        Binding(
            get: { self.creatorPersonality.humor ?? 0.5 },
            set: { self.creatorPersonality.humor = $0 }
        )
    }

    func empathyBinding() -> Binding<Double> {
        Binding(
            get: { self.creatorPersonality.empathy ?? 0.5 },
            set: { self.creatorPersonality.empathy = $0 }
        )
    }

    func formalityBinding() -> Binding<Double> {
        Binding(
            get: { self.creatorPersonality.formality ?? 0.5 },
            set: { self.creatorPersonality.formality = $0 }
        )
    }
}
