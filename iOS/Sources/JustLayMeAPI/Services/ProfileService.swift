// MARK: - Profile Service
// Handles user profile management and data operations

import Foundation
import Combine

public final class ProfileService: ObservableObject {
    public static let shared = ProfileService()

    private let client: APIClient
    private var cancellables = Set<AnyCancellable>()

    @Published public private(set) var profile: ProfileResponse?
    @Published public private(set) var isLoading: Bool = false

    public init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Get Profile

    /// Get the current user's profile
    public func fetchProfile() -> AnyPublisher<ProfileResponse, APIError> {
        isLoading = true

        return client.request(.profile)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.profile = response
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func fetchProfile() async throws -> ProfileResponse {
        isLoading = true
        defer { isLoading = false }

        let response: ProfileResponse = try await client.request(.profile)
        profile = response
        return response
    }

    // MARK: - Update Profile

    /// Update the current user's profile
    public func updateProfile(
        name: String? = nil,
        avatarStyle: String? = nil,
        themePreference: String? = nil
    ) -> AnyPublisher<UpdateProfileResponse, APIError> {
        isLoading = true

        let request = UpdateProfileRequest(
            name: name,
            avatarStyle: avatarStyle,
            themePreference: themePreference
        )

        return client.request(.updateProfile, body: request)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    if let user = response.user {
                        self?.profile = ProfileResponse(
                            id: user.id,
                            email: user.email,
                            name: user.name,
                            createdAt: user.createdAt,
                            subscriptionStatus: user.subscriptionStatus,
                            subscriptionEnd: user.subscriptionEnd
                        )
                    }
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func updateProfile(
        name: String? = nil,
        avatarStyle: String? = nil,
        themePreference: String? = nil
    ) async throws -> UpdateProfileResponse {
        isLoading = true
        defer { isLoading = false }

        let request = UpdateProfileRequest(
            name: name,
            avatarStyle: avatarStyle,
            themePreference: themePreference
        )

        let response: UpdateProfileResponse = try await client.request(.updateProfile, body: request)

        if let user = response.user {
            profile = ProfileResponse(
                id: user.id,
                email: user.email,
                name: user.name,
                createdAt: user.createdAt,
                subscriptionStatus: user.subscriptionStatus,
                subscriptionEnd: user.subscriptionEnd
            )
        }

        return response
    }

    // MARK: - Export Data

    /// Export all user data
    public func exportData() -> AnyPublisher<ExportDataResponse, APIError> {
        isLoading = true

        return client.request(.exportData)
            .handleEvents(
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func exportData() async throws -> ExportDataResponse {
        isLoading = true
        defer { isLoading = false }

        return try await client.request(.exportData)
    }

    /// Export data as raw JSON data for saving to file
    public func exportDataAsFile() -> AnyPublisher<Data, APIError> {
        isLoading = true

        return client.requestData(.exportData)
            .handleEvents(
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    // MARK: - Clear Data

    /// Clear all user data (conversations and characters)
    public func clearAllData() -> AnyPublisher<SuccessResponse, APIError> {
        isLoading = true

        return client.request(.clearData)
            .handleEvents(
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func clearAllData() async throws -> SuccessResponse {
        isLoading = true
        defer { isLoading = false }

        return try await client.request(.clearData)
    }

    // MARK: - Helper Properties

    /// Check if user has premium subscription
    public var isPremium: Bool {
        profile?.subscriptionStatus == "premium"
    }

    /// Get subscription end date
    public var subscriptionEndDate: Date? {
        guard let endString = profile?.subscriptionEnd else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: endString)
    }

    /// Check if subscription is active
    public var isSubscriptionActive: Bool {
        guard isPremium else { return false }
        guard let endDate = subscriptionEndDate else { return true }
        return endDate > Date()
    }

    /// Days remaining in subscription
    public var subscriptionDaysRemaining: Int? {
        guard let endDate = subscriptionEndDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return components.day
    }
}
