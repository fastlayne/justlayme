# JustLayMeAPI - iOS API Client

A production-ready iOS API client for the JustLay.me AI chat platform. Built with URLSession + Combine for modern Swift development.

## Features

- **Complete API Coverage** - All server endpoints implemented
- **URLSession + Combine** - Modern reactive networking
- **Async/Await Support** - iOS 15+ async APIs
- **WebSocket Manager** - Real-time chat updates
- **Type-Safe Models** - Full Codable support
- **Service Layer** - Clean architecture with dedicated services
- **Mock Responses** - Pre-built mocks for testing
- **SwiftUI Integration** - Environment values and ObservableObjects

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../iOS")  // Local path
    // Or from git: .package(url: "https://github.com/fastlayne/justlayme.git", branch: "main")
]
```

Or in Xcode: File > Add Packages > Add Local Package

## Quick Start

### Configuration

```swift
import JustLayMeAPI

// Use production (https://justlay.me)
APIClient.shared.configure(with: .production)

// Or development (http://localhost:3000)
APIClient.shared.configure(with: .development)
```

### Authentication

```swift
// Register
let result = try await AuthService.shared.register(
    email: "user@example.com",
    password: "password123"
)
// User needs to verify email before logging in

// Login
let response = try await AuthService.shared.login(
    email: "user@example.com",
    password: "password123"
)
print("Token: \(response.token)")
print("User: \(response.user.email)")

// Google OAuth
let googleResponse = try await AuthService.shared.loginWithGoogle(
    credential: googleIdToken
)
```

### Chat

```swift
// Send a message (works without auth)
let chat = try await ChatService.shared.sendMessage(
    "Hello, how are you?",
    characterId: .laymeV1
)
print(chat.response)      // AI response
print(chat.character)     // "Layme V1"
print(chat.model)         // "zephyr:7b-alpha-q4_0"

// Use different character types
let uncensored = try await ChatService.shared.sendMessage(
    "Tell me anything",
    characterId: .uncensoredGpt
)

let roleplay = try await ChatService.shared.sendMessage(
    "Let's start an adventure",
    characterId: .roleplay
)
```

### Using Combine

```swift
ChatService.shared.sendMessage("Hello")
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Error: \(error)")
            }
        },
        receiveValue: { response in
            print("AI: \(response.response)")
        }
    )
    .store(in: &cancellables)
```

### Available AI Models

```swift
// Fetch available models
let models = try await ModelService.shared.fetchModels()
print("Available: \(models.models.map { $0.name })")
print("Default: \(models.defaultModel)")

// Get recommendations for a character
let recommendation = try await ModelService.shared.getRecommendations(
    for: CharacterType.roleplay.rawValue
)
print("Recommended: \(recommendation.recommendedModel)")
```

### Conversation History

```swift
// Get conversations (requires auth)
let conversations = try await ConversationService.shared.fetchConversations()

// Get messages
let messages = try await ConversationService.shared.fetchMessages(
    conversationId: "conv-uuid"
)

// Search conversations
let results = try await ConversationService.shared.search(query: "neural networks")

// Export conversation (premium only)
let data = try await ConversationService.shared.exportConversation(
    "conv-uuid",
    format: .json
)
```

### WebSocket for Real-time Updates

```swift
// Connect
WebSocketManager.shared.connect()

// Listen for events
WebSocketManager.shared.events
    .sink { event in
        switch event {
        case .connected:
            print("Connected!")
        case .newMessage(let sessionId, let message, let isUser, _):
            print("\(isUser ? "User" : "AI"): \(message)")
        case .error(let error):
            print("Error: \(error)")
        default:
            break
        }
    }
    .store(in: &cancellables)

// Admin authentication
WebSocketManager.shared.authenticateAdmin(password: "admin123")
```

### Profile & Settings

```swift
// Get profile
let profile = try await ProfileService.shared.fetchProfile()

// Update profile
try await ProfileService.shared.updateProfile(
    name: "New Name",
    themePreference: "dark"
)

// Export all data
let exportData = try await ProfileService.shared.exportData()

