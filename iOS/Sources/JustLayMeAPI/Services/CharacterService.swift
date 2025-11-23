// MARK: - Character Service
// Handles character management and customization

import Foundation
import Combine

public final class CharacterService: ObservableObject {
    public static let shared = CharacterService()

    private let client: APIClient
    private var cancellables = Set<AnyCancellable>()

    @Published public private(set) var characters: [Character] = []
    @Published public private(set) var customizationOptions: CustomizationOptions?
    @Published public private(set) var isLoading: Bool = false

    public init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Fetch Characters

    /// Get all characters for the authenticated user
    public func fetchCharacters() -> AnyPublisher<[Character], APIError> {
        isLoading = true

        return client.request(.characters)
            .handleEvents(
                receiveOutput: { [weak self] characters in
                    self?.characters = characters
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func fetchCharacters() async throws -> [Character] {
        isLoading = true
        defer { isLoading = false }

        let characters: [Character] = try await client.request(.characters)
        self.characters = characters
        return characters
    }

    // MARK: - Create Character

    /// Create a new character
    public func createCharacter(
        name: String,
        backstory: String? = nil,
        personalityTraits: [String: Any]? = nil,
        speechPatterns: [String]? = nil
    ) -> AnyPublisher<Character, APIError> {
        isLoading = true

        let request = CreateCharacterRequest(
            name: name,
            backstory: backstory,
            personalityTraits: personalityTraits,
            speechPatterns: speechPatterns
        )

        return client.request(.createCharacter, body: request)
            .handleEvents(
                receiveOutput: { [weak self] character in
                    self?.characters.append(character)
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func createCharacter(
        name: String,
        backstory: String? = nil,
        personalityTraits: [String: Any]? = nil,
        speechPatterns: [String]? = nil
    ) async throws -> Character {
        isLoading = true
        defer { isLoading = false }

        let request = CreateCharacterRequest(
            name: name,
            backstory: backstory,
            personalityTraits: personalityTraits,
            speechPatterns: speechPatterns
        )

        let character: Character = try await client.request(.createCharacter, body: request)
        characters.append(character)
        return character
    }

    // MARK: - Update Character

    /// Update an existing character
    public func updateCharacter(
        id: String,
        backstory: String? = nil,
        personalityTraits: [String: Any]? = nil,
        speechPatterns: [String]? = nil
    ) -> AnyPublisher<Character, APIError> {
        isLoading = true

        struct UpdateRequest: Codable {
            let backstory: String?
            let personality_traits: String?
            let speech_patterns: [String]?
        }

        var traitsJson: String? = nil
        if let traits = personalityTraits,
           let data = try? JSONSerialization.data(withJSONObject: traits) {
            traitsJson = String(data: data, encoding: .utf8)
        }

        let request = UpdateRequest(
            backstory: backstory,
            personality_traits: traitsJson,
            speech_patterns: speechPatterns
        )

        return client.request(.updateCharacter(id), body: request)
            .handleEvents(
                receiveOutput: { [weak self] updatedCharacter in
                    if let index = self?.characters.firstIndex(where: { $0.id == id }) {
                        self?.characters[index] = updatedCharacter
                    }
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func updateCharacter(
        id: String,
        backstory: String? = nil,
        personalityTraits: [String: Any]? = nil,
        speechPatterns: [String]? = nil
    ) async throws -> Character {
        isLoading = true
        defer { isLoading = false }

        struct UpdateRequest: Codable {
            let backstory: String?
            let personality_traits: String?
            let speech_patterns: [String]?
        }

        var traitsJson: String? = nil
        if let traits = personalityTraits,
           let data = try? JSONSerialization.data(withJSONObject: traits) {
            traitsJson = String(data: data, encoding: .utf8)
        }

        let request = UpdateRequest(
            backstory: backstory,
            personality_traits: traitsJson,
            speech_patterns: speechPatterns
        )

        let updatedCharacter: Character = try await client.request(.updateCharacter(id), body: request)
        if let index = characters.firstIndex(where: { $0.id == id }) {
            characters[index] = updatedCharacter
        }
        return updatedCharacter
    }

    // MARK: - Customization Options

    /// Get available customization options for a character type
    public func fetchCustomizationOptions(
        for characterId: String
    ) -> AnyPublisher<CustomizationOptions, APIError> {
        client.request(.customizationOptions(characterId))
            .handleEvents(
                receiveOutput: { [weak self] options in
                    self?.customizationOptions = options
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func fetchCustomizationOptions(
        for characterId: String
    ) async throws -> CustomizationOptions {
        let options: CustomizationOptions = try await client.request(.customizationOptions(characterId))
        customizationOptions = options
        return options
    }

    // MARK: - Customize Character

    /// Apply customization to a character
    public func customizeCharacter(
        characterId: String,
        customization: CharacterCustomization
    ) -> AnyPublisher<CustomizeCharacterResponse, APIError> {
        isLoading = true

        return client.request(.customizeCharacter(characterId), body: customization)
            .handleEvents(
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func customizeCharacter(
        characterId: String,
        customization: CharacterCustomization
    ) async throws -> CustomizeCharacterResponse {
        isLoading = true
        defer { isLoading = false }

        return try await client.request(.customizeCharacter(characterId), body: customization)
    }

    // MARK: - Preview Prompt

    /// Preview the generated prompt for a character
    public func previewPrompt(
        for characterId: String,
        userId: String? = nil
    ) -> AnyPublisher<PreviewPromptResponse, APIError> {
        var queryItems: [URLQueryItem] = []
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: userId))
        }

        return client.request(
            .previewPrompt(characterId),
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func previewPrompt(
        for characterId: String,
        userId: String? = nil
    ) async throws -> PreviewPromptResponse {
        var queryItems: [URLQueryItem] = []
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: userId))
        }

        return try await client.request(
            .previewPrompt(characterId),
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }
}

// MARK: - Character Builder

/// Fluent API for building character customizations
public class CharacterCustomizationBuilder {
    private var customization: CharacterCustomization

    public init() {
        customization = CharacterCustomization()
    }

    @discardableResult
    public func name(_ name: String) -> Self {
        customization = CharacterCustomization(
            name: name,
            age: customization.age,
            background: customization.background,
            personalityTraits: customization.personalityTraits,
            interests: customization.interests,
            speechStyle: customization.speechStyle,
            tone: customization.tone,
            relationshipToUser: customization.relationshipToUser,
            specialKnowledge: customization.specialKnowledge,
            quirks: customization.quirks,
            emotionalState: customization.emotionalState,
            conversationStyle: customization.conversationStyle,
            boundaries: customization.boundaries
        )
        return self
    }

    @discardableResult
    public func age(_ age: Int) -> Self {
        customization = CharacterCustomization(
            name: customization.name,
            age: age,
            background: customization.background,
            personalityTraits: customization.personalityTraits,
            interests: customization.interests,
            speechStyle: customization.speechStyle,
            tone: customization.tone,
            relationshipToUser: customization.relationshipToUser,
            specialKnowledge: customization.specialKnowledge,
            quirks: customization.quirks,
            emotionalState: customization.emotionalState,
            conversationStyle: customization.conversationStyle,
            boundaries: customization.boundaries
        )
        return self
    }

    @discardableResult
    public func background(_ background: String) -> Self {
        customization = CharacterCustomization(
            name: customization.name,
            age: customization.age,
            background: background,
            personalityTraits: customization.personalityTraits,
            interests: customization.interests,
            speechStyle: customization.speechStyle,
            tone: customization.tone,
            relationshipToUser: customization.relationshipToUser,
            specialKnowledge: customization.specialKnowledge,
            quirks: customization.quirks,
            emotionalState: customization.emotionalState,
            conversationStyle: customization.conversationStyle,
            boundaries: customization.boundaries
        )
        return self
    }

    @discardableResult
    public func personalityTraits(_ traits: String) -> Self {
        customization = CharacterCustomization(
            name: customization.name,
            age: customization.age,
            background: customization.background,
            personalityTraits: traits,
            interests: customization.interests,
            speechStyle: customization.speechStyle,
            tone: customization.tone,
            relationshipToUser: customization.relationshipToUser,
            specialKnowledge: customization.specialKnowledge,
            quirks: customization.quirks,
            emotionalState: customization.emotionalState,
            conversationStyle: customization.conversationStyle,
            boundaries: customization.boundaries
        )
        return self
    }

    @discardableResult
    public func interests(_ interests: [String]) -> Self {
        customization = CharacterCustomization(
            name: customization.name,
            age: customization.age,
            background: customization.background,
            personalityTraits: customization.personalityTraits,
            interests: interests,
            speechStyle: customization.speechStyle,
            tone: customization.tone,
            relationshipToUser: customization.relationshipToUser,
            specialKnowledge: customization.specialKnowledge,
            quirks: customization.quirks,
            emotionalState: customization.emotionalState,
            conversationStyle: customization.conversationStyle,
            boundaries: customization.boundaries
        )
        return self
    }

    @discardableResult
    public func speechStyle(_ style: String) -> Self {
        customization = CharacterCustomization(
            name: customization.name,
            age: customization.age,
            background: customization.background,
            personalityTraits: customization.personalityTraits,
            interests: customization.interests,
            speechStyle: style,
            tone: customization.tone,
            relationshipToUser: customization.relationshipToUser,
            specialKnowledge: customization.specialKnowledge,
            quirks: customization.quirks,
            emotionalState: customization.emotionalState,
            conversationStyle: customization.conversationStyle,
            boundaries: customization.boundaries
        )
        return self
    }

    @discardableResult
    public func tone(_ tone: String) -> Self {
        customization = CharacterCustomization(
            name: customization.name,
            age: customization.age,
            background: customization.background,
            personalityTraits: customization.personalityTraits,
            interests: customization.interests,
            speechStyle: customization.speechStyle,
            tone: tone,
            relationshipToUser: customization.relationshipToUser,
            specialKnowledge: customization.specialKnowledge,
            quirks: customization.quirks,
            emotionalState: customization.emotionalState,
            conversationStyle: customization.conversationStyle,
            boundaries: customization.boundaries
        )
        return self
    }

    @discardableResult
    public func relationshipToUser(_ relationship: String) -> Self {
        customization = CharacterCustomization(
            name: customization.name,
            age: customization.age,
            background: customization.background,
            personalityTraits: customization.personalityTraits,
            interests: customization.interests,
            speechStyle: customization.speechStyle,
            tone: customization.tone,
            relationshipToUser: relationship,
            specialKnowledge: customization.specialKnowledge,
            quirks: customization.quirks,
            emotionalState: customization.emotionalState,
            conversationStyle: customization.conversationStyle,
            boundaries: customization.boundaries
        )
        return self
    }

    @discardableResult
    public func conversationStyle(_ style: String) -> Self {
        customization = CharacterCustomization(
            name: customization.name,
            age: customization.age,
            background: customization.background,
            personalityTraits: customization.personalityTraits,
            interests: customization.interests,
            speechStyle: customization.speechStyle,
            tone: customization.tone,
            relationshipToUser: customization.relationshipToUser,
            specialKnowledge: customization.specialKnowledge,
            quirks: customization.quirks,
            emotionalState: customization.emotionalState,
            conversationStyle: style,
            boundaries: customization.boundaries
        )
        return self
    }

    public func build() -> CharacterCustomization {
        return customization
    }
}
