# Feature Parity: Web to iOS

This document maps web features to their iOS implementations.

## Screen Mapping

| Web Component | iOS Screen | Implementation |
|---------------|------------|----------------|
| Login/Signup Modal | `AuthView` | Full auth flow with Google |
| Main Chat Interface | `ChatView` | TabView > Chat tab |
| **Black Mirror Page** | `BlackMirrorView` | TabView > Analyze tab |
| Character Selector | `CharacterPickerSheet` | Sheet presentation |
| Character Creator | `CreateCharacterView` | Sheet from Characters tab |
| Settings Modal | `SettingsView` | TabView > Settings tab |
| Profile Modal | `ProfileView` | TabView > Profile tab |
| Subscription Modal | `PaywallView` | Sheet presentation |
| Admin Monitor | Not included | Admin features excluded |

## Feature Checklist

### Authentication
| Feature | Web | iOS | Notes |
|---------|-----|-----|-------|
| Email/Password Login | ✅ | ✅ | `AuthViewModel.login()` |
| Email/Password Register | ✅ | ✅ | `AuthViewModel.register()` |
| Google OAuth | ✅ | ✅ | GoogleSignIn SDK |
| Email Verification | ✅ | ✅ | `VerificationSentView` |
| Guest Mode | ✅ | ✅ | `AuthViewModel.continueAsGuest()` |
| JWT Token Storage | localStorage | Keychain | More secure on iOS |
| Auto-login | ✅ | ✅ | Token verification on launch |

### Chat
| Feature | Web | iOS | Notes |
|---------|-----|-----|-------|
| Send Message | ✅ | ✅ | `ChatViewModel.sendMessage()` |
| Receive AI Response | ✅ | ✅ | Async/await pattern |
| Typing Indicator | ✅ | ✅ | `TypingIndicator` view |
| Message History | ✅ | ✅ | Scrollable LazyVStack |
| Character Selection | ✅ | ✅ | `CharacterPickerSheet` |
| Session Persistence | ✅ | ✅ | X-Session-ID header |
| Free Message Limit | ✅ | ✅ | Premium paywall trigger |

### AI Characters
| Feature | Web | iOS | Notes |
|---------|-----|-----|-------|
| Layme V1 (Free) | ✅ | ✅ | Default character |
| LayMe Uncensored | ✅ | ✅ | Premium required |
| Mythomax Roleplay | ✅ | ✅ | Premium required |
| FastLayMe | ✅ | ✅ | Premium required |
| Custom Characters | ✅ | ✅ | `CreateCharacterView` |
| Character Customization | ✅ | ✅ | `CharacterCustomizeView` |

### Payments
| Feature | Web | iOS | Notes |
|---------|-----|-----|-------|
| Monthly Plan | ✅ | ✅ | $9.99/month |
| Yearly Plan | ✅ | ✅ | $79.99/year |
| Lifetime Plan | ✅ | ✅ | $199 one-time |
| Stripe Checkout | ✅ | ✅ | Opens web checkout |
| Premium Status | ✅ | ✅ | User.isPremium |

### Profile & Settings
| Feature | Web | iOS | Notes |
|---------|-----|-----|-------|
| View Profile | ✅ | ✅ | `ProfileView` |
| Update Name | ✅ | ✅ | `ProfileViewModel.updateProfile()` |
| Avatar Style | ✅ | ✅ | Picker in profile |
| Theme Selection | ✅ | ✅ | Light/Dark/System |
| Response Length | ✅ | ✅ | Short/Medium/Long |
| Auto-scroll | ✅ | ✅ | Toggle setting |
| Sound Notifications | ✅ | ✅ | Toggle setting |
| Analytics Opt-out | ✅ | ✅ | Toggle setting |

### Data Management
| Feature | Web | iOS | Notes |
|---------|-----|-----|-------|
| Export Data | ✅ | ✅ | JSON export with ShareSheet |
| Clear All Data | ✅ | ✅ | Confirmation dialog |
| Conversation History | ✅ | ✅ | `ConversationHistoryView` |
| Search Conversations | ✅ | ✅ | Searchable modifier |
| Delete Conversation | ✅ | ✅ | Swipe action |
| Archive Conversation | ✅ | ✅ | Swipe action |

## API Endpoint Mapping

