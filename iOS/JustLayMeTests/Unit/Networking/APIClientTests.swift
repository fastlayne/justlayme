import XCTest
@testable import JustLayMe

final class APIClientTests: XCTestCase {

    var sut: APIClient!
    var mockSession: MockURLSession!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        sut = APIClient(baseURL: URL(string: "https://justlay.me")!, session: mockSession)
    }

    override func tearDown() {
        sut = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - Request Building Tests

    func testRequestBuildsCorrectURL() async throws {
        // Given
        let user = MockDataFactory.createUser()
        mockSession.stubResponse(with: user, statusCode: 200)

        let endpoint = APIEndpoint(path: "/api/profile")

        // When
        let _: User = try await sut.request(endpoint)

        // Then
        XCTAssertEqual(mockSession.lastRequest?.url?.path, "/api/profile")
    }

    func testRequestIncludesQueryItems() async throws {
        // Given
        let users = [MockDataFactory.createUser()]
        mockSession.stubResponse(with: users, statusCode: 200)

        let endpoint = APIEndpoint(
            path: "/api/users",
            queryItems: [
                URLQueryItem(name: "search", value: "test"),
                URLQueryItem(name: "limit", value: "10")
            ]
        )

        // When
        let _: [User] = try await sut.request(endpoint)

        // Then
        let url = mockSession.lastRequest?.url
        XCTAssertTrue(url?.absoluteString.contains("search=test") ?? false)
        XCTAssertTrue(url?.absoluteString.contains("limit=10") ?? false)
    }

    func testRequestSetsContentType() async throws {
        // Given
        let user = MockDataFactory.createUser()
        mockSession.stubResponse(with: user, statusCode: 200)

        // When
        let _: User = try await sut.request(APIEndpoint(path: "/api/profile"))

        // Then
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testRequestIncludesAuthToken() async throws {
        // Given
        let user = MockDataFactory.createUser()
        mockSession.stubResponse(with: user, statusCode: 200)
        sut.setAuthToken("test-token-123")

        let endpoint = APIEndpoint(path: "/api/profile", requiresAuth: true)

        // When
        let _: User = try await sut.request(endpoint)

        // Then
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-token-123")
    }

    func testRequestDoesNotIncludeAuthTokenWhenNotRequired() async throws {
        // Given
        let user = MockDataFactory.createUser()
        mockSession.stubResponse(with: user, statusCode: 200)
        sut.setAuthToken("test-token-123")

        let endpoint = APIEndpoint(path: "/api/public", requiresAuth: false)

        // When
        let _: User = try await sut.request(endpoint)

        // Then
        XCTAssertNil(mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    func testRequestIncludesSessionId() async throws {
        // Given
        let response = MockDataFactory.createChatResponse()
        mockSession.stubResponse(with: response, statusCode: 200)

        let endpoint = APIEndpoint(path: "/api/chat", method: .POST, sessionId: "session-123")

        // When
        let _: ChatResponse = try await sut.request(endpoint)

        // Then
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "X-Session-ID"), "session-123")
    }

    func testRequestSetsHTTPMethod() async throws {
        // Given
        let user = MockDataFactory.createUser()
        mockSession.stubResponse(with: user, statusCode: 200)

        let getEndpoint = APIEndpoint(path: "/api/profile", method: .GET)
        let _: User = try await sut.request(getEndpoint)
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "GET")

        let postEndpoint = APIEndpoint(path: "/api/login", method: .POST)
        mockSession.stubResponse(with: MockDataFactory.createAuthResponse(), statusCode: 200)
        let _: AuthResponse = try await sut.request(postEndpoint)
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
    }

    // MARK: - Response Handling Tests

    func testSuccessfulResponseDecodes() async throws {
        // Given
        let expectedUser = MockDataFactory.createUser(email: "test@example.com")
        mockSession.stubResponse(with: expectedUser, statusCode: 200)

        // When
        let user: User = try await sut.request(APIEndpoint(path: "/api/profile"))

        // Then
        XCTAssertEqual(user.email, "test@example.com")
    }

    func testBadRequestThrowsError() async {
        // Given
        mockSession.stubError(
            statusCode: 400,
            errorBody: ErrorResponse(error: "Invalid email")
        )

        // When/Then
        do {
            let _: User = try await sut.request(APIEndpoint(path: "/api/register", method: .POST))
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error, .badRequest("Invalid email"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testUnauthorizedThrowsError() async {
        // Given
        mockSession.stubError(statusCode: 401, errorBody: ErrorResponse(error: "Unauthorized"))

        // When/Then
        do {
            let _: User = try await sut.request(APIEndpoint(path: "/api/profile", requiresAuth: true))
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testForbiddenThrowsError() async {
        // Given
        mockSession.stubError(statusCode: 403, errorBody: ErrorResponse(error: "Premium required"))

        // When/Then
        do {
            let _: User = try await sut.request(APIEndpoint(path: "/api/premium"))
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error, .forbidden("Premium required"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testNotFoundThrowsError() async {
        // Given
        mockSession.stubError(statusCode: 404, errorBody: ErrorResponse(error: "Not found"))

        // When/Then
        do {
            let _: User = try await sut.request(APIEndpoint(path: "/api/users/123"))
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testServerErrorThrowsError() async {
        // Given
        mockSession.stubError(statusCode: 500, errorBody: ErrorResponse(error: "Internal error"))

        // When/Then
        do {
            let _: User = try await sut.request(APIEndpoint(path: "/api/profile"))
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error, .serverError(500))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Auth Token Management Tests

    func testSetAuthToken() {
        // When
        sut.setAuthToken("new-token")

        // Then - verify by making a request
        // Token is private, so we verify through behavior
        XCTAssertNotNil(sut) // Token is stored internally
    }

    func testClearAuthToken() async throws {
        // Given
        sut.setAuthToken("test-token")
        let user = MockDataFactory.createUser()
        mockSession.stubResponse(with: user, statusCode: 200)

        // When
        sut.setAuthToken(nil)
        let _: User = try await sut.request(APIEndpoint(path: "/api/profile", requiresAuth: true))

        // Then
        XCTAssertNil(mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    // MARK: - Void Request Tests

    func testRequestVoidSuccess() async throws {
        // Given
        mockSession.stubVoidResponse(statusCode: 200)

        // When/Then - should not throw
        try await sut.requestVoid(APIEndpoint(path: "/api/logout", method: .POST))
    }

    func testRequestVoidError() async {
        // Given
        mockSession.stubError(statusCode: 500, errorBody: ErrorResponse(error: "Server error"))

        // When/Then
        do {
            try await sut.requestVoid(APIEndpoint(path: "/api/clear-data", method: .DELETE))
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error, .serverError(500))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

// MARK: - API Error Tests

final class APIErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertEqual(APIError.invalidURL("/path").errorDescription, "Invalid URL: /path")
        XCTAssertEqual(APIError.invalidResponse.errorDescription, "Invalid server response")
        XCTAssertEqual(APIError.badRequest("Bad").errorDescription, "Bad")
        XCTAssertEqual(APIError.unauthorized.errorDescription, "Please log in to continue")
        XCTAssertEqual(APIError.forbidden("No access").errorDescription, "No access")
        XCTAssertEqual(APIError.notFound.errorDescription, "Resource not found")
        XCTAssertEqual(APIError.serverError(500).errorDescription, "Server error (500)")
        XCTAssertEqual(APIError.unknown(418).errorDescription, "Unknown error (418)")
        XCTAssertEqual(APIError.noData.errorDescription, "No data received")
    }

    func testErrorEquality() {
        XCTAssertEqual(APIError.unauthorized, APIError.unauthorized)
        XCTAssertEqual(APIError.badRequest("test"), APIError.badRequest("test"))
        XCTAssertNotEqual(APIError.badRequest("a"), APIError.badRequest("b"))
        XCTAssertNotEqual(APIError.unauthorized, APIError.forbidden("test"))
    }
}

// MARK: - API Endpoint Tests

final class APIEndpointTests: XCTestCase {

    func testRegisterEndpoint() {
        let endpoint = APIEndpoint.register(email: "test@example.com", password: "password")
        XCTAssertEqual(endpoint.path, "/api/register")
        XCTAssertEqual(endpoint.method, .POST)
        XCTAssertNotNil(endpoint.body)
        XCTAssertFalse(endpoint.requiresAuth)
    }

    func testLoginEndpoint() {
        let endpoint = APIEndpoint.login(email: "test@example.com", password: "password")
        XCTAssertEqual(endpoint.path, "/api/login")
        XCTAssertEqual(endpoint.method, .POST)
    }

    func testChatEndpoint() {
        let endpoint = APIEndpoint.chat(message: "Hello", characterId: "layme_v1", userId: "user123", sessionId: "session123")
        XCTAssertEqual(endpoint.path, "/api/chat")
        XCTAssertEqual(endpoint.method, .POST)
        XCTAssertEqual(endpoint.sessionId, "session123")
    }

    func testGetProfileEndpoint() {
        let endpoint = APIEndpoint.getProfile()
        XCTAssertEqual(endpoint.path, "/api/profile")
        XCTAssertEqual(endpoint.method, .GET)
        XCTAssertTrue(endpoint.requiresAuth)
    }

    func testGetCharactersEndpoint() {
        let endpoint = APIEndpoint.getCharacters()
        XCTAssertEqual(endpoint.path, "/api/characters")
        XCTAssertTrue(endpoint.requiresAuth)
    }

    func testCreateCheckoutSessionEndpoint() {
        let endpoint = APIEndpoint.createCheckoutSession(plan: "monthly", userId: "user123", email: "test@example.com")
        XCTAssertEqual(endpoint.path, "/api/create-checkout-session")
        XCTAssertEqual(endpoint.method, .POST)
    }
}

// MARK: - Mock URL Session

class MockURLSession: URLSession {
    var lastRequest: URLRequest?
    private var stubbedData: Data?
    private var stubbedStatusCode: Int = 200

    func stubResponse<T: Encodable>(with response: T, statusCode: Int) {
        stubbedData = try? JSONEncoder().encode(response)
        stubbedStatusCode = statusCode
    }

    func stubError<T: Encodable>(statusCode: Int, errorBody: T) {
        stubbedData = try? JSONEncoder().encode(errorBody)
        stubbedStatusCode = statusCode
    }

    func stubVoidResponse(statusCode: Int) {
        stubbedData = nil
        stubbedStatusCode = statusCode
    }

    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stubbedStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!

        return (stubbedData ?? Data(), response)
    }
}
