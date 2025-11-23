import XCTest
import Combine
@testable import JustLayMe

@MainActor
final class CharacterViewModelTests: ViewModelTestCase {

    var sut: CharacterViewModel!

    override func setUp() {
        super.setUp()
        sut = CharacterViewModel(apiClient: env.mockAPIClient, userRepository: env.mockUserRepository)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(sut.state, .idle)
        XCTAssertTrue(sut.characters.isEmpty)
        XCTAssertNil(sut.selectedCharacter)
        XCTAssertTrue(sut.characterName.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isFormValid)
    }

    // MARK: - Load Characters Tests

    func testLoadCharactersSuccess() async {
        // Given
        let characters = MockDataFactory.createCharacters(count: 3)
        env.mockAPIClient.stub(endpoint: "/api/characters", with: characters)

        // When
        await sut.loadCharacters()

        // Then
        XCTAssertEqual(sut.characters.count, 3)
        if case .loaded(let loadedChars) = sut.state {
            XCTAssertEqual(loadedChars.count, 3)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func testLoadCharactersEmpty() async {
        // Given
        let characters: [AICharacter] = []
        env.mockAPIClient.stub(endpoint: "/api/characters", with: characters)

        // When
        await sut.loadCharacters()

        // Then
        XCTAssertTrue(sut.characters.isEmpty)
        if case .loaded(let loadedChars) = sut.state {
            XCTAssertTrue(loadedChars.isEmpty)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func testLoadCharactersError() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .serverError(500)

        // When
        await sut.loadCharacters()

        // Then
        if case .error(.networkError) = sut.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected error state")
        }
    }

    // MARK: - Create Character Tests

    func testCreateCharacterSuccess() async {
        // Given
        let newCharacter = MockDataFactory.createCharacter(name: "New Character")
        env.mockAPIClient.stub(endpoint: "/api/characters", with: newCharacter)
        env.mockUserRepository.currentUser = MockDataFactory.createFreeUser()

        sut.characterName = "New Character"
        sut.characterBackstory = "A mysterious companion"

        // When
        let result = await sut.createCharacter()

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(sut.characters.count, 1)
        XCTAssertTrue(sut.characterName.isEmpty) // Form cleared
    }

    func testCreateCharacterInvalidForm() async {
        // Given
        sut.characterName = ""

        // When
        let result = await sut.createCharacter()

        // Then
        XCTAssertFalse(result)
        XCTAssertEqual(env.mockAPIClient.requestCallCount, 0)
    }

    func testCreateCharacterLimitReachedFreeUser() async {
        // Given - free user with 1 existing character
        env.mockUserRepository.currentUser = MockDataFactory.createFreeUser()
        sut.characters = [MockDataFactory.createCharacter()]

        sut.characterName = "Second Character"

        // When
        let result = await sut.createCharacter()

        // Then
        XCTAssertFalse(result)
        XCTAssertEqual(sut.state, .error(.limitReached))
    }

    func testPremiumUserCanCreateMultipleCharacters() async {
        // Given
        env.mockUserRepository.currentUser = MockDataFactory.createPremiumUser()
        sut.characters = [MockDataFactory.createCharacter()]

        let newCharacter = MockDataFactory.createCharacter(name: "Second Character")
        env.mockAPIClient.stub(endpoint: "/api/characters", with: newCharacter)

        sut.characterName = "Second Character"

        // When
        let result = await sut.createCharacter()

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(sut.characters.count, 2)
    }

    // MARK: - Update Character Tests

    func testUpdateCharacterSuccess() async {
        // Given
        var character = MockDataFactory.createCharacter()
        sut.characters = [character]

        character.backstory = "Updated backstory"
        env.mockAPIClient.stub(endpoint: "/api/characters/\(character.id)", with: character)

        // When
        let result = await sut.updateCharacter(character)

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(sut.characters.first?.backstory, "Updated backstory")
    }

    func testUpdateCharacterNotFound() async {
        // Given
        let character = MockDataFactory.createCharacter()
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .notFound

        // When
        let result = await sut.updateCharacter(character)

        // Then
        XCTAssertFalse(result)
        XCTAssertEqual(sut.state, .error(.notFound))
    }

    // MARK: - Select Character Tests

    func testSelectCharacter() {
        // Given
        let character = MockDataFactory.createCharacter(
            name: "Test Char",
            backstory: "A backstory",
            personalityTraits: ["friendly": 8],
            speechPatterns: ["Casual"]
        )

        // When
        sut.selectCharacter(character)

        // Then
        XCTAssertEqual(sut.selectedCharacter, character)
        XCTAssertEqual(sut.characterName, "Test Char")
        XCTAssertEqual(sut.characterBackstory, "A backstory")
        XCTAssertEqual(sut.selectedTraits["friendly"], 8)
        XCTAssertTrue(sut.speechPatterns.contains("Casual"))
    }

    // MARK: - Trait Management Tests

    func testAddTrait() {
        // When
        sut.addTrait("friendly", value: 8)
        sut.addTrait("humor", value: 5)

        // Then
        XCTAssertEqual(sut.selectedTraits.count, 2)
        XCTAssertEqual(sut.selectedTraits["friendly"], 8)
        XCTAssertEqual(sut.selectedTraits["humor"], 5)
    }

    func testAddTraitClampsValue() {
        // When
        sut.addTrait("extreme_low", value: -5)
        sut.addTrait("extreme_high", value: 15)

        // Then
        XCTAssertEqual(sut.selectedTraits["extreme_low"], 1)
        XCTAssertEqual(sut.selectedTraits["extreme_high"], 10)
    }

    func testRemoveTrait() {
        // Given
        sut.addTrait("friendly", value: 8)
        sut.addTrait("humor", value: 5)

        // When
        sut.removeTrait("friendly")

        // Then
        XCTAssertEqual(sut.selectedTraits.count, 1)
        XCTAssertNil(sut.selectedTraits["friendly"])
    }

    // MARK: - Speech Pattern Management Tests

    func testAddSpeechPattern() {
        // When
        sut.addSpeechPattern("Uses casual language")
        sut.addSpeechPattern("Makes jokes")

        // Then
        XCTAssertEqual(sut.speechPatterns.count, 2)
        XCTAssertTrue(sut.speechPatterns.contains("Uses casual language"))
    }

    func testAddDuplicateSpeechPattern() {
        // Given
        sut.addSpeechPattern("Uses casual language")

        // When
        sut.addSpeechPattern("Uses casual language")

        // Then
        XCTAssertEqual(sut.speechPatterns.count, 1)
    }

    func testAddEmptySpeechPattern() {
        // When
        sut.addSpeechPattern("")

        // Then
        XCTAssertTrue(sut.speechPatterns.isEmpty)
    }

    func testRemoveSpeechPattern() {
        // Given
        sut.addSpeechPattern("Pattern 1")
        sut.addSpeechPattern("Pattern 2")

        // When
        sut.removeSpeechPattern("Pattern 1")

        // Then
        XCTAssertEqual(sut.speechPatterns.count, 1)
        XCTAssertFalse(sut.speechPatterns.contains("Pattern 1"))
    }

    // MARK: - Form Validation Tests

    func testIsFormValid() {
        XCTAssertFalse(sut.isFormValid)

        sut.characterName = "Test"
        XCTAssertTrue(sut.isFormValid)

        sut.characterName = "   "
        XCTAssertFalse(sut.isFormValid)
    }

    // MARK: - Clear Form Tests

    func testClearForm() {
        // Given
        sut.characterName = "Test"
        sut.characterBackstory = "Backstory"
        sut.addTrait("friendly", value: 8)
        sut.addSpeechPattern("Casual")
        sut.selectedCharacter = MockDataFactory.createCharacter()

        // When
        sut.clearForm()

        // Then
        XCTAssertTrue(sut.characterName.isEmpty)
        XCTAssertTrue(sut.characterBackstory.isEmpty)
        XCTAssertTrue(sut.selectedTraits.isEmpty)
        XCTAssertTrue(sut.speechPatterns.isEmpty)
        XCTAssertNil(sut.selectedCharacter)
    }

    // MARK: - Can Create Character Tests

    func testCanCreateCharacterFreeUser() {
        // Given
        env.mockUserRepository.currentUser = MockDataFactory.createFreeUser()

        // Then - can create first character
        XCTAssertTrue(sut.canCreateCharacter)

        // Given - already has one character
        sut.characters = [MockDataFactory.createCharacter()]

        // Then - cannot create more
        XCTAssertFalse(sut.canCreateCharacter)
    }

    func testCanCreateCharacterPremiumUser() {
        // Given
        env.mockUserRepository.currentUser = MockDataFactory.createPremiumUser()
        sut.characters = MockDataFactory.createCharacters(count: 5)

        // Then
        XCTAssertTrue(sut.canCreateCharacter)
    }

    func testCanCreateCharacterNoUser() {
        // Given
        env.mockUserRepository.currentUser = nil

        // Then
        XCTAssertFalse(sut.canCreateCharacter)
    }

    // MARK: - Customization Options Tests

    func testLoadCustomizationOptions() async {
        // Given
        let options = MockDataFactory.createCustomizationOptions()
        env.mockAPIClient.stub(endpoint: "/api/characters/test/customization-options", with: options)

        // When
        await sut.loadCustomizationOptions(for: "test")

        // Then
        XCTAssertNotNil(sut.customizationOptions)
        XCTAssertEqual(sut.customizationOptions?.personalityTraits.count, 5)
    }

    // MARK: - Clear Error Tests

    func testClearError() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .serverError(500)
        await sut.loadCharacters()

        // When
        sut.clearError()

        // Then
        XCTAssertEqual(sut.state, .idle)
    }

    func testClearErrorWithExistingCharacters() async {
        // Given - load characters first
        let characters = MockDataFactory.createCharacters(count: 2)
        env.mockAPIClient.stub(endpoint: "/api/characters", with: characters)
        await sut.loadCharacters()

        // Create error state
        env.mockUserRepository.currentUser = MockDataFactory.createFreeUser()
        sut.characterName = "New"
        _ = await sut.createCharacter()

        // When
        sut.clearError()

        // Then
        if case .loaded(let loadedChars) = sut.state {
            XCTAssertEqual(loadedChars.count, 2)
        } else {
            XCTFail("Expected loaded state")
        }
    }
}
