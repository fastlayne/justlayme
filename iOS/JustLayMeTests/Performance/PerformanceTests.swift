import XCTest
@testable import JustLayMe

final class PerformanceTests: XCTestCase {

    var mockAPIClient: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
    }

    override func tearDown() {
        mockAPIClient = nil
        super.tearDown()
    }

    // MARK: - API Response Time Tests

    func testChatResponsePerformance() async throws {
        // Given
        let chatResponse = MockDataFactory.createChatResponse()
        mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)

        // When/Then
        let metrics = try await measureAsync(iterations: 100) {
            let _: ChatResponse = try await self.mockAPIClient.request(
                .chat(message: "Hello", characterId: "layme_v1", userId: nil, sessionId: nil)
            )
        }

        print(metrics.description)
        XCTAssertLessThan(metrics.averageTime, 0.01) // Should be very fast with mocks
    }

    func testAuthResponsePerformance() async throws {
        // Given
        let authResponse = MockDataFactory.createAuthResponse()
        mockAPIClient.stub(endpoint: "/api/login", with: authResponse)

        // When/Then
        let metrics = try await measureAsync(iterations: 100) {
            let _: AuthResponse = try await self.mockAPIClient.request(
                .login(email: "test@example.com", password: "password")
            )
        }

        print(metrics.description)
        XCTAssertLessThan(metrics.averageTime, 0.01)
    }

    // MARK: - Model Creation Performance

    func testUserModelCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = MockDataFactory.createUser()
            }
        }
    }

    func testCharacterModelCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = MockDataFactory.createCharacter()
            }
        }
    }

    func testChatMessageCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = MockDataFactory.createChatMessage()
            }
        }
    }

    // MARK: - JSON Encoding/Decoding Performance

    func testUserEncodingPerformance() throws {
        let user = MockDataFactory.createUser()
        let encoder = JSONEncoder()

        measure {
            for _ in 0..<1000 {
                _ = try? encoder.encode(user)
            }
        }
    }

    func testUserDecodingPerformance() throws {
        let user = MockDataFactory.createUser()
        let data = try JSONEncoder().encode(user)
        let decoder = JSONDecoder()

        measure {
            for _ in 0..<1000 {
                _ = try? decoder.decode(User.self, from: data)
            }
        }
    }

    func testChatResponseDecodingPerformance() throws {
        let response = MockDataFactory.createChatResponse()
        let data = try JSONEncoder().encode(response)
        let decoder = JSONDecoder()

        measure {
            for _ in 0..<1000 {
                _ = try? decoder.decode(ChatResponse.self, from: data)
            }
        }
    }

    // MARK: - Large Data Set Performance

    func testLargeConversationListPerformance() {
        let conversations = MockDataFactory.createConversations(count: 100)

        measure {
            // Simulate filtering and sorting
            let filtered = conversations.filter { !$0.isArchived }
            let sorted = filtered.sorted { $0.updatedAt > $1.updatedAt }
            _ = sorted.prefix(20)
        }
    }

    func testLargeMessageListPerformance() {
        let messages = MockDataFactory.createConversation(count: 500)

        measure {
            // Simulate grouping messages by date
            let grouped = Dictionary(grouping: messages) { message in
                Calendar.current.startOfDay(for: message.createdAt)
            }
            _ = grouped.keys.sorted()
        }
    }

    // MARK: - ViewModel State Update Performance

    @MainActor
    func testChatViewModelMessageAppendPerformance() async {
        let mockUserRepo = MockUserRepository()
        let chatViewModel = ChatViewModel(apiClient: mockAPIClient, userRepository: mockUserRepo)

        let chatResponse = MockDataFactory.createChatResponse()
        mockAPIClient.stub(endpoint: "/api/chat", with: chatResponse)

        measure {
            for i in 0..<100 {
                chatViewModel.inputMessage = "Message \(i)"
                Task {
                    await chatViewModel.sendMessage()
                }
            }
        }
    }

    // MARK: - Settings Persistence Performance

    @MainActor
    func testSettingsPersistencePerformance() {
        let userDefaults = UserDefaults(suiteName: "PerformanceTest")!

        measure {
            for _ in 0..<100 {
                let settingsViewModel = SettingsViewModel(userDefaults: userDefaults)
                settingsViewModel.isDarkMode = true
                settingsViewModel.enableNotifications = false
                settingsViewModel.defaultCharacterType = .roleplay
            }
        }

        userDefaults.removePersistentDomain(forName: "PerformanceTest")
    }

    // MARK: - Memory Performance

    func testNoMemoryLeakInChatViewModel() async {
        weak var weakViewModel: ChatViewModel?

        await MainActor.run {
            let viewModel = ChatViewModel(apiClient: mockAPIClient, userRepository: nil)
            weakViewModel = viewModel

            // Simulate usage
            viewModel.inputMessage = "Test"
            viewModel.selectCharacter(.roleplay)
            viewModel.clearChat()
        }

        // Force cleanup
        await Task.yield()

        // ViewModel should be deallocated
        XCTAssertNil(weakViewModel)
    }

    func testNoMemoryLeakInAuthViewModel() async {
        weak var weakViewModel: AuthViewModel?

        await MainActor.run {
            let mockKeychain = MockKeychainService()
            let viewModel = AuthViewModel(apiClient: mockAPIClient, keychain: mockKeychain)
            weakViewModel = viewModel

            // Simulate usage
            viewModel.email = "test@example.com"
            viewModel.password = "password"
            viewModel.clearError()
        }

        await Task.yield()

        XCTAssertNil(weakViewModel)
    }

    // MARK: - Startup Performance

    @MainActor
    func testAppInitializationPerformance() {
        measure {
            // Simulate app initialization
            let _ = UserRepository(apiClient: mockAPIClient, keychain: MockKeychainService())
            let _ = ChatRepository(apiClient: mockAPIClient)
            let _ = CharacterRepository(apiClient: mockAPIClient)
            let _ = SettingsViewModel()
        }
    }
}

// MARK: - Async Measurement Extension

extension PerformanceTests {
    func measureAsync(
        iterations: Int = 10,
        operation: @escaping () async throws -> Void
    ) async throws -> PerformanceMetrics {
        var times: [TimeInterval] = []

        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            try await operation()
            let end = CFAbsoluteTimeGetCurrent()
            times.append(end - start)
        }

        return PerformanceMetrics(
            averageTime: times.reduce(0, +) / Double(times.count),
            minTime: times.min() ?? 0,
            maxTime: times.max() ?? 0,
            iterations: iterations
        )
    }
}
