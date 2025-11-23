# JustLayMe iOS App

Native iOS app for the JustLayMe AI chat platform, built with SwiftUI and Combine.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Architecture

The app follows the **MVVM (Model-View-ViewModel)** architecture pattern with Combine for reactive programming.

```
JustLayMe-iOS/
├── App/                    # App entry point and coordination
│   ├── JustLayMeApp.swift  # @main app entry
│   ├── AppCoordinator.swift # Navigation coordination
│   └── RootView.swift      # Root view switching
│
├── Core/
│   ├── Configuration/      # App configuration
│   │   └── AppConfig.swift # API endpoints, keys, settings
│   ├── Extensions/         # Swift extensions
│   │   └── AppColors.swift # Color scheme and fonts
│   ├── Utilities/          # Helper utilities
│   └── Protocols/          # Shared protocols
│
├── Models/                 # Data models
│   ├── User.swift          # User and auth models
│   ├── Character.swift     # AI character models
│   ├── Message.swift       # Chat message models
│   ├── Conversation.swift  # Conversation models
│   ├── AIModel.swift       # AI model definitions
│   └── Subscription.swift  # Subscription/payment models
│
├── Services/               # Business logic layer
│   ├── API/
│   │   ├── NetworkService.swift  # HTTP networking
│   │   └── APIService.swift      # API endpoint implementations
│   ├── Auth/
│   │   └── AuthService.swift     # Authentication logic
│   ├── Keychain/
│   │   └── KeychainService.swift # Secure storage
│   ├── WebSocket/
│   │   └── WebSocketService.swift # Real-time messaging
│   └── StoreKit/
│       └── StoreKitService.swift  # In-app purchases
│
├── ViewModels/             # Presentation logic
│   ├── AuthViewModel.swift
│   ├── ChatViewModel.swift
│   ├── CharacterViewModel.swift
│   ├── ProfileViewModel.swift
│   ├── SubscriptionViewModel.swift
│   └── ConversationViewModel.swift
│
├── Views/                  # SwiftUI views
│   ├── Auth/               # Authentication screens
│   ├── Chat/               # Chat interface
│   ├── Characters/         # Character browser/creator
│   ├── Profile/            # User profile
│   ├── Settings/           # App settings
│   ├── Subscription/       # Premium subscriptions
│   └── Components/         # Reusable UI components
│
└── Resources/              # Assets and config files
    ├── Assets.xcassets/    # Images, colors, app icon
    ├── Info.plist          # App configuration
    └── JustLayMe.entitlements
```

## Features

### Core Features
- **AI Chat** - Converse with multiple AI character models
- **Character Selection** - Choose from preset characters or create custom ones
- **Real-time Updates** - WebSocket connection for live messaging
- **Dark Mode** - Native dark theme matching the web design

### Authentication
- Email/Password registration and login
- Google Sign-In support
- Apple Sign-In support
- Guest mode for trying the app

### Premium Features
- In-app purchases via StoreKit 2
- Monthly, yearly, and lifetime subscription options
- Unlimited access to premium AI models
- Character creation capability

## Setup

### 1. Clone and Open
```bash
git clone https://github.com/fastlayne/justlayme.git
cd justlayme/JustLayMe-iOS
```

### 2. Generate Xcode Project (using XcodeGen)
```bash
# Install XcodeGen if not installed
brew install xcodegen

# Generate project
xcodegen generate
```

### 3. Or Use Swift Package Manager
```bash
# Open Package.swift in Xcode
open Package.swift
```

### 4. Configure Signing
- Open the project in Xcode
- Select your development team
- Update bundle identifier if needed

### 5. Configure API
Update `Core/Configuration/AppConfig.swift`:
```swift
static var environment: Environment {
    #if DEBUG
    return .development // Points to localhost:3000
    #else
    return .production  // Points to https://justlay.me
    #endif
}
```

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [Alamofire](https://github.com/Alamofire/Alamofire) | 5.8+ | HTTP networking |
| [Nuke](https://github.com/kean/Nuke) | 12.0+ | Image loading/caching |
| [KeychainSwift](https://github.com/evgenyneu/keychain-swift) | 20.0+ | Secure token storage |
| [Starscream](https://github.com/daltoniam/Starscream) | 4.0+ | WebSocket client |

## API Endpoints

The app connects to the JustLayMe backend at:
- **Development**: `http://localhost:3000`
- **Production**: `https://justlay.me`

See `Core/Configuration/AppConfig.swift` for all endpoint definitions.

## Build Configurations

### Debug
- Development API endpoint
- Debug logging enabled
- Product name: "JustLayMe Dev"

### Release
- Production API endpoint
- Optimized compilation
- Product name: "JustLayMe"

## Testing

```bash
# Run unit tests
xcodebuild test -scheme JustLayMe -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests
xcodebuild test -scheme JustLayMeUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

## App Store Submission

1. Update version in `project.yml`
2. Archive the Release build
3. Upload to App Store Connect
4. Complete app metadata

### Required Screenshots
- 6.7" (iPhone 15 Pro Max)
- 6.5" (iPhone 14 Plus)
- 5.5" (iPhone 8 Plus)
- 12.9" iPad Pro (if supporting iPad)

## Color Scheme

| Color | Hex | Usage |
|-------|-----|-------|
| Primary | `#8B5CF6` | Accent, buttons, links |
| Primary Light | `#A78BFA` | Gradients |
| Dark Background | `#0F0F23` | Main background |
| Card Background | `#1A1A2E` | Cards, modals |
| Text Primary | `#FFFFFF` | Main text |
| Text Secondary | `#A0AEC0` | Subtitle text |
| Success | `#48BB78` | Success states |
| Error | `#F56565` | Error states |

## License

Proprietary - All rights reserved.

## Support

For issues and feature requests, contact: support@justlay.me
