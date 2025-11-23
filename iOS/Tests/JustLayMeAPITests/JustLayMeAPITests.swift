import XCTest
import Combine
@testable import JustLayMeAPI

final class JustLayMeAPITests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - Model Encoding/Decoding Tests

    func testChatRequestEncoding() throws {
        let request = ChatRequest(message: "Hello", characterId: "layme_v1", userId: "user-123")
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["message"] as? String, "Hello")
        XCTAssertEqual(json["character_id"] as? String, "layme_v1")
        XCTAssertEqual(json["user_id"] as? String, "user-123")
    }

    func testChatResponseDecoding() throws {
        let json = """
        {
            "response": "Hello! How can I help you?",
            "character": "Layme V1",
            "model": "zephyr:7b-alpha-q4_0",
            "customized": false,
            "sessionId": "session-123"
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)

        XCTAssertEqual(response.response, "Hello! How can I help you?")
        XCTAssertEqual(response.character, "Layme V1")
        XCTAssertEqual(response.model, "zephyr:7b-alpha-q4_0")
        XCTAssertEqual(response.customized, false)
        XCTAssertEqual(response.sessionId, "session-123")
    }

    func testUserDecoding() throws {
        let json = """
        {
            "id": "user-uuid-123",
            "email": "test@example.com",
            "name": "Test User",
            "subscription_status": "premium",
            "email_verified": true,
            "created_at": "2024-01-15T10:30:00.000Z"
        }
        """

        let data = json.data(using: .utf8)!
        let user = try JSONDecoder().decode(User.self, from: data)

        XCTAssertEqual(user.id, "user-uuid-123")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.name, "Test User")
        XCTAssertEqual(user.subscriptionStatus, "premium")
        XCTAssertEqual(user.emailVerified, true)
    }

    func testLoginResponseDecoding() throws {
        let json = """
        {
            "token": "jwt-token-here",
            "user": {
                "id": "user-uuid",
                "email": "test@example.com",
                "subscription_status": "free"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(LoginResponse.self, from: data)

        XCTAssertEqual(response.token, "jwt-token-here")
        XCTAssertEqual(response.user.id, "user-uuid")
        XCTAssertEqual(response.user.email, "test@example.com")
    }

    func testConversationDecoding() throws {
        let json = """
        {
            "id": "conv-uuid",
            "user_id": "user-uuid",
            "model_type": "layme_v1",
            "title": "Chat about AI",
            "message_count": 24,
            "is_archived": false,
            "created_at": "2024-01-20T10:00:00.000Z",
            "updated_at": "2024-01-20T15:30:00.000Z"
        }
        """

        let data = json.data(using: .utf8)!
        let conversation = try JSONDecoder().decode(Conversation.self, from: data)

        XCTAssertEqual(conversation.id, "conv-uuid")
        XCTAssertEqual(conversation.modelType, "layme_v1")
        XCTAssertEqual(conversation.title, "Chat about AI")
        XCTAssertEqual(conversation.messageCount, 24)
        XCTAssertEqual(conversation.isArchived, false)
    }

    func testModelsResponseDecoding() throws {
        let json = """
        {
            "models": [
                {
                    "name": "zephyr:7b-alpha-q4_0",
                    "size": 4370000000,
                    "modified": "2024-01-10T12:00:00.000Z"
                }
            ],
            "default_model": "zephyr:7b-alpha-q4_0",
            "total_models": 1
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ModelsResponse.self, from: data)

        XCTAssertEqual(response.models.count, 1)
        XCTAssertEqual(response.defaultModel, "zephyr:7b-alpha-q4_0")
        XCTAssertEqual(response.totalModels, 1)
    }

    // MARK: - Character Type Tests

    func testCharacterTypeDisplayNames() {
        XCTAssertEqual(CharacterType.laymeV1.displayName, "Layme V1")
        XCTAssertEqual(CharacterType.uncensoredGpt.displayName, "LayMe V1 Uncensored")
        XCTAssertEqual(CharacterType.roleplay.displayName, "Mythomax Roleplay")
        XCTAssertEqual(CharacterType.companion.displayName, "FastLayMe")
    }

    func testCharacterTypeFreeStatus() {
        XCTAssertTrue(CharacterType.laymeV1.isFree)
        XCTAssertFalse(CharacterType.uncensoredGpt.isFree)
        XCTAssertFalse(CharacterType.roleplay.isFree)
    }

    // MARK: - Payment Plan Tests

    func testPaymentPlanPrices() {
        XCTAssertEqual(PaymentPlan.monthly.price, 9.99)
        XCTAssertEqual(PaymentPlan.yearly.price, 79.99)
        XCTAssertEqual(PaymentPlan.lifetime.price, 199.00)
    }

    func testPaymentPlanCents() {
        XCTAssertEqual(PaymentPlan.monthly.priceInCents, 999)
        XCTAssertEqual(PaymentPlan.yearly.priceInCents, 7999)
        XCTAssertEqual(PaymentPlan.lifetime.priceInCents, 19900)
    }

    // MARK: - Mock Response Tests

    func testMockChatResponse() {
        let response = MockResponses.chatResponse
        XCTAssertFalse(response.response.isEmpty)
        XCTAssertEqual(response.character, "Layme V1")
    }

    func testMockModelsResponse() {
        let response = MockResponses.modelsResponse
        XCTAssertFalse(response.models.isEmpty)
        XCTAssertNotNil(response.defaultModel)
    }

    func testMockDataGenerator() {
        let uuid = MockDataGenerator.uuid()
        XCTAssertFalse(uuid.isEmpty)

        let sessionId = MockDataGenerator.sessionId()
        XCTAssertTrue(sessionId.hasPrefix("session-"))

        let timestamp = MockDataGenerator.timestamp()
        XCTAssertFalse(timestamp.isEmpty)
    }

    // MARK: - API Configuration Tests

    func testProductionConfiguration() {
        let config = APIConfiguration.production
        XCTAssertEqual(config.baseURL.absoluteString, "https://justlay.me")
        XCTAssertEqual(config.webSocketURL.absoluteString, "wss://justlay.me")
    }

    func testDevelopmentConfiguration() {
        let config = APIConfiguration.development
        XCTAssertEqual(config.baseURL.absoluteString, "http://localhost:3000")
        XCTAssertEqual(config.webSocketURL.absoluteString, "ws://localhost:3000")
    }

    // MARK: - API Error Tests

    func testAPIErrorDescriptions() {
        XCTAssertNotNil(APIError.invalidURL.errorDescription)
        XCTAssertNotNil(APIError.unauthorized.errorDescription)
        XCTAssertNotNil(APIError.notFound.errorDescription)
        XCTAssertNotNil(APIError.emailNotVerified(email: "test@example.com").errorDescription)
    }

    // MARK: - Character Customization Builder Tests

    func testCharacterCustomizationBuilder() {
        let customization = CharacterCustomizationBuilder()
            .name("My Character")
            .age(25)
            .background("A friendly AI")
            .personalityTraits("playful and energetic")
            .tone("casual")
            .build()

        XCTAssertEqual(customization.name, "My Character")
        XCTAssertEqual(customization.age, 25)
        XCTAssertEqual(customization.background, "A friendly AI")
        XCTAssertEqual(customization.personalityTraits, "playful and energetic")
        XCTAssertEqual(customization.tone, "casual")
    }

    // MARK: - Subscription Status Tests

    func testSubscriptionStatus() {
        XCTAssertFalse(SubscriptionStatus.free.isPremium)
        XCTAssertTrue(SubscriptionStatus.premium.isPremium)
    }
}
