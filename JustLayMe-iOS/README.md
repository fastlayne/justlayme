# JustLayMe iOS App

Native iOS app converted from the JustLayMe web application.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Project Structure

```
JustLayMe-iOS/
├── JustLayMe/
│   ├── App/
│   │   ├── JustLayMeApp.swift          # App entry point
│   │   └── ContentView.swift           # Main view controller
│   ├── Models/
│   │   ├── User.swift                  # User data model
│   │   ├── Character.swift             # AI character models
│   │   ├── Message.swift               # Chat message models
│   │   └── Subscription.swift          # Subscription plans
│   ├── Services/
│   │   ├── NetworkManager.swift        # HTTP networking layer
│   │   ├── APIService.swift            # API endpoint methods
│   │   ├── AuthManager.swift           # Authentication state
│   │   └── KeychainService.swift       # Secure storage
│   ├── ViewModels/
│   │   ├── ChatViewModel.swift         # Chat logic
│   │   ├── AuthViewModel.swift         # Auth form logic
│   │   ├── ProfileViewModel.swift      # Profile management
│   │   └── SettingsViewModel.swift     # Settings management
│   ├── Views/
│   │   ├── Auth/
│   │   │   ├── AuthenticationView.swift
│   │   │   └── VerificationView.swift
│   │   ├── Chat/
│   │   │   ├── ChatView.swift
│   │   │   └── CharacterSelectorView.swift
│   │   ├── Paywall/
│   │   │   └── PaywallView.swift
│   │   ├── Profile/
│   │   │   └── ProfileView.swift
│   │   ├── Settings/
│   │   │   └── SettingsView.swift
│   │   └── Components/
│   │       └── CustomTextField.swift
│   ├── Utilities/
│   │   ├── ThemeManager.swift          # Color scheme management
│   │   └── UserDefaultsManager.swift   # Preferences storage
│   └── Resources/
│       └── Info.plist
└── JustLayMe.xcodeproj/
```

## Features Implemented

### Phase 1 - Analysis ✅
- Analyzed entire codebase structure
- Identified 15+ API endpoints
- Mapped all web components to iOS equivalents

### Phase 2 - Foundation ✅
- Created Xcode project structure
- Built networking layer with async/await
- Created data models matching API
- Implemented base ViewModels with Combine

### Phase 3 - Screens ✅
- **AuthenticationView**: Login/signup with form validation
- **VerificationView**: Email verification flow
- **ChatView**: Message display with typing indicators
- **CharacterSelectorView**: Horizontal character picker
- **PaywallView**: Subscription plan selection
- **ProfileView**: User profile settings
- **SettingsView**: App preferences

### Phase 4 - Features ✅
- JWT authentication flow
- Keychain secure token storage
- Theme management (light/dark/auto)
- User preferences persistence
- Stripe payment integration ready

## API Integration

The app connects to the existing backend at `https://justlay.me`:

| Endpoint | Description |
|----------|-------------|
| POST /api/register | User registration |
| POST /api/login | User authentication |
| GET /api/verify | Token validation |
| POST /api/chat | Send message to AI |
| GET /api/characters | List AI characters |
| GET/PUT /api/profile | User profile |
| POST /api/create-checkout-session | Stripe payment |

## Design System

Colors from web app preserved:
- Primary: #6b46ff (Purple)
- Secondary: #ff4690 (Pink)
- Gold: #ffd700
- Dark BG: #0a0a0a
- Card BG: #1a1a1f

## Getting Started

1. Open `JustLayMe.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run on simulator or device

## Next Steps

- [ ] Add Google Sign-In SDK
- [ ] Implement push notifications
- [ ] Add character creator view
- [ ] Implement conversation history
- [ ] Add haptic feedback
- [ ] Create widget extension
- [ ] Add App Clips support

## Notes

- The project uses SwiftUI with iOS 17 features
- MVVM architecture with Combine for reactivity
- All network calls use async/await
- Sensitive data stored in Keychain
- User preferences in UserDefaults
