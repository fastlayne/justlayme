// MARK: - JustLayMeAPI
// iOS API Client for JustLay.me
// Production-ready networking layer with URLSession + Combine

/**
 # JustLayMeAPI

 A complete iOS API client for the JustLay.me AI chat platform.

 ## Features
 - Full API coverage for all endpoints
 - URLSession + Combine based networking
 - WebSocket support for real-time updates
 - Async/await support (iOS 15+)
 - Type-safe Codable models
 - Mock responses for testing

 ## Quick Start

 ```swift
 import JustLayMeAPI

 // Configure for production
 APIClient.shared.configure(with: .production)

 // Login
 let response = try await AuthService.shared.login(
     email: "user@example.com",
     password: "password"
 )

 // Send a chat message
 let chat = try await ChatService.shared.sendMessage(
     "Hello, how are you?",
     characterId: .laymeV1
 )
 print(chat.response)
 ```

 ## Available Services

 - `AuthService` - Authentication (login, register, Google OAuth)
 - `ChatService` - AI chat messaging
 - `CharacterService` - Character management and customization
 - `ModelService` - AI model discovery and recommendations
 - `ConversationService` - Chat history and conversation management
 - `ProfileService` - User profile management
 - `PaymentService` - Stripe payment integration
 - `WebSocketManager` - Real-time WebSocket connections

 ## Configuration

 ```swift
 // Use production configuration
 APIClient.shared.configure(with: .production)

 // Use development configuration
 APIClient.shared.configure(with: .development)

 // Custom configuration
 let config = APIConfiguration(
     baseURL: URL(string: "https://your-server.com")!,
     webSocketURL: URL(string: "wss://your-server.com")!
 )
 APIClient.shared.configure(with: config)
 ```

 ## WebSocket Usage

 ```swift
 // Connect to WebSocket
 WebSocketManager.shared.connect()

 // Listen for events
 WebSocketManager.shared.events
     .sink { event in
         switch event {
         case .newMessage(let sessionId, let message, let isUser, let timestamp):
             print("New message in \(sessionId): \(message)")
         default:
             break
         }
     }
     .store(in: &cancellables)
 ```
 */

import Foundation
import Combine

// MARK: - Public Exports

// Re-export all public types for convenience
public typealias JLAPIClient = APIClient
public typealias JLAPIConfiguration = APIConfiguration
public typealias JLAPIError = APIError

// MARK: - Version Info

public struct JustLayMeAPIInfo {
    public static let version = "1.0.0"
    public static let name = "JustLayMeAPI"
    public static let minimumServerVersion = "1.0.0"

    /// Base URL for production
    public static let productionBaseURL = URL(string: "https://justlay.me")!

    /// Base URL for development
    public static let developmentBaseURL = URL(string: "http://localhost:3000")!
}

// MARK: - Convenience Initializers

extension APIClient {
    /// Create a pre-configured client for production use
    public static var production: APIClient {
        let client = APIClient(configuration: .production)
        return client
    }

    /// Create a pre-configured client for development use
    public static var development: APIClient {
        let client = APIClient(configuration: .development)
        return client
    }
}

// MARK: - Service Factory

/// Factory for creating service instances with custom configuration
public struct ServiceFactory {
    private let client: APIClient

    public init(client: APIClient = .shared) {
        self.client = client
    }

    public func makeAuthService() -> AuthService {
        AuthService(client: client)
    }

    public func makeChatService() -> ChatService {
        ChatService(client: client)
    }

    public func makeCharacterService() -> CharacterService {
        CharacterService(client: client)
    }

    public func makeModelService() -> ModelService {
        ModelService(client: client)
    }

    public func makeConversationService() -> ConversationService {
        ConversationService(client: client)
    }

    public func makeProfileService() -> ProfileService {
        ProfileService(client: client)
    }

    public func makePaymentService() -> PaymentService {
        PaymentService(client: client)
    }
}

// MARK: - SwiftUI Integration Helpers

#if canImport(SwiftUI)
import SwiftUI

/// Environment key for API client
public struct APIClientKey: EnvironmentKey {
    public static let defaultValue: APIClient = .shared
}

/// Environment key for Auth service
public struct AuthServiceKey: EnvironmentKey {
    public static let defaultValue: AuthService = .shared
}

/// Environment key for Chat service
public struct ChatServiceKey: EnvironmentKey {
    public static let defaultValue: ChatService = .shared
}

extension EnvironmentValues {
    public var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }

    public var authService: AuthService {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }

    public var chatService: ChatService {
        get { self[ChatServiceKey.self] }
        set { self[ChatServiceKey.self] = newValue }
    }
}
#endif
