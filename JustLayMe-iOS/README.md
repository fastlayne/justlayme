# JustLayMe iOS App

Native iOS app for JustLayMe - connecting to the existing Node.js backend.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

### 1. Clone and Open Project

```bash
cd JustLayMe-iOS
open Package.swift
```

Or create an Xcode project and add this as a Swift Package.

### 2. Configure Server URL

Edit `Sources/App/JustLayMeApp.swift` and update `AppConfig`:

```swift
enum AppConfig {
    // Development (local server)
    static let baseURL = "http://localhost:3000"
    static let websocketURL = "ws://localhost:3000"

    // Production
    // static let baseURL = "https://justlay.me"
    // static let websocketURL = "wss://justlay.me"
}
```

### 3. Configure Google Sign-In

1. Create OAuth credentials in Google Cloud Console
2. Add your iOS bundle ID
3. Download `GoogleService-Info.plist`
4. Update `AppConfig.googleClientID`

### 4. Build and Run

```bash
# Using Xcode
xcodebuild -scheme JustLayMe -destination 'platform=iOS Simulator,name=iPhone 15'

# Or open in Xcode and press Cmd+R
```

## Architecture

### MVVM + Combine

```
Sources/
├── App/                    # App entry point and configuration
│   ├── JustLayMeApp.swift
│   └── RootView.swift
│
├── Models/                 # Data models matching backend schema
│   ├── User.swift
│   ├── Character.swift
│   ├── Conversation.swift
│   └── Payment.swift
│
├── ViewModels/             # Business logic with Combine
│   ├── AuthViewModel.swift
│   ├── ChatViewModel.swift
│   ├── ConversationViewModel.swift
│   ├── ProfileViewModel.swift
│   └── PaymentViewModel.swift
│
├── Views/                  # SwiftUI views
│   ├── Auth/
│   ├── Chat/
│   ├── Characters/
│   ├── Profile/
│   ├── Settings/
│   └── Payment/
│
├── Services/               # Networking and data services
│   ├── Networking/
│   │   ├── APIClient.swift
│   │   ├── APIEndpoint.swift
│   │   ├── AuthService.swift
│   │   └── TokenManager.swift
│   ├── WebSocket/
│   │   └── WebSocketService.swift
│   └── Persistence/
│       └── UserDefaults+Extensions.swift
│
├── Navigation/             # Navigation coordination
│   └── NavigationCoordinator.swift
│
└── Extensions/             # Swift extensions
    └── Extensions.swift
```

## Dependencies

| Package | Purpose |
|---------|---------|
| Alamofire | HTTP networking |
| Starscream | WebSocket client |
| KeychainSwift | Secure token storage |
| Nuke | Image loading/caching |
| StripePaymentSheet | Payment processing |
| GoogleSignIn | OAuth authentication |

## Feature Parity with Web

See [FEATURE_PARITY.md](FEATURE_PARITY.md) for detailed mapping.

## API Integration

The iOS app connects to the same backend API:

- **Base URL**: `http://localhost:3000` (dev) / `https://justlay.me` (prod)
- **Auth**: JWT tokens stored in Keychain
- **WebSocket**: For future real-time features

## Testing

```bash
swift test
```

## License

Proprietary - All rights reserved.
