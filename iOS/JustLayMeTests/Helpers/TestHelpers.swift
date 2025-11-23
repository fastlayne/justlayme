import XCTest
import Combine
@testable import JustLayMe

// MARK: - Test Environment

class TestEnvironment {
    let mockAPIClient: MockAPIClient
    let mockKeychain: MockKeychainService
    let mockUserRepository: MockUserRepository
    let mockChatRepository: MockChatRepository
    let mockCharacterRepository: MockCharacterRepository

    init() {
        mockAPIClient = MockAPIClient()
        mockKeychain = MockKeychainService()
        mockUserRepository = MockUserRepository()
        mockChatRepository = MockChatRepository()
        mockCharacterRepository = MockCharacterRepository()
    }

    func reset() {
        mockAPIClient.reset()
        mockKeychain.reset()
        mockUserRepository.reset()
        mockChatRepository.reset()
        mockCharacterRepository.reset()
    }
}

// MARK: - ViewModel Test Case Base

class ViewModelTestCase: XCTestCase {
    var env: TestEnvironment!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        env = TestEnvironment()
        cancellables = []
    }

    override func tearDown() {
        env.reset()
        cancellables.removeAll()
        super.tearDown()
    }
}

// MARK: - State Change Recorder

class StateChangeRecorder<State> {
    private(set) var states: [State] = []
    private var cancellable: AnyCancellable?

    init<P: Publisher>(publisher: P) where P.Output == State, P.Failure == Never {
        cancellable = publisher.sink { [weak self] state in
            self?.states.append(state)
        }
    }

    var firstState: State? { states.first }
    var lastState: State? { states.last }
    var stateCount: Int { states.count }

    func cancel() {
        cancellable?.cancel()
    }
}

// MARK: - JSON Helpers

extension Data {
    static func jsonData(from dictionary: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: dictionary)
    }
}

extension Encodable {
    func toJSONData() throws -> Data {
        try JSONEncoder().encode(self)
    }

    func toJSONString() throws -> String {
        let data = try toJSONData()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Date Helpers

extension Date {
    static func from(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    static var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }

    static var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    static var nextMonth: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    }

    static var nextYear: Date {
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    }
}

// MARK: - Assertions

func assertContains<T: Equatable>(_ collection: [T], _ element: T, file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(collection.contains(element), "Expected collection to contain \(element)", file: file, line: line)
}

func assertNotContains<T: Equatable>(_ collection: [T], _ element: T, file: StaticString = #file, line: UInt = #line) {
    XCTAssertFalse(collection.contains(element), "Expected collection to not contain \(element)", file: file, line: line)
}

func assertEmpty<T>(_ collection: [T], file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(collection.isEmpty, "Expected collection to be empty but had \(collection.count) elements", file: file, line: line)
}

func assertNotEmpty<T>(_ collection: [T], file: StaticString = #file, line: UInt = #line) {
    XCTAssertFalse(collection.isEmpty, "Expected collection to not be empty", file: file, line: line)
}

// MARK: - Subscription Status Assertions

extension XCTestCase {
    func assertFreeUser(_ user: User, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(user.subscriptionStatus, .free, file: file, line: line)
        XCTAssertFalse(user.subscriptionStatus.isPremium, file: file, line: line)
    }

    func assertPremiumUser(_ user: User, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(user.subscriptionStatus.isPremium, file: file, line: line)
    }
}

// MARK: - Auth State Assertions

extension XCTestCase {
    @MainActor
    func assertAuthenticated(_ viewModel: AuthViewModel, file: StaticString = #file, line: UInt = #line) {
        if case .authenticated = viewModel.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected authenticated state but got \(viewModel.state)", file: file, line: line)
        }
    }

    @MainActor
    func assertAuthError(_ viewModel: AuthViewModel, _ expectedError: AuthError, file: StaticString = #file, line: UInt = #line) {
        if case .error(let error) = viewModel.state {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } else {
            XCTFail("Expected error state but got \(viewModel.state)", file: file, line: line)
        }
    }
}

// MARK: - Performance Metrics

struct PerformanceMetrics {
    let averageTime: TimeInterval
    let minTime: TimeInterval
    let maxTime: TimeInterval
    let iterations: Int

    var description: String {
        """
        Performance Metrics (\(iterations) iterations):
        - Average: \(String(format: "%.4f", averageTime))s
        - Min: \(String(format: "%.4f", minTime))s
        - Max: \(String(format: "%.4f", maxTime))s
        """
    }
}

extension XCTestCase {
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
