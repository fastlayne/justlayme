import XCTest
import Combine
@testable import JustLayMe

@MainActor
final class ProfileViewModelTests: ViewModelTestCase {

    var sut: ProfileViewModel!

    override func setUp() {
        super.setUp()
        sut = ProfileViewModel(apiClient: env.mockAPIClient)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(sut.state, .idle)
        XCTAssertNil(sut.user)
        XCTAssertTrue(sut.editableName.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.hasChanges)
    }

    // MARK: - Load Profile Tests

    func testLoadProfileSuccess() async {
        // Given
        let user = MockDataFactory.createUser(name: "John Doe")
        env.mockAPIClient.stub(endpoint: "/api/profile", with: user)

        // When
        await sut.loadProfile()

        // Then
        XCTAssertEqual(sut.user, user)
        XCTAssertEqual(sut.editableName, "John Doe")
        if case .loaded(let loadedUser) = sut.state {
            XCTAssertEqual(loadedUser, user)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func testLoadProfileWithNilName() async {
        // Given
        let user = MockDataFactory.createUser(name: nil)
        env.mockAPIClient.stub(endpoint: "/api/profile", with: user)

        // When
        await sut.loadProfile()

        // Then
        XCTAssertTrue(sut.editableName.isEmpty)
    }

    func testLoadProfileUnauthorized() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .unauthorized

        // When
        await sut.loadProfile()

        // Then
        XCTAssertEqual(sut.state, .error(.notAuthenticated))
    }

    func testLoadProfileServerError() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .serverError(500)

        // When
        await sut.loadProfile()

        // Then
        XCTAssertEqual(sut.state, .error(.loadFailed))
    }

    // MARK: - Update Profile Tests

    func testUpdateProfileSuccess() async {
        // Given
        let user = MockDataFactory.createUser(name: "John Doe")
        env.mockAPIClient.stub(endpoint: "/api/profile", with: user)
        await sut.loadProfile()

        sut.editableName = "Jane Doe"

        // When
        let result = await sut.updateProfile()

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(sut.user?.name, "Jane Doe")
    }

    func testUpdateProfileNoChanges() async {
        // Given
        let user = MockDataFactory.createUser(name: "John Doe")
        env.mockAPIClient.stub(endpoint: "/api/profile", with: user)
        await sut.loadProfile()

        // editableName is already "John Doe", no changes

        // When
        let result = await sut.updateProfile()

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(env.mockAPIClient.requestCallCount, 1) // Only initial load
    }

    func testUpdateProfileClearName() async {
        // Given
        let user = MockDataFactory.createUser(name: "John Doe")
        env.mockAPIClient.stub(endpoint: "/api/profile", with: user)
        await sut.loadProfile()

        sut.editableName = ""

        // When
        let result = await sut.updateProfile()

        // Then
        XCTAssertTrue(result)
        XCTAssertNil(sut.user?.name)
    }

