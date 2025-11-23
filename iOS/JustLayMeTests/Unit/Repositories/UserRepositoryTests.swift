import XCTest
import Combine
@testable import JustLayMe

final class UserRepositoryTests: XCTestCase {

    var sut: UserRepository!
    var mockAPIClient: MockAPIClient!
    var mockKeychain: MockKeychainService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        mockKeychain = MockKeychainService()
        sut = UserRepository(apiClient: mockAPIClient, keychain: mockKeychain)
        cancellables = []
    }

    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        mockKeychain = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertNil(sut.currentUser)
        XCTAssertFalse(sut.isAuthenticated)
    }

    // MARK: - Set User Tests

    func testSetUser() {
        // Given
        let user = MockDataFactory.createUser()

        // When
        sut.setUser(user)

        // Then
        XCTAssertEqual(sut.currentUser, user)
        XCTAssertTrue(sut.isAuthenticated)
    }

    func testSetUserNil() {
        // Given
        sut.setUser(MockDataFactory.createUser())
        XCTAssertTrue(sut.isAuthenticated)

        // When
        sut.setUser(nil)

        // Then
        XCTAssertNil(sut.currentUser)
        XCTAssertFalse(sut.isAuthenticated)
    }

    // MARK: - Update Subscription Tests

    func testUpdateSubscription() {
        // Given
        let user = MockDataFactory.createFreeUser()
        sut.setUser(user)
        let endDate = Date.nextMonth

        // When
        sut.updateSubscription(.premium, endDate: endDate)

        // Then
        XCTAssertEqual(sut.currentUser?.subscriptionStatus, .premium)
        XCTAssertEqual(sut.currentUser?.subscriptionEnd, endDate)
    }

    func testUpdateSubscriptionWithoutUser() {
        // Given
        XCTAssertNil(sut.currentUser)

        // When
        sut.updateSubscription(.premium, endDate: Date.nextMonth)

        // Then - should not crash
        XCTAssertNil(sut.currentUser)
    }

    // MARK: - Message Count Tests

    func testUpdateMessageCount() {
        // Given
        let user = MockDataFactory.createUser(messageCount: 0)
        sut.setUser(user)

        // When
        sut.updateMessageCount(50)

        // Then
        XCTAssertEqual(sut.currentUser?.messageCount, 50)
    }

    func testIncrementMessageCount() {
        // Given
        let user = MockDataFactory.createUser(messageCount: 10)
        sut.setUser(user)

        // When
        sut.incrementMessageCount()
        sut.incrementMessageCount()
        sut.incrementMessageCount()

        // Then
        XCTAssertEqual(sut.currentUser?.messageCount, 13)
    }

    func testIncrementMessageCountWithoutUser() {
        // Given
        XCTAssertNil(sut.currentUser)

        // When
        sut.incrementMessageCount()

        // Then - should not crash
        XCTAssertNil(sut.currentUser)
    }

    // MARK: - Clear Tests

    func testClear() {
        // Given
        sut.setUser(MockDataFactory.createUser())
        XCTAssertTrue(sut.isAuthenticated)

        // When
        sut.clear()

        // Then
        XCTAssertNil(sut.currentUser)
        XCTAssertFalse(sut.isAuthenticated)
    }

    // MARK: - Published Property Tests

    func testUserPublisherEmitsChanges() async {
        // Given
        var receivedUsers: [User?] = []
        let expectation = XCTestExpectation(description: "Receive user updates")
        expectation.expectedFulfillmentCount = 3

        sut.$currentUser
            .sink { user in
                receivedUsers.append(user)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        let user1 = MockDataFactory.createUser(email: "user1@test.com")
        let user2 = MockDataFactory.createUser(email: "user2@test.com")

        sut.setUser(user1)
        sut.setUser(user2)

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedUsers.count, 3) // nil, user1, user2
        XCTAssertNil(receivedUsers[0])
        XCTAssertEqual(receivedUsers[1]?.email, "user1@test.com")
        XCTAssertEqual(receivedUsers[2]?.email, "user2@test.com")
    }

    func testIsAuthenticatedPublisherEmitsChanges() async {
        // Given
        var receivedValues: [Bool] = []
        let expectation = XCTestExpectation(description: "Receive auth updates")
        expectation.expectedFulfillmentCount = 3

        sut.$isAuthenticated
            .sink { isAuth in
                receivedValues.append(isAuth)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        sut.setUser(MockDataFactory.createUser())
        sut.setUser(nil)

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues, [false, true, false])
    }
}
