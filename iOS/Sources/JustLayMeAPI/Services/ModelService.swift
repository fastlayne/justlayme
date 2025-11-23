// MARK: - Model Service
// Handles AI model discovery, testing, and recommendations

import Foundation
import Combine

public final class ModelService: ObservableObject {
    public static let shared = ModelService()

    private let client: APIClient
    private var cancellables = Set<AnyCancellable>()

    @Published public private(set) var models: [AIModel] = []
    @Published public private(set) var defaultModel: String?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var healthStatus: [String: TestModelResponse] = [:]

    public init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Fetch Models

    /// Get all available AI models
    public func fetchModels() -> AnyPublisher<ModelsResponse, APIError> {
        isLoading = true

        return client.request(.models)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.models = response.models
                    self?.defaultModel = response.defaultModel
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func fetchModels() async throws -> ModelsResponse {
        isLoading = true
        defer { isLoading = false }

        let response: ModelsResponse = try await client.request(.models)
        models = response.models
        defaultModel = response.defaultModel
        return response
    }

    // MARK: - Test Model

    /// Test a specific model with a prompt
    public func testModel(
        _ modelName: String,
        prompt: String = "Hello, how are you?"
    ) -> AnyPublisher<TestModelResponse, APIError> {
        let request = TestModelRequest(model: modelName, prompt: prompt)
        return client.request(.testModel, body: request)
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func testModel(
        _ modelName: String,
        prompt: String = "Hello, how are you?"
    ) async throws -> TestModelResponse {
        let request = TestModelRequest(model: modelName, prompt: prompt)
        return try await client.request(.testModel, body: request)
    }

    // MARK: - Health Check

    /// Check health status of all models
    public func checkHealth() -> AnyPublisher<[String: TestModelResponse], APIError> {
        isLoading = true

        return client.request(.modelsHealth)
            .handleEvents(
                receiveOutput: { [weak self] status in
                    self?.healthStatus = status
                },
                receiveCompletion: { [weak self] _ in
                    self?.isLoading = false
                }
            )
            .eraseToAnyPublisher()
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func checkHealth() async throws -> [String: TestModelResponse] {
        isLoading = true
        defer { isLoading = false }

        let status: [String: TestModelResponse] = try await client.request(.modelsHealth)
        healthStatus = status
        return status
    }

    // MARK: - Model Recommendations

    /// Get model recommendations for a character
    public func getRecommendations(
        for characterId: String,
        userId: String? = nil
    ) -> AnyPublisher<ModelRecommendationResponse, APIError> {
        var queryItems: [URLQueryItem] = []
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: userId))
        }

        return client.request(
            .modelRecommendations(characterId),
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    @available(iOS 15.0, macOS 12.0, *)
    public func getRecommendations(
        for characterId: String,
        userId: String? = nil
    ) async throws -> ModelRecommendationResponse {
        var queryItems: [URLQueryItem] = []
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: userId))
        }

        return try await client.request(
            .modelRecommendations(characterId),
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    // MARK: - Helper Methods

    /// Get model by name
    public func model(named name: String) -> AIModel? {
        models.first { $0.name == name }
    }

    /// Get models optimized for speed
    public var fastModels: [AIModel] {
        models.filter { $0.capabilities?.speed == "fast" }
    }

    /// Get models optimized for quality
    public var qualityModels: [AIModel] {
        models.filter {
            $0.capabilities?.strengths?.contains("reasoning") == true ||
            $0.capabilities?.strengths?.contains("detailed_responses") == true
        }
    }

    /// Get models best for roleplay
    public var roleplayModels: [AIModel] {
        models.filter {
            $0.capabilities?.bestFor?.contains("creative") == true ||
            $0.capabilities?.bestFor?.contains("adventurous") == true ||
            $0.capabilities?.strengths?.contains("roleplay") == true
        }
    }

    /// Get uncensored models
    public var uncensoredModels: [AIModel] {
        models.filter {
            $0.capabilities?.strengths?.contains("uncensored") == true
        }
    }
}