    func testUpdateProfileFailed() async {
        // Given
        let user = MockDataFactory.createUser(name: "John Doe")
        env.mockAPIClient.stub(endpoint: "/api/profile", with: user)
        await sut.loadProfile()

        sut.editableName = "Jane Doe"
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .serverError(500)

        // When
        let result = await sut.updateProfile()

        // Then
        XCTAssertFalse(result)
        if case .error(.updateFailed) = sut.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected updateFailed error")
        }
    }

    // MARK: - Has Changes Tests

    func testHasChanges() async {
        // Given
        let user = MockDataFactory.createUser(name: "John Doe")
        env.mockAPIClient.stub(endpoint: "/api/profile", with: user)
        await sut.loadProfile()

        // Then - no changes initially
        XCTAssertFalse(sut.hasChanges)

        // When - make change
        sut.editableName = "Jane Doe"

        // Then
        XCTAssertTrue(sut.hasChanges)

        // When - revert change
        sut.editableName = "John Doe"

        // Then
        XCTAssertFalse(sut.hasChanges)
    }

    // MARK: - Export Data Tests

    func testExportDataSuccess() async {
        // Given
        let exportData = MockDataFactory.createExportData()
        env.mockAPIClient.stub(endpoint: "/api/export-data", with: exportData)

        // When
        let url = await sut.exportData()

        // Then
        XCTAssertNotNil(url)
        if case .exported(let exportedURL) = sut.state {
            XCTAssertEqual(exportedURL, url)
        } else {
            XCTFail("Expected exported state")
        }
    }

    func testExportDataFailure() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .serverError(500)

        // When
        let url = await sut.exportData()

        // Then
        XCTAssertNil(url)
        XCTAssertEqual(sut.state, .error(.exportFailed))
    }

    func testExportShowsExportingState() async {
        // Given
        let exportData = MockDataFactory.createExportData()
        env.mockAPIClient.stub(endpoint: "/api/export-data", with: exportData)
        env.mockAPIClient.delay = 0.1

        var states: [ProfileState] = []
        let cancellable = sut.$state.sink { states.append($0) }

        // When
        _ = await sut.exportData()

        // Then
        XCTAssertTrue(states.contains(.exporting))
        cancellable.cancel()
    }

    // MARK: - Clear Data Tests

    func testClearDataSuccess() async {
        // Given
        let user = MockDataFactory.createUser()
        env.mockAPIClient.stub(endpoint: "/api/profile", with: user)
        await sut.loadProfile()

        // When
        let result = await sut.clearAllData()

        // Then
        XCTAssertTrue(result)
    }

    func testClearDataFailure() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .serverError(500)

        // When
        let result = await sut.clearAllData()

        // Then
        XCTAssertFalse(result)
        XCTAssertEqual(sut.state, .error(.clearDataFailed))
    }

    // MARK: - Reset Changes Tests

    func testResetChanges() async {
        // Given
        let user = MockDataFactory.createUser(name: "Original Name")
        env.mockAPIClient.stub(endpoint: "/api/profile", with: user)
        await sut.loadProfile()

        sut.editableName = "Changed Name"
        XCTAssertTrue(sut.hasChanges)

        // When
        sut.resetChanges()

        // Then
        XCTAssertEqual(sut.editableName, "Original Name")
        XCTAssertFalse(sut.hasChanges)
    }

    // MARK: - Date Formatting Tests

    func testMemberSince() async {
        // Given
        let createdAt = Date.from(year: 2024, month: 1, day: 15)
        let user = MockDataFactory.createUser(createdAt: createdAt)
        env.mockAPIClient.stub(endpoint: "/api/profile", with: user)

        // When
        await sut.loadProfile()

        // Then
        XCTAssertFalse(sut.memberSince.isEmpty)
        XCTAssertNotEqual(sut.memberSince, "Unknown")
    }

    func testMemberSinceNoDate() {
        XCTAssertEqual(sut.memberSince, "Unknown")
    }

    func testLastActive() async {
        // Given
        let lastLogin = Date()
        let user = MockDataFactory.createUser(lastLogin: lastLogin)
        env.mockAPIClient.stub(endpoint: "/api/profile", with: user)

        // When
        await sut.loadProfile()

        // Then
        XCTAssertFalse(sut.lastActive.isEmpty)
        XCTAssertNotEqual(sut.lastActive, "Unknown")
    }

    // MARK: - Clear Error Tests

    func testClearError() async {
        // Given
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .unauthorized
        await sut.loadProfile()

        // When
        sut.clearError()

        // Then
        XCTAssertEqual(sut.state, .idle)
    }

    func testClearErrorWithLoadedUser() async {
        // Given
        let user = MockDataFactory.createUser()
        env.mockAPIClient.stub(endpoint: "/api/profile", with: user)
        await sut.loadProfile()

        // Create error state
        sut.editableName = "New Name"
        env.mockAPIClient.shouldFail = true
        env.mockAPIClient.errorToThrow = .serverError(500)
        _ = await sut.updateProfile()

        // When
        sut.clearError()

        // Then
        if case .loaded = sut.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected loaded state")
        }
    }
}