// Clear all data
try await ProfileService.shared.clearAllData()
```

### Payments (Stripe)

```swift
// Create checkout session
let session = try await PaymentService.shared.createCheckoutSession(
    plan: .monthly,
    userId: AuthService.shared.currentUser?.id,
    userEmail: AuthService.shared.currentUser?.email
)

// Get checkout URL
if let url = PaymentService.shared.checkoutURL(sessionId: session.sessionId) {
    // Open in Safari or SFSafariViewController
}
```

## API Endpoints Covered

### Authentication
- `POST /api/register` - Register new user
- `POST /api/login` - User login
- `GET /api/verify` - Verify JWT token
- `GET /api/verify-email` - Email verification
- `POST /api/resend-verification` - Resend verification
- `POST /api/auth/google` - Google OAuth

### Chat
- `POST /api/chat` - Main chat endpoint (public)
- `POST /api/chat/:character_id` - Character-specific chat (auth required)
- `POST /api/feedback/:memory_id` - Submit feedback

### Characters
- `GET /api/characters` - List characters
- `POST /api/characters` - Create character
- `PUT /api/characters/:id` - Update character
- `GET /api/characters/:id/customization-options` - Get options
- `POST /api/characters/:id/customize` - Apply customization
- `GET /api/characters/:id/preview-prompt` - Preview prompt

### Models
- `GET /api/models` - List available AI models
- `POST /api/models/test` - Test a model
- `GET /api/models/health` - Health check
- `GET /api/models/recommendations/:character_id` - Get recommendations

### Conversations
- `GET /api/conversations` - List conversations
- `GET /api/conversations/:id/messages` - Get messages
- `GET /api/conversations/search` - Search conversations
- `POST /api/conversations/:id/archive` - Archive conversation
- `DELETE /api/conversations/:id` - Delete conversation
- `GET /api/conversations/:id/export` - Export conversation

### Profile
- `GET /api/profile` - Get profile
- `PUT /api/profile` - Update profile
- `GET /api/export-data` - Export all data
- `DELETE /api/clear-data` - Clear all data

### Payments
- `POST /api/create-checkout-session` - Create Stripe checkout

### WebSocket
- Real-time chat monitoring
- Session tracking
- Admin authentication

## Character Types

| Type | Display Name | Free |
|------|-------------|------|
| `laymeV1` | Layme V1 | Yes |
| `uncensoredGpt` | LayMe V1 Uncensored | No |
| `roleplay` | Mythomax Roleplay | No |
| `companion` | FastLayMe | No |
| `dominant` | Dominant AI | No |
| `submissive` | Submissive AI | No |

## Pricing Plans

| Plan | Price | Description |
|------|-------|-------------|
| Monthly | $9.99/month | Full access, billed monthly |
| Yearly | $79.99/year | Save 33%, billed annually |
| Lifetime | $199 one-time | Pay once, access forever |

## Testing

Use the built-in mock responses for testing:

```swift
// Use mock data
let mockChat = MockResponses.chatResponse
let mockModels = MockResponses.modelsResponse
let mockUser = MockResponses.mockUser

// Generate dynamic mocks
let response = MockDataGenerator.chatResponse(for: .laymeV1)
```

## Requirements

- iOS 14.0+ / macOS 12.0+
- Swift 5.7+
- Xcode 14.0+

## Architecture

```
JustLayMeAPI/
├── Models/
│   └── APIModels.swift       # All Codable models
├── Networking/
│   ├── APIClient.swift       # URLSession networking
│   └── WebSocketManager.swift # WebSocket handling
├── Services/
│   ├── AuthService.swift     # Authentication
│   ├── ChatService.swift     # Chat messaging
│   ├── CharacterService.swift # Character management
│   ├── ModelService.swift    # AI model management
│   ├── ConversationService.swift # Chat history
│   ├── ProfileService.swift  # User profile
│   └── PaymentService.swift  # Stripe payments
├── Mocks/
│   └── MockResponses.swift   # Test mocks
└── JustLayMeAPI.swift        # Public exports
```

## License

Proprietary - JustLay.me
