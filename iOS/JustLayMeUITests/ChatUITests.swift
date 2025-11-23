import XCTest

final class ChatUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-auth"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Chat Screen Tests

    func testChatScreenElementsExist() {
        // Given
        navigateToChat()

        // Then
        XCTAssertTrue(app.textViews["messageInputField"].exists)
        XCTAssertTrue(app.buttons["sendButton"].exists)
        XCTAssertTrue(app.scrollViews["messagesScrollView"].exists)
    }

    func testSendMessage() {
        // Given
        navigateToChat()

        // When
        let inputField = app.textViews["messageInputField"]
        inputField.tap()
        inputField.typeText("Hello, how are you?")

        app.buttons["sendButton"].tap()

        // Then
        waitForElement(app.staticTexts["Hello, how are you?"], timeout: 2)
        // Wait for AI response
        waitForElement(app.otherElements["aiMessage"], timeout: 10)
    }

    func testSendButtonDisabledWhenEmpty() {
        // Given
        navigateToChat()

        // Then
        XCTAssertFalse(app.buttons["sendButton"].isEnabled)

        // When
        let inputField = app.textViews["messageInputField"]
        inputField.tap()
        inputField.typeText("Hello")

        // Then
        XCTAssertTrue(app.buttons["sendButton"].isEnabled)
    }

    func testCharacterSelection() {
        // Given
        navigateToChat()

        // When
        app.buttons["characterSelector"].tap()

        // Then
        waitForElement(app.staticTexts["Layme V1"], timeout: 2)
        XCTAssertTrue(app.staticTexts["LayMe Uncensored"].exists)
        XCTAssertTrue(app.staticTexts["Mythomax Roleplay"].exists)
        XCTAssertTrue(app.staticTexts["FastLayMe"].exists)
    }

    func testSwitchCharacter() {
        // Given
        navigateToChat()
        app.buttons["characterSelector"].tap()

        // When
        app.staticTexts["Mythomax Roleplay"].tap()

        // Then
        waitForElement(app.staticTexts["Mythomax Roleplay"], timeout: 2)
    }

    func testClearChatButton() {
        // Given
        navigateToChat()

        // Send a message first
        let inputField = app.textViews["messageInputField"]
        inputField.tap()
        inputField.typeText("Test message")
        app.buttons["sendButton"].tap()

        waitForElement(app.staticTexts["Test message"], timeout: 2)

        // When
        app.buttons["clearChatButton"].tap()
        app.buttons["confirmClearChat"].tap()

        // Then
        XCTAssertFalse(app.staticTexts["Test message"].exists)
    }

    func testMessageLimitWarning() {
        // Given
        app.launchArguments = ["--uitesting", "--skip-auth", "--free-user"]
        app.launch()
        navigateToChat()

        // Select premium model
        app.buttons["characterSelector"].tap()
        app.staticTexts["LayMe Uncensored"].tap()

        // When - send 3 messages
        for i in 1...3 {
            let inputField = app.textViews["messageInputField"]
            inputField.tap()
            inputField.typeText("Message \(i)")
            app.buttons["sendButton"].tap()
            sleep(2) // Wait for response
        }

        // Then - should show upgrade prompt
        waitForElement(app.staticTexts["upgradePrompt"], timeout: 5)
    }

    // MARK: - Keyboard Tests

    func testKeyboardDismissOnScroll() {
        // Given
        navigateToChat()

        let inputField = app.textViews["messageInputField"]
        inputField.tap()

        // Verify keyboard is shown
        XCTAssertTrue(app.keyboards.element.exists)

        // When
        app.scrollViews["messagesScrollView"].swipeDown()

        // Then
        XCTAssertFalse(app.keyboards.element.exists)
    }

    // MARK: - Helper Methods

    private func navigateToChat() {
        if app.tabBars["mainTabBar"].exists {
            app.tabBars["mainTabBar"].buttons["Chat"].tap()
        }
    }

    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval) {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element \(element) did not appear within \(timeout) seconds")
    }
}
