# JustLayMe iOS

Native iOS chat interface for the JustLayMe AI platform, matching the web implementation at https://justlay.me.

## Features

### Chat Interface
- **Conversation List**: View all conversations with search and filter
- **Chat View**: Message bubbles with streaming text animation
- **Model Selection**: Switch between AI models mid-conversation
- **Message Actions**: Copy, regenerate, and delete messages

### AI Models
1. **Layme V1** - FREE & Unlimited (default)
2. **LayMe Uncensored** - Premium (3 free messages)
3. **Mythomax Roleplay** - Premium (3 free messages)
4. **FastLayMe** - Premium (3 free messages)

### Settings
- Server connection (URL, test connection)
- Model defaults (temperature, top_p, max_tokens)
- System prompt configuration
- Chat preferences (auto-scroll, notifications)
- Privacy settings
- Data management (export, clear)

## Architecture

### Project Structure
```
ios/JustLayMe/
├── Sources/
│   ├── App/
│   │   └── JustLayMeApp.swift       # App entry point
│   ├── Models/
│   │   └── ChatModels.swift         # Data models
│   ├── Services/
│   │   ├── APIService.swift         # API communication
│   │   └── PersistenceController.swift # CoreData
│   ├── ViewModels/
│   │   └── ChatViewModel.swift      # Business logic
│   ├── Views/
│   │   ├── Chat/
│   │   │   ├── ConversationListView.swift
│   │   │   └── ChatView.swift
│   │   ├── Settings/
│   │   │   └── SettingsView.swift
│   │   └── Components/
│   │       └── StreamingTextView.swift
│   └── CoreData/
│       └── JustLayMe.xcdatamodeld
├── Package.swift
└── README.md
```

### Key Components

#### ChatViewModel
- Combine publishers for reactive UI
- Message queue management
- CoreData persistence
- Auto-reconnect logic
- Offline mode support

#### APIService
- RESTful API communication
- Authentication handling
- Session management
- Error handling with fallbacks

#### Streaming Text
- Word-by-word animation matching web
- Markdown rendering support
- Code block highlighting

## API Endpoints

The app communicates with the JustLayMe server:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/chat` | POST | Send message, get AI response |
| `/api/models` | GET | List available AI models |
| `/api/conversations` | GET | List user conversations |
| `/api/conversations/:id/messages` | GET | Get conversation messages |
| `/api/login` | POST | User authentication |
| `/api/profile` | GET/PUT | User profile management |

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

### Using Xcode
1. Open `JustLayMe.xcodeproj` in Xcode
2. Select your target device/simulator
3. Build and run (Cmd + R)

### Using Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/fastlayne/justlayme", from: "1.0.0")
]
```

## Configuration

### Server URL
Default: `https://justlay.me`

Configure in Settings > Server Connection or programmatically:
```swift
APIService.shared.configure(baseURL: "https://your-server.com")
```

### Model Parameters
- **Temperature**: 0.0 - 2.0 (default: 0.8)
- **Top P**: 0.0 - 1.0 (default: 0.9)
- **Max Tokens**: 100 - 2000 (default: 500)

## Premium Features

Premium subscription unlocks:
- Unlimited messages on all models
- Custom character creation
- Chat history export
- Priority responses

### Pricing
- Monthly: $9.99/month
- Yearly: $79.99/year (save 33%)
- Lifetime: $199 (one-time)

## Data Storage

### Local (CoreData)
- Conversations
- Messages
- User settings

### Server
- User accounts
- Subscription status
- Character customizations

## Privacy

- No data collected without consent
- Conversations stored locally by default
- Optional server sync for premium users
- Analytics opt-out available

## License

Proprietary - JustLayMe 2024

## Support

- Website: https://justlay.me
- Email: support@justlayme.com