### Authentication
```
POST /api/login          → APIEndpoint.login()
POST /api/register       → APIEndpoint.register()
POST /api/auth/google    → APIEndpoint.googleAuth()
GET  /api/verify         → APIEndpoint.verifyToken
POST /api/resend-verification → APIEndpoint.resendVerification()
```

### Chat
```
POST /api/chat           → APIEndpoint.sendMessage()
POST /api/feedback/:id   → APIEndpoint.sendFeedback()
```

### Characters
```
GET  /api/characters     → APIEndpoint.characters
POST /api/characters     → APIEndpoint.createCharacter()
PUT  /api/characters/:id → APIEndpoint.updateCharacter()
GET  /api/characters/:id/customization-options → APIEndpoint.characterCustomizationOptions()
POST /api/characters/:id/customize → APIEndpoint.customizeCharacter()
```

### Conversations
```
GET  /api/conversations           → APIEndpoint.conversations()
GET  /api/conversations/:id/messages → APIEndpoint.conversationMessages()
GET  /api/conversations/search    → APIEndpoint.searchConversations()
POST /api/conversations/:id/archive → APIEndpoint.archiveConversation()
DELETE /api/conversations/:id     → APIEndpoint.deleteConversation()
GET  /api/conversations/:id/export → APIEndpoint.exportConversation()
```

### Profile
```
GET  /api/profile        → APIEndpoint.profile
PUT  /api/profile        → APIEndpoint.updateProfile()
GET  /api/export-data    → APIEndpoint.exportData
DELETE /api/clear-data   → APIEndpoint.clearData
```

### Payments
```
POST /api/create-checkout-session → APIEndpoint.createCheckoutSession()
```

## Data Model Mapping

### User
```
Web (JavaScript)              iOS (Swift)
----------------              -----------
id                     →      id: String
email                  →      email: String
name                   →      name: String?
google_id              →      googleId: String?
subscription_status    →      subscriptionStatus: SubscriptionStatus
subscription_end       →      subscriptionEnd: Date?
message_count          →      messageCount: Int
email_verified         →      emailVerified: Bool
created_at             →      createdAt: Date?
last_login             →      lastLogin: Date?
```

### Character
```
Web (JavaScript)              iOS (Swift)
----------------              -----------
id                     →      id: String
user_id                →      userId: String?
name                   →      name: String
backstory              →      backstory: String?
personality_traits     →      personalityTraits: [String]?
speech_patterns        →      speechPatterns: [String]?
avatar_url             →      avatarUrl: String?
is_public              →      isPublic: Bool
created_at             →      createdAt: Date?
```

### Message
```
Web (JavaScript)              iOS (Swift)
----------------              -----------
id                     →      id: String
conversation_id        →      conversationId: String?
sender_type            →      senderType: SenderType
content                →      content: String
metadata               →      metadata: MessageMetadata?
created_at             →      createdAt: Date?
```

## LocalStorage → UserDefaults/Keychain

| Web (localStorage) | iOS | Storage |
|--------------------|-----|---------|
| authToken | TokenManager.authToken | Keychain |
| currentUser | TokenManager.currentUser | UserDefaults |
| avatarStyle | SettingsManager.avatarStyle | UserDefaults |
| themePreference | SettingsManager.themePreference | UserDefaults |
| defaultCharacter | SettingsManager.defaultCharacter | UserDefaults |
| responseLength | SettingsManager.responseLength | UserDefaults |
| autoScroll | SettingsManager.autoScroll | UserDefaults |
| soundNotifications | SettingsManager.soundNotifications | UserDefaults |
| saveConversations | SettingsManager.saveConversations | UserDefaults |
| analyticsOptOut | SettingsManager.analyticsOptOut | UserDefaults |

## Features NOT Included in iOS

1. **Admin Monitor** - Admin dashboard is web-only
2. **WebSocket Real-time Updates** - Infrastructure ready but not active
3. **Email Verification Page** - Opens in browser instead

## iOS-Specific Enhancements

1. **Keychain Storage** - More secure than web localStorage
2. **Native Share Sheet** - System sharing for exports
3. **Pull to Refresh** - Native refresh patterns
4. **Swipe Actions** - Archive/delete conversations
5. **Haptic Feedback** - Can be added for interactions
6. **Face ID/Touch ID** - Can be added for app unlock
7. **Widgets** - Potential for quick chat access
8. **Shortcuts** - Siri integration potential
