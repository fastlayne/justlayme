import XCTest
@testable import JustLayMe

final class JustLayMeTests: XCTestCase {

    // MARK: - Model Tests

    func testUserDecoding() throws {
        let json = """
        {
            "id": "user-123",
            "email": "test@example.com",
            "name": "Test User",
            "subscription_status": "free",
            "message_count": 5,
            "email_verified": true
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let user = try decoder.decode(User.self, from: data)

        XCTAssertEqual(user.id, "user-123")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.name, "Test User")
        XCTAssertEqual(user.subscriptionStatus, .free)
        XCTAssertEqual(user.messageCount, 5)
        XCTAssertTrue(user.emailVerified)
        XCTAssertFalse(user.isPremium)
    }

    func testPremiumUser() throws {
        let json = """
        {
            "id": "user-456",
            "email": "premium@example.com",
            "subscription_status": "premium",
            "message_count": 100,
            "email_verified": true
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let user = try decoder.decode(User.self, from: data)

        XCTAssertTrue(user.isPremium)
        XCTAssertTrue(user.canAccessPremiumModels)
    }

    func testCharacterDecoding() throws {
        let json = """
        {
            "id": "char-123",
            "user_id": "user-123",
            "name": "Test Character",
            "backstory": "A mysterious character",
            "personality_traits": ["friendly", "curious"],
            "is_public": false
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let character = try decoder.decode(AICharacter.self, from: data)

        XCTAssertEqual(character.id, "char-123")
        XCTAssertEqual(character.name, "Test Character")
        XCTAssertEqual(character.personalityTraits?.count, 2)
        XCTAssertFalse(character.isPublic)
    }

    func testMessageDecoding() throws {
        let json = """
        {
            "id": "msg-123",
            "conversation_id": "conv-123",
            "sender_type": "human",
            "content": "Hello, AI!"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let message = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(message.id, "msg-123")
        XCTAssertEqual(message.senderType, .human)
        XCTAssertTrue(message.isUser)
        XCTAssertFalse(message.isAI)
    }

    // MARK: - Predefined Character Tests

    func testPredefinedCharacters() {
        XCTAssertEqual(PredefinedCharacter.allCases.count, 4)

        XCTAssertTrue(PredefinedCharacter.laymeV1.isFree)
        XCTAssertFalse(PredefinedCharacter.laymeV1.isPremium)

        XCTAssertFalse(PredefinedCharacter.uncensoredGpt.isFree)
        XCTAssertTrue(PredefinedCharacter.uncensoredGpt.isPremium)

        XCTAssertTrue(PredefinedCharacter.roleplay.isPremium)
        XCTAssertTrue(PredefinedCharacter.companion.isPremium)
    }

    // MARK: - Subscription Plan Tests

    func testSubscriptionPlans() {
        XCTAssertEqual(SubscriptionPlan.monthly.price, 9.99)
        XCTAssertEqual(SubscriptionPlan.yearly.price, 79.99)
        XCTAssertEqual(SubscriptionPlan.lifetime.price, 199.00)

        XCTAssertNil(SubscriptionPlan.monthly.savings)
        XCTAssertEqual(SubscriptionPlan.yearly.savings, "Save 33%")
        XCTAssertEqual(SubscriptionPlan.lifetime.savings, "Best Value")
    }

    // MARK: - Premium Access Tests

    func testPremiumAccessCheck() {
        // Free model - always allowed
        let freeResult = PaymentViewModel.checkPremiumAccess(
            for: .laymeV1,
            user: nil,
            messageCount: 100
        )
        XCTAssertEqual(freeResult, .allowed)

        // Premium user - always allowed
        let premiumUser = User(
            id: "1",
            email: "test@test.com",
            subscriptionStatus: .premium,
            messageCount: 0,
            emailVerified: true
        )
        let premiumResult = PaymentViewModel.checkPremiumAccess(
            for: .uncensoredGpt,
            user: premiumUser,
            messageCount: 0
        )
        XCTAssertEqual(premiumResult, .allowed)

        // Free user with remaining messages
        let limitedResult = PaymentViewModel.checkPremiumAccess(
            for: .uncensoredGpt,
            user: nil,
            messageCount: 1
        )
        if case .allowedWithLimit(let remaining) = limitedResult {
            XCTAssertEqual(remaining, 2) // 3 - 1 = 2
        } else {
            XCTFail("Expected allowedWithLimit")
        }

        // Free user over limit
        let blockedResult = PaymentViewModel.checkPremiumAccess(
            for: .uncensoredGpt,
            user: nil,
            messageCount: 5
        )
        XCTAssertEqual(blockedResult, .premiumRequired)
    }

    // MARK: - String Extension Tests

    func testEmailValidation() {
        XCTAssertTrue("test@example.com".isValidEmail)
        XCTAssertTrue("user.name+tag@domain.co.uk".isValidEmail)
        XCTAssertFalse("invalid-email".isValidEmail)
        XCTAssertFalse("@nodomain.com".isValidEmail)
        XCTAssertFalse("noat.domain.com".isValidEmail)
    }

    func testStringTrimming() {
        XCTAssertEqual("  hello  ".trimmed, "hello")
        XCTAssertEqual("\n\ttest\n".trimmed, "test")
        XCTAssertEqual("no-trim".trimmed, "no-trim")
    }

    // MARK: - Settings Tests

    func testThemePreference() {
        XCTAssertNil(ThemePreference.system.colorScheme)
        XCTAssertEqual(ThemePreference.light.colorScheme, .light)
        XCTAssertEqual(ThemePreference.dark.colorScheme, .dark)
    }

    func testResponseLength() {
        XCTAssertEqual(ResponseLength.short.displayName, "Short")
        XCTAssertEqual(ResponseLength.medium.displayName, "Medium")
        XCTAssertEqual(ResponseLength.long.displayName, "Long")
    }
}

// MARK: - Equatable Conformance for Tests
extension PremiumAccessResult: Equatable {
    public static func == (lhs: PremiumAccessResult, rhs: PremiumAccessResult) -> Bool {
        switch (lhs, rhs) {
        case (.allowed, .allowed):
            return true
        case (.premiumRequired, .premiumRequired):
            return true
        case (.allowedWithLimit(let l), .allowedWithLimit(let r)):
            return l == r
        default:
            return false
        }
    }
}
