import XCTest
import Combine
@testable import JustLayMe

final class CharacterRepositoryTests: XCTestCase {

    var sut: CharacterRepository!
    var mockAPIClient: MockAPIClient!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = CharacterRepository(apiClient: mockAPIClient)
        cancellables = []
    }

    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertTrue(sut.characters.isEmpty)
        XCTAssertNil(sut.customizationOptions)
    }

    // MARK: - Load Characters Tests

    @MainActor
    func testLoadCharactersSuccess() async throws {
        // Given
        let characters = MockDataFactory.createCharacters(count: 5)
        mockAPIClient.stub(endpoint: "/api/characters", with: characters)

        // When
        let result = try await sut.loadCharacters()

        // Then
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(sut.characters.count, 5)
    }

    @MainActor
    func testLoadCharactersEmpty() async throws {
        // Given
        let characters: [AICharacter] = []
        mockAPIClient.stub(endpoint: "/api/characters", with: characters)

        // When
        let result = try await sut.loadCharacters()

        // Then
        XCTAssertTrue(result.isEmpty)
    }

    @MainActor
    func testLoadCharactersError() async {
        // Given
        mockAPIClient.shouldFail = true
        mockAPIClient.errorToThrow = .serverError(500)

        // When/Then
        do {
            _ = try await sut.loadCharacters()
            XCTFail("Expected error")
        } catch let error as APIError {
            XCTAssertEqual(error, .serverError(500))
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - Load Customization Options Tests

    @MainActor
    func testLoadCustomizationOptionsSuccess() async throws {
        // Given
        let options = MockDataFactory.createCustomizationOptions()
        mockAPIClient.stub(endpoint: "/api/characters/test/customization-options", with: options)

        // When
        let result = try await sut.loadCustomizationOptions(for: "test")

        // Then
        XCTAssertEqual(result.personalityTraits.count, 5)
        XCTAssertEqual(sut.customizationOptions, options)
    }

    // MARK: - Create Character Tests

    @MainActor
    func testCreateCharacterSuccess() async throws {
        // Given
        let newCharacter = MockDataFactory.createCharacter(name: "New Character")
        mockAPIClient.stub(endpoint: "/api/characters", with: newCharacter)

        // When
        let result = try await sut.createCharacter(newCharacter)

        // Then
        XCTAssertEqual(result.name, "New Character")
        XCTAssertEqual(sut.characters.count, 1)
        XCTAssertEqual(sut.characters.first?.name, "New Character")
    }

    @MainActor
    func testCreateCharacterAppendsToExisting() async throws {
        // Given
        sut.characters = MockDataFactory.createCharacters(count: 2)
        let newCharacter = MockDataFactory.createCharacter(name: "Third Character")
        mockAPIClient.stub(endpoint: "/api/characters", with: newCharacter)

        // When
        _ = try await sut.createCharacter(newCharacter)

        // Then
        XCTAssertEqual(sut.characters.count, 3)
    }

    // MARK: - Update Character Tests

    @MainActor
    func testUpdateCharacterSuccess() async throws {
        // Given
        var character = MockDataFactory.createCharacter()
        sut.characters = [character]

        character.backstory = "Updated backstory"
        mockAPIClient.stub(endpoint: "/api/characters/\(character.id)", with: character)

        // When
        let result = try await sut.updateCharacter(character)

        // Then
        XCTAssertEqual(result.backstory, "Updated backstory")
        XCTAssertEqual(sut.characters.first?.backstory, "Updated backstory")
    }

    @MainActor
    func testUpdateCharacterNotInList() async throws {
        // Given
        let character = MockDataFactory.createCharacter()
        sut.characters = [] // Empty list
        mockAPIClient.stub(endpoint: "/api/characters/\(character.id)", with: character)

        // When
        let result = try await sut.updateCharacter(character)

        // Then - returns updated but doesn't add to list
        XCTAssertEqual(result.id, character.id)
        XCTAssertTrue(sut.characters.isEmpty)
    }

    // MARK: - Delete Character Tests

    @MainActor
    func testDeleteCharacterSuccess() async throws {
        // Given
        let characters = MockDataFactory.createCharacters(count: 3)
        sut.characters = characters
        let characterToDelete = characters[1]

        // When
        try await sut.deleteCharacter(id: characterToDelete.id)

        // Then
        XCTAssertEqual(sut.characters.count, 2)
        XCTAssertFalse(sut.characters.contains(where: { $0.id == characterToDelete.id }))
    }

    // MARK: - Clear Cache Tests

    @MainActor
    func testClearCache() {
        // Given
        sut.characters = MockDataFactory.createCharacters(count: 3)
        sut.customizationOptions = MockDataFactory.createCustomizationOptions()

        // When
        sut.clearCache()

        // Then
        XCTAssertTrue(sut.characters.isEmpty)
        XCTAssertNil(sut.customizationOptions)
    }

    // MARK: - Publisher Tests

    @MainActor
    func testCharactersPublisherEmitsChanges() async {
        // Given
        var receivedCharacters: [[AICharacter]] = []
        let expectation = XCTestExpectation(description: "Receive character updates")
        expectation.expectedFulfillmentCount = 2

        sut.$characters
            .sink { characters in
                receivedCharacters.append(characters)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        let newCharacter = MockDataFactory.createCharacter()
        mockAPIClient.stub(endpoint: "/api/characters", with: newCharacter)
        _ = try? await sut.createCharacter(newCharacter)

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedCharacters.first?.count, 0)
        XCTAssertEqual(receivedCharacters.last?.count, 1)
    }
}
