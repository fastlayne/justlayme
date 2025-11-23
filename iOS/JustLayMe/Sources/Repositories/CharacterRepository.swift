import Foundation
import Combine

// MARK: - Character Repository Protocol

protocol CharacterRepositoryProtocol {
    var characters: [AICharacter] { get }
    var customizationOptions: CustomizationOptions? { get }

    func loadCharacters() async throws -> [AICharacter]
    func loadCustomizationOptions(for characterId: String) async throws -> CustomizationOptions
    func createCharacter(_ character: AICharacter) async throws -> AICharacter
    func updateCharacter(_ character: AICharacter) async throws -> AICharacter
    func deleteCharacter(id: String) async throws
}

// MARK: - Character Repository

class CharacterRepository: CharacterRepositoryProtocol, ObservableObject {
    static let shared = CharacterRepository()

    @Published private(set) var characters: [AICharacter] = []
    @Published private(set) var customizationOptions: CustomizationOptions?

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    func loadCharacters() async throws -> [AICharacter] {
        let loadedCharacters: [AICharacter] = try await apiClient.request(.getCharacters())
        await MainActor.run {
            self.characters = loadedCharacters
        }
        return loadedCharacters
    }

    func loadCustomizationOptions(for characterId: String) async throws -> CustomizationOptions {
        let options: CustomizationOptions = try await apiClient.request(
            .customizationOptions(characterId: characterId)
        )
        await MainActor.run {
            self.customizationOptions = options
        }
        return options
    }

    func createCharacter(_ character: AICharacter) async throws -> AICharacter {
        let createdCharacter: AICharacter = try await apiClient.request(
            .createCharacter(
                name: character.name,
                backstory: character.backstory,
                traits: character.personalityTraits,
                patterns: character.speechPatterns
            )
        )
        await MainActor.run {
            self.characters.append(createdCharacter)
        }
        return createdCharacter
    }

    func updateCharacter(_ character: AICharacter) async throws -> AICharacter {
        let updatedCharacter: AICharacter = try await apiClient.request(
            .updateCharacter(
                id: character.id,
                backstory: character.backstory,
                traits: character.personalityTraits,
                patterns: character.speechPatterns
            )
        )
        await MainActor.run {
            if let index = self.characters.firstIndex(where: { $0.id == character.id }) {
                self.characters[index] = updatedCharacter
            }
        }
        return updatedCharacter
    }

    func deleteCharacter(id: String) async throws {
        // Note: Delete endpoint not in current API, but included for completeness
        await MainActor.run {
            self.characters.removeAll { $0.id == id }
        }
    }

    func clearCache() {
        characters.removeAll()
        customizationOptions = nil
    }
}
