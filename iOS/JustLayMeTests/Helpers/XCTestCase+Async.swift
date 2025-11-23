import XCTest
@testable import JustLayMe

// MARK: - XCTestCase Async Extensions

extension XCTestCase {

    /// Waits for an async operation to complete within a timeout
    func waitForAsync(
        timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw AsyncTestError.timeout
            }

            // Wait for first to complete
            _ = try await group.next()
            group.cancelAll()
        }
    }

    /// Executes an async test with MainActor context
    @MainActor
    func executeOnMainActor<T>(
        _ operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        try await operation()
    }

    /// Asserts that an async operation throws a specific error
    func assertAsyncThrows<T, E: Error & Equatable>(
        _ expression: @autoclosure () async throws -> T,
        _ expectedError: E,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error \(expectedError) but no error was thrown", file: file, line: line)
        } catch let error as E {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Expected error \(expectedError) but got \(error)", file: file, line: line)
        }
    }

    /// Asserts that an async operation does not throw
    func assertAsyncNoThrow<T>(
        _ expression: @autoclosure () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async -> T? {
        do {
            return try await expression()
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
            return nil
        }
    }
}

enum AsyncTestError: Error {
    case timeout
}

// MARK: - Publisher Testing

import Combine

extension XCTestCase {

    /// Collects values from a publisher for a specified duration
    func collectValues<P: Publisher>(
        from publisher: P,
        count: Int = 1,
        timeout: TimeInterval = 2.0
    ) async -> [P.Output] where P.Failure == Never {
        var values: [P.Output] = []
        var cancellable: AnyCancellable?

        let expectation = XCTestExpectation(description: "Collect values")

        cancellable = publisher
            .prefix(count)
            .sink { _ in
                expectation.fulfill()
            } receiveValue: { value in
                values.append(value)
            }

        await fulfillment(of: [expectation], timeout: timeout)
        cancellable?.cancel()

        return values
    }
}

// MARK: - State Assertion Helpers

extension XCTestCase {

    /// Waits for a condition to become true
    func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 5.0,
        pollInterval: TimeInterval = 0.1,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        let startTime = Date()

        while !condition() {
            if Date().timeIntervalSince(startTime) > timeout {
                XCTFail("Condition not met within \(timeout) seconds", file: file, line: line)
                return
            }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }

    /// Asserts a value eventually becomes expected
    func assertEventually<T: Equatable>(
        _ getValue: @escaping () -> T,
        equals expected: T,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        await waitUntil({ getValue() == expected }, timeout: timeout, file: file, line: line)
    }
}

// MARK: - Mock Delay Helper

extension Task where Success == Never, Failure == Never {
    static func delay(seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
