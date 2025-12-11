# JustLayMe Architecture Blueprint
## Comprehensive Production-Grade System Design

**Version**: 1.0
**Status**: Complete & Locked
**Last Updated**: 2024-11-13

---

## TABLE OF CONTENTS

1. [System Overview](#system-overview)
2. [User Journey Maps](#user-journey-maps)
3. [Context Providers](#context-providers)
4. [Component Hierarchy](#component-hierarchy)
5. [Custom Hooks](#custom-hooks)
6. [API Service Layer](#api-service-layer)
7. [State Management Flows](#state-management-flows)
8. [Modal System](#modal-system)
9. [Sidebar Architecture](#sidebar-architecture)
10. [RelationshipX Deep-Dive](#relationshipx-deep-dive)
11. [Animations & UX](#animations--ux)
12. [Responsive Design](#responsive-design)
13. [Error Handling](#error-handling)
14. [File Structure](#file-structure)
15. [Implementation Phases](#implementation-phases)
16. [Technical Decisions](#technical-decisions)

---

## SYSTEM OVERVIEW

### Three Integrated Features

**Feature 1: Chat Interface**
- Left collapsible sidebar with conversation/character list
- Main chat area with message display and input
- Character selector at top of chat
- Message virtualization for large conversations
- Real-time message updates

**Feature 2: Character Creation**
- Split-screen immersive modal
- Left: Multi-step form with validation
- Right: Live preview card updating in real-time
- Premium fade-in with logo reveal animation
- Full character customization (name, bio, personality, voice, system prompt)

**Feature 3: RelationshipX Analysis**
- Dedicated route with portal transition
- Three upload methods: paste text, file upload, screenshot OCR
- Interactive metrics explorer (expandable cards)
- Metrics: sentiment, communication patterns, engagement, toxicity, conflict resolution
- Backend ML analysis pipeline

### Architecture Philosophy

✅ **No Shortcuts** - Production-grade patterns everywhere
✅ **Systematic** - Every decision documented with rationale
✅ **Scalable** - Handles 10k+ messages, 100+ characters, large file uploads
✅ **Maintainable** - Clear separation of concerns, modular components
✅ **Testable** - Unit, integration, and E2E test coverage
✅ **Accessible** - WCAG 2.1 AA compliance throughout

---

## USER JOURNEY MAPS

### Journey 1: Start a New Chat Conversation

```
Landing Page (IndexPage)
    ↓
[Click "Get Started" or "Start Free Today"]
    ↓ (Gradient Portal Transition)
Chat Interface (ChatPage)
    ↓
[Sidebar shows existing characters OR "Create Character" prompt]
    ↓
[User selects character OR creates new one]
    ↓
[Chat conversation starts]
    ↓
[Messages flow in real-time]
    ↓
[User can switch characters anytime from top selector]
```

### Journey 2: Create a New Character

```
[Within Chat Interface]
    ↓
[Click "New Character" button]
    ↓ (Premium Fade + Logo Reveal Modal)
Character Creation Modal Opens
    ↓
[Step 1: Basic Info - name, bio, avatar]
    ↓
[Right panel: Live preview updates]
    ↓
[Step 2: Personality - traits, tone, style]
    ↓
[Right panel: Preview evolves]
    ↓
[Step 3: Advanced - system prompt, response settings]
    ↓
[User clicks "Create Character"]
    ↓
[Modal fades out, character appears in sidebar]
    ↓
[Chat with new character begins]
```

### Journey 3: Analyze Relationship Data (RelationshipX)

```
[Chat Interface]
    ↓
[Click "RelationshipX" in sidebar/menu]
    ↓ (Portal Transition to /relationship-analysis)
RelationshipX Page
    ↓
[User chooses upload method:]
    ├─ Paste conversation text
    ├─ Upload SMS/iMessage file
    └─ Upload screenshot (with OCR)
    ↓
[File processed and sent to backend]
    ↓
[Loading state with progress indicator]
    ↓
[ML pipeline analyzes: sentiment, patterns, engagement, etc.]
    ↓
[Results page with interactive metrics explorer]
    ↓
[User clicks on metrics to expand and see deeper insights]
    ↓
[Can go back to upload new data]
```

---

## CONTEXT PROVIDERS

### Provider 1: AuthContext
**Purpose**: User authentication, session management
**State**:
```javascript
{
  user: {
    id: string,
    email: string,
    name: string,
    avatar?: string,
    plan: 'free' | 'premium' | 'pro'
  },
  isAuthenticated: boolean,
  isLoading: boolean,
  error: string | null,
  token: string | null
}
```
**Methods**: `login()`, `logout()`, `signup()`, `refreshToken()`
**Used By**: Every protected route, API interceptors

### Provider 2: ChatContext
**Purpose**: Chat messages, conversations, active conversation state
**State**:
```javascript
{
  conversations: Conversation[],
  activeConversationId: string | null,
  messages: Message[],
  isLoadingMessages: boolean,
  messageError: string | null,
  typingIndicator: {
    isVisible: boolean,
    characterName: string
  },
  pagination: {
    page: number,
    pageSize: number,
    hasMore: boolean
  }
}
```
**Methods**:
- `startConversation(characterId)`
- `sendMessage(content)`
- `loadMoreMessages(conversationId)`
- `deleteConversation(conversationId)`
- `archiveConversation(conversationId)`

**Reducer Pattern**: useReducer with action types:
```javascript
LOAD_MESSAGES | LOAD_MORE_MESSAGES | ADD_MESSAGE | DELETE_MESSAGE |
SET_TYPING | CLEAR_TYPING | SET_ERROR | CLEAR_ERROR
```

### Provider 3: CharacterContext
**Purpose**: Character management, selection, creation
**State**:
```javascript
{
  characters: Character[],
  activeCharacterId: string | null,
  isLoadingCharacters: boolean,
  characterError: string | null,
  recentCharacters: Character[]
}
```
**Character Schema**:
```javascript
{
  id: string,
  userId: string,
  name: string,
  bio: string,
  avatar: string,
  personality: {
    traits: string[],
    tone: 'formal' | 'casual' | 'flirty' | 'professional',
    style: string
  },
  voiceSettings: {
    voiceId: string,
    pitch: number,
    speed: number
  },
  systemPrompt: string,
  createdAt: Date,
  updatedAt: Date,
  messageCount: number,
  lastUsed: Date
}
```
**Methods**:
- `selectCharacter(id)`
- `createCharacter(data)`
- `updateCharacter(id, data)`
- `deleteCharacter(id)`
- `getCharacterById(id)`

### Provider 4: UIContext
**Purpose**: Modal state, sidebar state, UI preferences
**State**:
```javascript
{
  sidebarOpen: boolean,
  modalStack: Modal[],
  notificationQueue: Notification[],
  theme: 'dark' | 'light',
  isMobile: boolean,
  selectedTab: string
}
```
**Modal Type**:
```javascript
{
  id: string,
  type: 'character-creator' | 'confirm-delete' | 'settings' | 'upload-relationship',
  isOpen: boolean,
  data?: any
}
```
**Methods**:
- `toggleSidebar()`
- `openModal(type, data)`
- `closeModal(id)`
- `closeAllModals()`
- `addNotification(message, type)`
- `removeNotification(id)`
- `setTheme(theme)`

### Provider 5: RelationshipContext
**Purpose**: RelationshipX analysis state
**State**:
```javascript
{
  uploadedFile: File | null,
  uploadProgress: number,
  isAnalyzing: boolean,
  analysisResults: AnalysisResults | null,
  error: string | null,
  selectedMetrics: string[]
}
```
**Analysis Results Schema**:
```javascript
{
  id: string,
  timestamp: Date,
  uploadMethod: 'paste' | 'file' | 'screenshot',
  metrics: {
    sentiment: {
      overall: number,
      trends: number[],
      byPerson: { name: string, score: number }[]
    },
    communicationPatterns: {
      messageFrequency: number,
      averageResponseTime: number,
      topicClusters: string[]
    },
    emotionalEngagement: {
      score: number,
      depth: string,
      vulnerabilityIndex: number
    },
    conflictMetrics: {
      conflictCount: number,
      resolutionRate: number,
      triggers: string[]
    },
    toxicity: number,
    positivityIndex: number
  }
}
```
**Methods**:
- `uploadConversationData(file, method)`
- `analyzeData()`
- `toggleMetricExpanded(metricId)`
- `exportResults()`
- `clearResults()`

### Provider 6: ModalManagerContext
**Purpose**: Advanced modal management (stacking, animations, logic)
**Methods**:
- `showCharacterCreator()`
- `showDeleteConfirm(type, id)`
- `showUploadRelationship()`
- `closeTopModal()`
- `closeAllModals()`

---

## COMPONENT HIERARCHY

```
App
├── PageTransitionProvider
├── AuthContext.Provider
├── ChatContext.Provider
├── CharacterContext.Provider
├── UIContext.Provider
├── RelationshipContext.Provider
└── Router
    └── TransitionWrapper
        ├── Routes
        │   ├── Route "/" → IndexPage
        │   ├── Route "/chat" → ChatPage
        │   │   ├── ChatLayout
        │   │   │   ├── Sidebar
        │   │   │   │   ├── SidebarHeader
        │   │   │   │   │   ├── Logo
        │   │   │   │   │   └── MenuButton
        │   │   │   │   ├── ConversationList
        │   │   │   │   │   └── ConversationItem[] (virtualized)
        │   │   │   │   ├── CharacterSelector
        │   │   │   │   │   ├── RecentCharacters
        │   │   │   │   │   └── ViewAllCharacters
        │   │   │   │   ├── NewCharacterButton
        │   │   │   │   └── SidebarFooter (settings, logout)
        │   │   │   │
        │   │   │   └── ChatArea
        │   │   │       ├── ChatHeader
        │   │   │       │   ├── CharacterInfo
        │   │   │       │   ├── ConnectionStatus
        │   │   │       │   └── MoreOptions
        │   │   │       ├── MessageList
        │   │   │       │   ├── Message[] (virtualized with react-window)
        │   │   │       │   │   ├── UserMessage
        │   │   │       │   │   ├── CharacterMessage
        │   │   │       │   │   └── SystemMessage
        │   │   │       │   └── TypingIndicator
        │   │   │       └── InputArea
        │   │   │           ├── MessageInput
        │   │   │           ├── FileUploadButton
        │   │   │           └── SendButton
        │   │   │
        │   │   └── ModalsContainer
        │   │       ├── CharacterCreatorModal
        │   │       │   ├── FormTabs (Basic | Personality | Advanced)
        │   │       │   │   └── TabContent with FormFields
        │   │       │   ├── LivePreviewPanel
        │   │       │   └── ActionButtons (Save | Cancel)
        │   │       └── OtherModals (DeleteConfirm, Settings, etc.)
        │   │
        │   └── Route "/relationship-analysis" → RelationshipXPage
        │       ├── UploadSection
        │       │   ├── UploadTabs (Paste | File | Screenshot)
        │       │   ├── FileDropZone
        │       │   ├── ProcessingIndicator
        │       │   └── UploadButton
        │       │
        │       └── ResultsSection
        │           ├── MetricsExplorer
        │           │   └── MetricCard[] (expandable)
        │           │       ├── MetricHeader (title, score)
        │           │       └── MetricDetails (hidden until expanded)
        │           └── ExportButton
        │
        └── ErrorBoundary (wraps all routes)
```

### Component Specifications

**ChatLayout**
- Props: `none` (uses context)
- Manages sidebar collapse state
- Coordinates between Sidebar and ChatArea
- Handles responsive behavior

**Sidebar**
- Props: `isOpen: boolean`, `onToggle: () => void`
- Displays conversations, characters, settings
- Collapses to hamburger on mobile
- Sticky footer with user profile

**ConversationList**
- Props: `conversations: Conversation[]`
- Virtual scrolling with react-window
- Lazy loads older conversations
- Click to switch conversation

**CharacterCreatorModal**
- Props: `isOpen: boolean`, `onClose: () => void`, `onSave: (character) => void`
- Form validation with react-hook-form
- Split-screen with live preview
- Logo reveal animation on open

**MessageList**
- Props: `messages: Message[]`, `isLoading: boolean`
- Virtual scrolling for 10k+ messages
- Auto-scroll to bottom on new message
- Scroll up to load older messages

**RelationshipXPage**
- Three upload methods
- Real-time progress indication
- Interactive metrics explorer
- Expandable metric cards

---

## CUSTOM HOOKS

### useChat()
**Purpose**: Manage chat operations and state
**Signature**:
```javascript
function useChat() {
  return {
    conversations: Conversation[],
    activeConversation: Conversation | null,
    messages: Message[],
    isLoadingMessages: boolean,
    startConversation: (characterId: string) => Promise<void>,
    sendMessage: (content: string) => Promise<Message>,
    loadMoreMessages: (conversationId: string) => Promise<void>,
    deleteConversation: (id: string) => Promise<void>,
    error: string | null,
    clearError: () => void
  }
}
```
**Implementation**:
- Wraps ChatContext dispatch
- Handles API calls via chatAPI service
- Manages optimistic updates
- Implements error recovery

### useCharacters()
**Purpose**: Character management and selection
**Signature**:
```javascript
function useCharacters() {
  return {
    characters: Character[],
    activeCharacter: Character | null,
    isLoading: boolean,
    selectCharacter: (id: string) => Promise<void>,
    createCharacter: (data: CharacterData) => Promise<Character>,
    updateCharacter: (id: string, data: Partial<Character>) => Promise<void>,
    deleteCharacter: (id: string) => Promise<void>,
    error: string | null
  }
}
```

### useModal()
**Purpose**: Modal management
**Signature**:
```javascript
function useModal(modalType: ModalType) {
  return {
    isOpen: boolean,
    data: any,
    openModal: (data?: any) => void,
    closeModal: () => void,
    updateData: (data: any) => void
  }
}
```
**Usage**:
```javascript
const characterModal = useModal('character-creator');
characterModal.openModal();
```

### useRelationshipAnalysis()
**Purpose**: RelationshipX analysis operations
**Signature**:
```javascript
function useRelationshipAnalysis() {
  return {
    uploadFile: (file: File, method: UploadMethod) => Promise<void>,
    analyzeData: () => Promise<AnalysisResults>,
    results: AnalysisResults | null,
    isAnalyzing: boolean,
    uploadProgress: number,
    expandMetric: (metricId: string) => void,
    collapseMetric: (metricId: string) => void,
    error: string | null
  }
}
```

### useSidebar()
**Purpose**: Sidebar state management
**Signature**:
```javascript
function useSidebar() {
  return {
    isOpen: boolean,
    isMobile: boolean,
    toggle: () => void,
    open: () => void,
    close: () => void
  }
}
```

### useNotification()
**Purpose**: Notification management
**Signature**:
```javascript
function useNotification() {
  return {
    addNotification: (message: string, type: 'success' | 'error' | 'info') => void,
    removeNotification: (id: string) => void,
    notifications: Notification[]
  }
}
```

### useVirtualization()
**Purpose**: Virtual scrolling for large lists
**Signature**:
```javascript
function useVirtualization(items: any[], itemHeight: number, containerHeight: number) {
  return {
    visibleItems: any[],
    startIndex: number,
    endIndex: number,
    totalHeight: number,
    handleScroll: (scrollTop: number) => void
  }
}
```

### useDebounce()
**Purpose**: Debounce hook for search, typing, etc.
**Signature**:
```javascript
function useDebounce(value: any, delay: number) {
  return debouncedValue: any
}
```

---

## API SERVICE LAYER

### Axios Client Setup
```javascript
// /src/services/client.js
const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:3333',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  }
})

// Request interceptor - add auth token
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('authToken')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// Response interceptor - handle errors
apiClient.interceptors.response.use(
  (response) => response.data,
  (error) => {
    if (error.response?.status === 401) {
      // Handle logout
    }
    return Promise.reject(error)
  }
)

export default apiClient
```

### Chat API Service
```javascript
// /src/services/chatAPI.js
export const chatAPI = {
  // Get all conversations
  getConversations: () =>
    apiClient.get('/api/conversations'),

  // Get specific conversation with messages
  getConversation: (conversationId) =>
    apiClient.get(`/api/conversations/${conversationId}`, {
      params: { page: 0, limit: 50 }
    }),

  // Get paginated messages
  getMessages: (conversationId, page = 0, limit = 50) =>
    apiClient.get(`/api/conversations/${conversationId}/messages`, {
      params: { page, limit }
    }),

  // Start new conversation with character
  startConversation: (characterId) =>
    apiClient.post('/api/conversations', { characterId }),

  // Send message
  sendMessage: (conversationId, content, metadata = {}) =>
    apiClient.post(`/api/conversations/${conversationId}/messages`, {
      content,
      metadata,
      timestamp: new Date().toISOString()
    }),

  // Delete conversation
  deleteConversation: (conversationId) =>
    apiClient.delete(`/api/conversations/${conversationId}`),

  // Archive conversation
  archiveConversation: (conversationId) =>
    apiClient.patch(`/api/conversations/${conversationId}`, {
      archived: true
    })
}
```

### Character API Service
```javascript
// /src/services/characterAPI.js
export const characterAPI = {
  // Get all characters
  getCharacters: () =>
    apiClient.get('/api/characters'),

  // Get character by ID
  getCharacter: (id) =>
    apiClient.get(`/api/characters/${id}`),

  // Create character
  createCharacter: (characterData) =>
    apiClient.post('/api/characters', {
      name: characterData.name,
      bio: characterData.bio,
      avatar: characterData.avatar,
      personality: characterData.personality,
      voiceSettings: characterData.voiceSettings,
      systemPrompt: characterData.systemPrompt
    }),

  // Update character
  updateCharacter: (id, updates) =>
    apiClient.patch(`/api/characters/${id}`, updates),

  // Delete character
  deleteCharacter: (id) =>
    apiClient.delete(`/api/characters/${id}`),

  // Test character response (preview)
  testCharacterResponse: (characterData, prompt) =>
    apiClient.post('/api/characters/test-response', {
      character: characterData,
      prompt
    })
}
```

### RelationshipX API Service
```javascript
// /src/services/relationshipAPI.js
export const relationshipAPI = {
  // Upload and analyze conversation data
  uploadAndAnalyze: (file, method = 'paste') =>
    apiClient.post('/api/relationship/analyze', {
      data: file,
      method,
      timestamp: new Date().toISOString()
    }, {
      headers: method === 'file' ? { 'Content-Type': 'multipart/form-data' } : {}
    }),

  // Process screenshot with OCR
  processScreenshot: (imageFile) =>
    apiClient.post('/api/relationship/ocr',
      { image: imageFile },
      { headers: { 'Content-Type': 'multipart/form-data' } }
    ),

  // Get analysis progress
  getAnalysisProgress: (analysisId) =>
    apiClient.get(`/api/relationship/progress/${analysisId}`),

  // Get analysis results
  getResults: (analysisId) =>
    apiClient.get(`/api/relationship/results/${analysisId}`),

  // Export results
  exportResults: (analysisId, format = 'pdf') =>
    apiClient.get(`/api/relationship/export/${analysisId}`, {
      params: { format },
      responseType: 'blob'
    })
}
```

### Auth API Service
```javascript
// /src/services/authAPI.js
export const authAPI = {
  // User login
  login: (email, password) =>
    apiClient.post('/api/auth/login', { email, password }),

  // User signup
  signup: (email, password, name) =>
    apiClient.post('/api/auth/signup', { email, password, name }),

  // Refresh token
  refreshToken: (token) =>
    apiClient.post('/api/auth/refresh', { token }),

  // Logout (client-side)
  logout: () => {
    localStorage.removeItem('authToken')
    localStorage.removeItem('refreshToken')
  },

  // Get current user
  getCurrentUser: () =>
    apiClient.get('/api/auth/me')
}
```

---

## STATE MANAGEMENT FLOWS

### Flow 1: User Sends a Message

```javascript
// User types and clicks send
InputArea.jsx:
  1. User enters text in message input
  2. Clicks send button
  3. Component calls: const { sendMessage } = useChat()
  4. sendMessage(messageText)

useChat() hook:
  1. Creates optimistic message object with temporary ID
  2. Dispatches ADD_MESSAGE to ChatContext (shows immediately)
  3. Calls: const response = await chatAPI.sendMessage(...)
  4. On success: Updates message with real ID and timestamp
  5. On error: Shows error toast, reverts optimistic update

ChatContext reducer:
  1. ADD_MESSAGE: Adds message to messages array
  2. UPDATE_MESSAGE: Replaces temporary with real message
  3. SET_ERROR: Shows error notification

API Response:
  1. Backend receives message
  2. Processes with character LLM
  3. Generates character response
  4. Returns both user message + character response

MessageList component:
  1. Listens to ChatContext
  2. Re-renders with new messages
  3. Auto-scrolls to bottom
  4. Displays typing indicator while waiting for character response
  5. Typing indicator removes when response arrives
  6. New message animates in
```

### Flow 2: User Creates a New Character

```javascript
// User clicks "Create Character"
ChatLayout.jsx:
  1. User sees "New Character" button
  2. Clicks it
  3. Calls: const { openModal } = useModal('character-creator')
  4. openModal()

UIContext (Modal Manager):
  1. Adds CharacterCreatorModal to modalStack
  2. Modal fades in with logo reveal animation
  3. Form fields appear

CharacterCreatorModal.jsx:
  1. User fills in character details
  2. LivePreviewPanel on right updates in real-time
  3. Form validation on blur/change
  4. User clicks "Create Character"
  5. Submits form data to: const { createCharacter } = useCharacters()
  6. createCharacter(characterData)

useCharacters() hook:
  1. Validates character data
  2. Calls: const response = await characterAPI.createCharacter(data)
  3. On success:
     - Dispatches ADD_CHARACTER to CharacterContext
     - New character appears in sidebar
     - Closes modal with fade-out animation
     - Sets as active character
     - Starts new conversation with character
  4. On error:
     - Shows error message in form
     - Keeps modal open for retry

CharacterContext:
  1. Adds new character to characters array
  2. Sets as activeCharacterId
  3. Notifies all components subscribing to CharacterContext

ChatContext:
  1. Creates new conversation with character
  2. Updates activeConversationId
  3. MessageList clears and waits for first message

ConversationList:
  1. New conversation appears at top
  2. Is automatically selected

User can now chat with new character
```

### Flow 3: User Analyzes Relationship Data

```javascript
// User navigates to RelationshipX
ChatLayout.jsx:
  1. User clicks "RelationshipX" in sidebar
  2. Navigation triggers: navigate('/relationship-analysis')
  3. Portal transition animation plays
  4. RelationshipXPage loads

RelationshipXPage.jsx:
  1. Shows upload options (Paste | File | Screenshot)
  2. User chooses method and provides data
  3. Calls: const { uploadFile, analyzeData } = useRelationshipAnalysis()
  4. uploadFile(fileData, method)

useRelationshipAnalysis() hook:
  1. Validates file/data
  2. Calls: await relationshipAPI.uploadAndAnalyze(data, method)
  3. Sets uploadProgress as file uploads
  4. On success: Triggers analyzeData()
  5. Sets isAnalyzing = true

RelationshipContext (updates):
  1. Stores uploaded file info
  2. Shows processing indicator
  3. Displays: "Analyzing sentiment... Analyzing communication patterns..."

Backend ML Pipeline:
  1. Receives data from frontend
  2. Pre-processes text (cleaning, tokenization)
  3. Runs sentiment classifier → sentiment metrics
  4. Runs topic clustering → communication patterns
  5. Runs toxicity detector → toxicity score
  6. Runs emotional analyzer → engagement metrics
  7. Runs conflict detector → conflict patterns
  8. Aggregates all metrics into AnalysisResults
  9. Returns results to frontend

Frontend (Results Display):
  1. RelationshipXPage receives results
  2. Populates MetricsExplorer with metric cards
  3. Each card shows: title, score, brief description
  4. Cards have [Expand] button

Interactive Exploration:
  1. User clicks expand on "Sentiment" card
  2. Expands to show:
     - Overall sentiment score with visualization
     - Sentiment trend over time (line chart)
     - Per-person sentiment breakdown
     - Top emotional words identified
  3. User clicks another card
     - First collapses, new one expands
  4. User can export results as PDF

RelationshipContext (closure):
  1. Stores results in analysisResults
  2. Can navigate away, come back later
  3. Results persist until user uploads new data or clears
```

---

## MODAL SYSTEM

### Modal Manager Architecture

```javascript
// UIContext manages modal stack
{
  modalStack: [
    {
      id: 'char-creator-1',
      type: 'character-creator',
      isOpen: true,
      position: 0,
      data: { editingCharacterId?: null }
    }
  ]
}

// Modal actions
OPEN_MODAL: { type, data }
CLOSE_MODAL: { id }
CLOSE_ALL_MODALS
UPDATE_MODAL_DATA: { id, data }
```

### Logo Reveal Animation

**File**: `/src/styles/modals.scss`

```scss
@keyframes logoReveal {
  0% {
    opacity: 0;
    transform: scale(0.5) rotate(-180deg);
    filter: blur(20px);
  }
  50% {
    opacity: 1;
    transform: scale(1.2) rotate(0deg);
    filter: blur(0);
  }
  100% {
    opacity: 0;
    transform: translateY(-100px) scale(0.8);
    filter: blur(10px);
  }
}

@keyframes modalFadeIn {
  0% {
    opacity: 0;
    backdrop-filter: blur(0px);
  }
  100% {
    opacity: 1;
    backdrop-filter: blur(8px);
  }
}

.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2500;
  animation: modalFadeIn 400ms ease-out forwards;
}

.modal-logo-reveal {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 120px;
  height: 120px;
  animation: logoReveal 1200ms ease-out forwards;

  // Company logo goes here
  background: url('/logo.svg') center/contain no-repeat;
}

.modal-content {
  position: relative;
  background: rgba(6, 18, 45, 0.95);
  border: 1px solid rgba(6, 182, 212, 0.2);
  border-radius: 16px;
  padding: 2.5rem;
  max-width: 1000px;
  width: 90%;
  max-height: 90vh;
  overflow-y: auto;
  animation: modalFadeIn 500ms ease-out 200ms both;
}
```

**Timeline**:
- 0ms: Modal overlay fades in
- 0ms: Logo appears, scales up, rotates
- 600ms: Logo reaches peak visibility
- 800ms: Logo fades and moves up
- 1200ms: Logo animation complete
- 200ms: Modal content starts fading in (delayed)
- 700ms: Modal content fully visible

### Modal Lifecycle

```javascript
// Open modal
useModal('character-creator').openModal({ editingId?: null })
  → UIContext: OPEN_MODAL
  → Modal added to modalStack
  → Modal component renders with animations
  → User sees logo reveal + content fade

// Update data (preserve open state)
modal.updateData({ formStep: 2 })
  → UIContext: UPDATE_MODAL_DATA
  → Modal content updates, stays open
  → No animation replay

// Close modal
modal.closeModal()
  → UIContext: CLOSE_MODAL
  → Modal animations reversed (fade out)
  → Modal removed from stack
  → Returns focus to previous element

// Close all modals
useModal().closeAllModals()
  → UIContext: CLOSE_ALL_MODALS
  → All modals animate out
  → Stack cleared
```

---

## SIDEBAR ARCHITECTURE

### Sidebar States

**Desktop (≥1024px)**:
- Always visible on left
- Width: 280px (can be collapsed to 80px icon-only)
- Not overlaying chat area
- No hamburger menu

**Tablet (768px - 1023px)**:
- Collapsible
- Default collapsed (hamburger visible)
- When open: slides in from left, 280px width
- Slightly overlays chat area (z-index: 1000)
- Can swipe to dismiss

**Mobile (<768px)**:
- Hidden by default
- Hamburger menu in top-left
- When open: Full-screen drawer
- Slides from left edge
- Has close button at top
- Swipe right to close

### Sidebar Component Structure

```javascript
// Sidebar.jsx
<aside className={`sidebar ${isOpen ? 'open' : 'closed'}`}>

  {/* Header with logo and menu toggle */}
  <SidebarHeader>
    <Logo />
    <MenuButton onClick={onToggle} />
  </SidebarHeader>

  {/* Search conversations */}
  <SearchBox
    placeholder="Search conversations..."
    onSearch={handleSearch}
  />

  {/* Character selector dropdown */}
  <CharacterSelector>
    <RecentCharacters />
    <CharacterDropdown />
  </CharacterSelector>

  {/* Conversations list (virtualized) */}
  <ConversationList
    conversations={conversations}
    activeConversationId={activeId}
    onSelect={selectConversation}
  />

  {/* New character button */}
  <NewCharacterButton onClick={openCharacterCreator} />

  {/* RelationshipX button */}
  <RelationshipXButton onClick={navigateToAnalysis} />

  {/* Footer with user profile and settings */}
  <SidebarFooter>
    <UserProfile />
    <SettingsButton />
    <LogoutButton />
  </SidebarFooter>

</aside>
```

### Responsive Behavior

```javascript
// useSidebar hook determines behavior
const { isMobile, isTablet, isDesktop } = useResponsive()

if (isDesktop) {
  // Sidebar always visible, collapsible to icons
  sidebarWidth = collapsed ? 80 : 280
  zIndex = 1000
  overlay = false
}

if (isTablet) {
  // Sidebar collapses to hamburger
  sidebarWidth = isOpen ? 280 : 0
  zIndex = 1100
  overlay = true (partial)
  position = 'fixed'
}

if (isMobile) {
  // Full-screen drawer
  sidebarWidth = isOpen ? 100vw : 0
  zIndex = 1200
  overlay = true (full)
  position = 'fixed'
  animation = slideInFromLeft
}
```

### Conversations List Virtualization

```javascript
// ConversationList uses react-window
<FixedSizeList
  height={remainingHeight}
  itemCount={conversations.length}
  itemSize={70}
  width="100%"
>
  {ConversationRow}
</FixedSizeList>

// Each row is 70px tall
// Only visible rows are rendered (can handle 10k+ conversations)
```

---

## RELATIONSHIPX DEEP-DIVE

### Upload Methods

**Method 1: Paste Text**
```javascript
// User pastes conversation text
// Format: Any readable text format
// Frontend: Validates text length (min 100 chars, max 1MB)
// Backend: Receives raw text, pre-processes
// Processing: Tokenizes, removes noise, formats for analysis

Example format:
```
Person A: Hey, how was your day?
Person B: Pretty good, just tired from work
Person A: I understand, let's relax tonight
...
```

**Method 2: File Upload**
```javascript
// User uploads SMS/iMessage export file
// Supported formats: .csv, .json, .txt, .sqlite (iOS)
// Frontend: Detects format, parses data
// Backend: Normalizes to standard format
// Processing: Extracts messages, timestamps, participants

CSV Format:
```
timestamp,sender,message
2024-01-01T10:30:00Z,Alice,Hey there!
2024-01-01T10:35:00Z,Bob,Hi! What's up?
...
```

**Method 3: Screenshot with OCR**
```javascript
// User uploads screenshot image
// Frontend: Sends to OCR service (backend or third-party)
// OCR: Extracts text from image
// Backend: Processes extracted text like paste method
// Fallback: If OCR fails, shows error with option to paste text manually
```

### ML Pipeline Architecture

```
Frontend: Upload file/text
    ↓
Backend receives data
    ↓
Pre-processing:
  - Text cleaning (remove special characters, extra whitespace)
  - Tokenization (split into words/sentences)
  - Participant identification (who's Person A/B?)
  - Timestamp normalization
  ↓
Sentiment Analysis:
  - Classifier model: DistilBERT fine-tuned on conversation data
  - Per-message sentiment: [-1 (negative) to +1 (positive)]
  - Aggregate statistics: Overall, per-person, over time
  ↓
Communication Patterns:
  - Message frequency analysis
  - Response time calculation (time between person A→B messages)
  - Topic extraction (clustering similar conversations)
  - Conversation turn-taking analysis
  ↓
Emotional Engagement:
  - Vulnerability detection (personal sharing, emotional openness)
  - Depth scoring (conversation substance, not just small talk)
  - Attachment analysis (frequency, consistency, patterns)
  ↓
Toxicity Detection:
  - Toxicity classifier: trained on toxic comment data
  - Flags: insults, threats, sarcasm detection
  - Severity scoring (0-1)
  ↓
Conflict Metrics:
  - Conflict event detection (argument, disagreement)
  - Resolution analysis (how conflicts are resolved)
  - Trigger identification (what causes conflicts)
  - Escalation patterns
  ↓
Results Aggregation:
  - Combine all metrics into single AnalysisResults object
  - Generate insights and recommendations
  - Create visualizations (data preparation)
  ↓
Return results to frontend
```

### Metrics Schema

```javascript
{
  sentiment: {
    overall: 0.72,  // Average sentiment score
    trend: [0.5, 0.6, 0.7, 0.75, 0.72],  // Over time
    byPerson: [
      { name: 'Person A', score: 0.8 },
      { name: 'Person B', score: 0.65 }
    ],
    topWords: ['love', 'happy', 'excited']
  },

  communicationPatterns: {
    messageCount: 2847,
    averageResponseTime: 180,  // seconds
    messageFrequency: 'daily',
    topicClusters: ['work', 'plans', 'feelings', 'relationships'],
    conversationStarters: {
      personA: 'Hey',
      personB: 'How was...'
    }
  },

  emotionalEngagement: {
    score: 0.78,
    depth: 'high',
    vulnerabilityIndex: 0.65,
    attachmentLevel: 'strong',
    sharedInterests: ['movies', 'travel', 'cooking']
  },

  conflictMetrics: {
    conflictCount: 12,
    conflictInstances: [
      {
        date: '2024-01-15',
        topic: 'Plans',
        severity: 0.6,
        resolution: 'positive'
      }
    ],
    resolutionRate: 0.83,
    commonTriggers: ['misunderstanding', 'timing', 'expectations'],
    escalationPatterns: 'quick-resolution'
  },

  toxicity: 0.05,  // Overall toxicity score
  positivityIndex: 0.72
}
```

### Interactive Metrics Explorer UI

```javascript
// Each metric is a card that can expand
<MetricCard metric="sentiment">
  <MetricHeader>
    <Title>Sentiment Analysis</Title>
    <Score>7.2/10</Score>
    <ExpandButton />
  </MetricHeader>

  {/* Hidden until expanded */}
  <MetricDetails>
    <StatBlock label="Overall Sentiment" value={0.72} />
    <Chart type="line" data={sentimentTrend} />
    <SubMetric>
      <PersonLabel>Person A</PersonLabel>
      <PersonScore>8.0</PersonScore>
    </SubMetric>
    <SubMetric>
      <PersonLabel>Person B</PersonLabel>
      <PersonScore>6.5</PersonScore>
    </SubMetric>
    <InsightsList>
      <Insight>Most positive topics: {topWords}</Insight>
      <Insight>Sentiment has been improving over time</Insight>
    </InsightsList>
  </MetricDetails>
</MetricCard>
```

---

## ANIMATIONS & UX

### Portal Transition (Already Implemented)
- **Duration**: 800ms
- **Components**: Gradient sweep, page fade, content zoom
- **Timing**: Sequential, overlapping stages
- **Used for**: Navigation between Index ↔ Chat ↔ RelationshipX

### Logo Reveal Animation (Character Creator Modal)
- **Duration**: 1200ms total
- **Sequence**:
  - 0-600ms: Logo scales in and rotates
  - 600-1200ms: Logo fades out and moves upward
  - 200ms delay before modal content fades in
- **Easing**: `cubic-bezier(0.34, 1.56, 0.64, 1)` (bounce effect)
- **Effect**: Premium, attention-grabbing, branded

### Sidebar Animations
- **Collapse/Expand**: 300ms ease-out
- **Mobile Slide-In**: 400ms cubic-bezier(0.4, 0, 0.2, 1)
- **Conversation Highlight**: Subtle background color change, 200ms

### Message Animations
- **Message Arrival**: Fade-in + slide-up 300ms ease-out
- **Typing Indicator**: Pulsing dots animation, 800ms loop
- **Message Delete**: Slide-out + fade-out 200ms

### Metric Card Animations
- **Expand**: Height transition 300ms, content fade-in
- **Collapse**: Reverse animation, 250ms

### Form Field Animations
- **Error State**: Shake animation 400ms (0 10px 0px -10px 0px)
- **Success**: Green check mark with scale-up animation, 400ms
- **Focus**: Subtle glow animation, smooth transitions

---

## RESPONSIVE DESIGN

### Breakpoints

**Mobile**: 320px - 767px
**Tablet**: 768px - 1023px
**Desktop**: 1024px+

### Component Adjustments by Breakpoint

**Chat Layout**:
```
Mobile:
  - Sidebar: Hidden, hamburger menu
  - Messages: Full width, larger text
  - Input: Full width with send button below

Tablet:
  - Sidebar: 200px, collapsible
  - Messages: Remaining width
  - Input: Horizontal layout preserved

Desktop:
  - Sidebar: 280px, always visible (can collapse to icons)
  - Messages: Remaining width
  - Input: Horizontal optimized layout
```

**Message List**:
```
Mobile:
  - Font size: 16px (avoid zoom on input)
  - Padding: 12px
  - Avatar size: 32px

Tablet:
  - Font size: 15px
  - Padding: 16px
  - Avatar size: 40px

Desktop:
  - Font size: 14px
  - Padding: 20px
  - Avatar size: 48px
```

**Character Creator Modal**:
```
Mobile:
  - Split-screen → Stacked vertically
  - Form on top, preview below (scrollable)
  - Full viewport height
  - Tabs instead of side-by-side

Tablet:
  - Form: 60% width, Preview: 40% width
  - Side-by-side with scroll

Desktop:
  - Form: 50%, Preview: 50%
  - Perfect split-screen
```

### Touch Interactions

**Mobile**:
- Swipe right on sidebar to close
- Swipe left on conversation to delete/archive options
- Tap character avatar to see character info
- Long-press message for context menu
- Pull-to-refresh on conversation list

**Tablet**:
- Hover states for desktop mouse users
- Touch-friendly target sizes (min 44px × 44px)

---

## ERROR HANDLING

### Error Boundaries

```javascript
// Root-level error boundary
<ErrorBoundary>
  <App />
</ErrorBoundary>

// Page-level error boundaries
<ChatPage>
  <ErrorBoundary>
    <ChatLayout />
  </ErrorBoundary>
</ChatPage>

// Component-level error boundaries
<ErrorBoundary onError={logError}>
  <MessageList />
</ErrorBoundary>
```

### API Error Handling

```javascript
// chatAPI calls wrapped in try-catch
try {
  const message = await chatAPI.sendMessage(...)
} catch (error) {
  if (error.response?.status === 401) {
    // Unauthorized → redirect to login
    authContext.logout()
    navigate('/login')
  } else if (error.response?.status === 429) {
    // Rate limited → show user-friendly message
    showNotification('Too many messages, please wait...', 'error')
  } else if (error.code === 'NETWORK_ERROR') {
    // Network error → show retry option
    showNotification('Network error, click to retry', 'error', () => {
      sendMessage(content)
    })
  } else {
    // Generic error
    showNotification('Failed to send message', 'error')
  }
}
```

### Skeleton Loaders

```javascript
// While messages load
<MessageList>
  {messages.length === 0 && isLoading && (
    <>
      <SkeletonMessage />
      <SkeletonMessage />
      <SkeletonMessage />
    </>
  )}
</MessageList>

// While characters load
<ConversationList>
  {isLoading && (
    <>
      <SkeletonConversation />
      <SkeletonConversation />
    </>
  )}
</ConversationList>
```

### User-Friendly Messages

```
Network Error: "Connection lost. Retrying..."
Timeout: "Taking longer than expected. Still trying..."
Auth Failed: "Session expired. Please log in again."
Rate Limited: "Too many requests. Please wait..."
File Too Large: "File exceeds 10MB limit. Please try a smaller file."
Invalid Character: "Please fill out all required fields."
```

---

## FILE STRUCTURE

```
/src
├── /components
│   ├── /chat
│   │   ├── ChatLayout.jsx
│   │   ├── Sidebar.jsx
│   │   ├── SidebarHeader.jsx
│   │   ├── ConversationList.jsx
│   │   ├── ConversationItem.jsx
│   │   ├── CharacterSelector.jsx
│   │   ├── ChatArea.jsx
│   │   ├── ChatHeader.jsx
│   │   ├── MessageList.jsx
│   │   ├── Message.jsx
│   │   ├── TypingIndicator.jsx
│   │   ├── InputArea.jsx
│   │   └── MessageInput.jsx
│   │
│   ├── /modals
│   │   ├── CharacterCreatorModal.jsx
│   │   ├── CharacterCreatorForm.jsx
│   │   ├── CharacterPreviewPanel.jsx
│   │   ├── ConfirmDeleteModal.jsx
│   │   ├── SettingsModal.jsx
│   │   └── ModalContainer.jsx
│   │
│   ├── /relationship
│   │   ├── RelationshipXPage.jsx
│   │   ├── UploadSection.jsx
│   │   ├── UploadTabs.jsx
│   │   ├── FileDropZone.jsx
│   │   ├── ResultsSection.jsx
│   │   ├── MetricsExplorer.jsx
│   │   ├── MetricCard.jsx
│   │   └── AnalysisProgress.jsx
│   │
│   ├── /common
│   │   ├── Button.jsx
│   │   ├── Input.jsx
│   │   ├── Modal.jsx
│   │   ├── Card.jsx
│   │   ├── ErrorBoundary.jsx
│   │   ├── Notification.jsx
│   │   ├── Skeleton.jsx
│   │   └── LoadingSpinner.jsx
│   │
│   ├── TransitionWrapper.jsx
│   └── IndexPage.jsx
│
├── /contexts
│   ├── AuthContext.jsx
│   ├── ChatContext.jsx
│   ├── CharacterContext.jsx
│   ├── UIContext.jsx
│   ├── RelationshipContext.jsx
│   └── PageTransitionContext.jsx
│
├── /hooks
│   ├── useChat.js
│   ├── useCharacters.js
│   ├── useModal.js
│   ├── useRelationshipAnalysis.js
│   ├── useSidebar.js
│   ├── useNotification.js
│   ├── useVirtualization.js
│   ├── useDebounce.js
│   └── useResponsive.js
│
├── /services
│   ├── client.js (Axios instance)
│   ├── chatAPI.js
│   ├── characterAPI.js
│   ├── relationshipAPI.js
│   ├── authAPI.js
│   └── fileUploadService.js
│
├── /pages
│   ├── IndexPage.jsx
│   ├── IndexPage.scss
│   ├── ChatPage.jsx
│   ├── ChatPage.scss
│   └── RelationshipXPage.jsx
│
├── /styles
│   ├── variables.scss
│   ├── glassmorphism.scss
│   ├── global.scss
│   ├── animations.scss
│   └── modals.scss
│
├── App.jsx
└── main.jsx
```

---

## IMPLEMENTATION PHASES

### Phase 1: API Layer & Context Providers (Week 1)

**Deliverables**:
- Axios client with interceptors
- All API service modules (chatAPI, characterAPI, relationshipAPI, authAPI)
- All Context providers (Auth, Chat, Character, UI, Relationship)
- useChat, useCharacters, useModal, useRelationshipAnalysis hooks

**Testing**:
- Mock API responses
- Test context providers with dummy data
- Verify hook return types

**Duration**: 3-4 days

---

### Phase 2: Chat Interface Skeleton (Week 1-2)

**Deliverables**:
- ChatLayout container component
- Sidebar with ConversationList (static, no virtualization yet)
- ChatArea with MessageList (static messages)
- InputArea with message input
- Basic responsive design

**No styling yet - focus on structure and data flow**

**Testing**:
- Verify context consumption
- Check message rendering
- Test responsive behavior

**Duration**: 3-4 days

---

### Phase 3: Character Creation Modal (Week 2)

**Deliverables**:
- CharacterCreatorModal with split-screen layout
- CharacterCreatorForm with validation
- CharacterPreviewPanel (live preview)
- Logo reveal animation
- Form submission to API

**Testing**:
- Verify form validation
- Test logo animation timing
- Check API integration
- Verify modal lifecycle

**Duration**: 2-3 days

---

### Phase 4: Sidebar & Navigation (Week 2-3)

**Deliverables**:
- Full Sidebar with all components
- ConversationList virtualization (react-window)
- Mobile responsive (hamburger menu)
- Tablet responsive (collapsible)
- Character selector with switcher
- New Character button integration

**Testing**:
- Verify virtualization with 1000+ conversations
- Test responsive behavior at all breakpoints
- Check animations and transitions

**Duration**: 3 days

---

### Phase 5: RelationshipX UI & Upload (Week 3-4)

**Deliverables**:
- RelationshipXPage route
- Upload section with 3 methods (paste, file, screenshot)
- File upload with progress indication
- Results display with MetricsExplorer
- Expandable MetricCards
- Export functionality

**Note**: Backend ML pipeline not included yet (will be in Phase 6)

**Testing**:
- Test file upload handling (various formats)
- Verify metrics display
- Test card expand/collapse
- Check error states

**Duration**: 3-4 days

---

### Phase 6: Backend ML Pipeline & Integration (Week 4-5)

**Deliverables**:
- Text pre-processing pipeline
- Sentiment analysis model
- Communication patterns analysis
- Emotional engagement analysis
- Toxicity detection
- Conflict metrics analysis
- Results aggregation
- Progress tracking API

**Backend endpoints**:
- POST `/api/relationship/analyze` - Upload and analyze
- GET `/api/relationship/progress/:id` - Check progress
- GET `/api/relationship/results/:id` - Get results
- POST `/api/relationship/ocr` - Process screenshots

**Testing**:
- Unit tests for each ML component
- Integration tests for pipeline
- Performance tests (large file uploads)
- Accuracy tests on known datasets

**Duration**: 5-7 days

---

### Phase 7: Polish, Animation, & Testing (Week 5-6)

**Deliverables**:
- All CSS/SCSS styling (premium glassmorphic design)
- All animations (portal, modal logo reveal, sidebar, messages)
- Skeleton loaders
- Error states and recovery flows
- Loading states throughout
- Notification system
- Comprehensive error handling

**Testing**:
- E2E tests for critical flows
- Visual regression testing
- Performance profiling
- Mobile testing across devices
- Accessibility audit
- Browser compatibility

**Duration**: 4-5 days

---

## TECHNICAL DECISIONS

### Why Context API Instead of Redux

**Decision**: Use React Context API with useReducer

**Rationale**:
- ✅ 5 separate contexts = good separation of concerns
- ✅ No extra dependencies (Redux requires redux, react-redux, middleware)
- ✅ Easier to understand and debug
- ✅ Built-in to React, no learning curve
- ✅ Sufficient for this app's complexity
- ❌ Not suitable for global state accessed every render (not a problem here)

**Alternative Considered**: Redux Toolkit
- ✅ Better for very large apps (100+ components)
- ✅ Better dev tools and middleware ecosystem
- ❌ Overkill for this use case
- ❌ Extra boilerplate
- ❌ More dependencies

---

### Why Split-Screen Modal for Character Creation

**Decision**: Immersive split-screen UI instead of linear form

**Rationale**:
- ✅ User sees preview update in real-time (engaging)
- ✅ Reduces "dead space" with previews in separate section
- ✅ More sophisticated and premium feel
- ✅ Allows side-by-side comparison of form vs preview
- ✅ Non-linear creation (jump between sections)
- ❌ Requires more screen space (handled with stacking on mobile)
- ❌ More complex component structure

**Alternative Considered**: Multi-step wizard
- ✅ Guides user step-by-step
- ✅ Simpler implementation
- ❌ Feels more basic/less premium
- ❌ Preview happens only at end
- ❌ More clicks to complete

---

### Why Interactive Metrics Explorer for RelationshipX

**Decision**: Expandable metric cards instead of dashboard or feed

**Rationale**:
- ✅ User controls what they want to explore
- ✅ Cleaner initial view (not overwhelming)
- ✅ Progressive disclosure (more details on demand)
- ✅ Allows deep-diving into specific metrics
- ✅ Works well on mobile (stacking naturally)
- ❌ Slightly more interaction required

**Alternative Considered**: Full Analytics Dashboard
- ✅ All data visible at once
- ❌ Overwhelming with too much information
- ❌ Poor mobile experience
- ❌ Feels like spreadsheet, not insights

---

### Why Virtual Scrolling for Large Lists

**Decision**: React-window for ConversationList and MessageList

**Rationale**:
- ✅ Handles 10k+ messages without performance issues
- ✅ Constant memory usage regardless of list size
- ✅ Smooth scrolling even on low-end devices
- ✅ Only renders visible items
- ❌ Slightly more complex implementation

---

## CONCLUSION

This architecture is **production-grade, systematically designed, and ready for implementation**.

Key principles:
- ✅ **No shortcuts** - Every pattern is battle-tested
- ✅ **Systematic** - Clear rationale for every decision
- ✅ **Scalable** - Handles growth from day 1
- ✅ **Maintainable** - Easy for future developers
- ✅ **Testable** - Built for comprehensive testing
- ✅ **Premium** - Sophisticated UX throughout

Follow the implementation phases in order. Each phase is self-contained and can be tested independently. No improvisation needed - this blueprint covers every aspect.

**Ready to build Phase 1!**
