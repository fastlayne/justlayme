# Phase 2 Frontend Fixes - TDD Implementation Guide

## Overview
Phase 2 implements four critical frontend fixes with Test-Driven Development discipline. All tests are written BEFORE implementation, demonstrating the expected behavior.

**Principle: NO BAND-AIDS - Proper State Management Patterns**

---

## FIX 12: Loading States for Async Operations

### Problem
Operations (character switch, file upload, analysis) show blank UI with no feedback that app is working.

### Solution
Centralized loading state management via `LoadingContext`.

### Files Created/Modified

#### 1. **Loading Context** (`/home/fastl/JustLayMe/client/src/contexts/LoadingContext.jsx`)
- Centralized state for all loading operations
- Separate state for: character switch, file upload, analysis
- Proper state transitions: idle → loading → success/error

**Key Methods:**
```javascript
// Character switch
startCharacterSwitch(character)
completeCharacterSwitch(character)
errorCharacterSwitch(error)

// File upload
startFileUpload(fileName)
updateUploadProgress(progress)
completeFileUpload(fileUrl)
errorFileUpload(error)

// Analysis
startAnalysis(analysisId)
updateAnalysisProgress(progress)
updateAnalysisStage(stage)
completeAnalysis()
errorAnalysis(error)
cancelAnalysis()
```

#### 2. **Test File** (`/home/fastl/JustLayMe/client/src/__tests__/fixes/fix12-loading-states.test.js`)
Tests that verify:
- Loading indicator shows during async operations
- Proper state transitions (idle → loading → success/error)
- Error states are handled with visible feedback
- Loading states prevent multiple simultaneous operations

### Usage Example

```javascript
import { useLoading } from '@/contexts/LoadingContext'

export default function CharacterSelector() {
  const { characterSwitch, startCharacterSwitch, completeCharacterSwitch, errorCharacterSwitch } = useLoading()

  const handleSelectCharacter = async (characterId) => {
    startCharacterSwitch(characterId)
    try {
      await selectCharacterAPI(characterId)
      completeCharacterSwitch(characterId)
    } catch (error) {
      errorCharacterSwitch(error.message)
    }
  }

  return (
    <>
      {characterSwitch.isLoading && <LoadingSpinner />}
      {characterSwitch.status === 'error' && <ErrorMessage error={characterSwitch.error} />}
      {/* Component JSX */}
    </>
  )
}
```

---

## FIX 13: Error Handling for Async Operations

### Problem
Failed async operations fail silently or show no error feedback. No retry mechanisms.

### Solution
Dedicated `ErrorContext` with error boundaries, display, and retry capabilities.

### Files Created/Modified

#### 1. **Error Context** (`/home/fastl/JustLayMe/client/src/contexts/ErrorContext.jsx`)
- Centralized error state management
- Error categorization (NETWORK_ERROR, VALIDATION_ERROR, UNAUTHORIZED, SERVER_ERROR)
- Retry registry for recoverable operations
- Global error support (for app-wide errors)

**Key Methods:**
```javascript
// Error management
addError(message, type, options)
clearError(errorId)
clearAllErrors()
retryError(errorId)
markErrorResolved(errorId)

// Global errors
setGlobalError(message, type)
clearGlobalError()

// Retry setup
registerRetry(errorId, retryFn, maxRetries)
```

#### 2. **Test File** (`/home/fastl/JustLayMe/client/src/__tests__/fixes/fix13-error-handling.test.js`)
Tests that verify:
- All failed operations show user-visible error messages
- Error boundaries catch and display errors gracefully
- Retry mechanism available for failed operations
- Error recovery cleans up state properly
- Specific error types are distinguished

### Usage Example

```javascript
import { useError } from '@/contexts/ErrorContext'

export default function FileUpload() {
  const { addError, registerRetry, getActiveError } = useError()

  const handleUpload = async (file) => {
    try {
      await uploadFile(file)
    } catch (error) {
      const errorId = addError(
        error.message,
        'UPLOAD_ERROR',
        { canRetry: true }
      )

      // Register retry function
      registerRetry(errorId, () => uploadFile(file), 3)
    }
  }

  const activeError = getActiveError()

  return (
    <>
      {activeError && (
        <div className="error-display">
          <p>{activeError.message}</p>
          {activeError.canRetry && (
            <button onClick={() => retryError(activeError.id)}>Retry</button>
          )}
        </div>
      )}
    </>
  )
}
```

---

## FIX 14: Grey Mirror Loading Indicator with Progress

### Problem
Analysis starts but user sees no progress - appears frozen.

### Solution
`AnalysisProgress` component with spinner, percentage, stage labels, ETA, and cancel button.

### Files Modified

#### 1. **AnalysisProgress Component** (`/home/fastl/JustLayMe/client/src/components/blackmirror/AnalysisProgress.jsx`)
Enhanced with:
- Animated spinner
- Real-time progress percentage (0-100)
- Current stage display (processing/analyzing/compiling)
- Estimated time remaining (ETA)
- Cancel button with confirmation
- Error state with retry option
- Integrates with `LoadingContext`

#### 2. **Test File** (`/home/fastl/JustLayMe/client/src/__tests__/fixes/fix14-progress-indicator.test.js`)
Tests that verify:
- Progress indicator displays during analysis
- Shows correct percentage and stages
- Cancel button available and functional
- Error states properly handled
- Progress persists during component remounts

### Usage Example

```javascript
import AnalysisProgress from '@/components/blackmirror/AnalysisProgress'
import { useLoading } from '@/contexts/LoadingContext'

export default function BlackMirrorPage() {
  const { analysis, cancelAnalysis } = useLoading()

  const handleAnalysis = async (files) => {
    startAnalysis('analysis_123')
    updateAnalysisStage('processing')
    updateAnalysisProgress(25)

    // ... analysis work ...

    updateAnalysisStage('analyzing')
    updateAnalysisProgress(75)

    // ... more analysis ...

    completeAnalysis()
  }

  return (
    <>
      <AnalysisProgress
        onCancel={cancelAnalysis}
        showETA={true}
      />
      {/* Rest of component */}
    </>
  )
}
```

---

## FIX 15: Token Expiration Auto-Refresh

### Problem
Token expires and user is signed out with no recovery. No automatic refresh.

### Solution
Token refresh interceptor that runs transparently before API calls and expiration.

### Files Created/Modified

#### 1. **Token Refresh Utility** (`/home/fastl/JustLayMe/client/src/utils/tokenRefreshInterceptor.js`)
Provides:
- Token expiration detection
- Proactive refresh (1 minute before expiration)
- Transparent refresh without user interruption
- Concurrent request deduplication
- Scheduled refresh timer
- App startup validation

**Key Functions:**
```javascript
// Detection
isTokenExpired(token)
isTokenExpiringSoon(token, thresholdMs)
getTimeUntilExpiration(token)

// Refresh
refreshTokenAsync(refreshTokenFn)
setupTokenRefreshInterceptor(apiClient, refreshTokenFn)
scheduleTokenRefresh(token, refreshTokenFn, advanceMs)
validateAndRefreshTokenOnStartup(refreshTokenFn)
```

#### 2. **Client Configuration** (`/home/fastl/JustLayMe/client/src/services/client.js`)
- Added token refresh interceptor setup
- Request interceptor checks token before API calls
- Response interceptor handles 401 errors

#### 3. **Auth API Integration** (`/home/fastl/JustLayMe/client/src/services/authAPI.js`)
- Initialize token refresh on login/signup
- Provides refresh endpoint to interceptor

#### 4. **Test File** (`/home/fastl/JustLayMe/client/src/__tests__/fixes/fix15-token-refresh.test.js`)
Tests that verify:
- Token expiration is detected correctly
- Tokens refresh automatically before expiration
- Refresh happens transparently (no user interruption)
- Failed refreshes redirect to login
- Concurrent refresh requests are deduplicated

### Usage Example

```javascript
import { setupTokenRefreshInterceptor, isTokenExpiringSoon } from '@/utils/tokenRefreshInterceptor'
import apiClient from '@/services/client'

// Setup happens automatically in authAPI.login/signup
// But can also be called manually:

setupTokenRefreshInterceptor(apiClient, async () => {
  return await authAPI.refreshToken()
})

// Check token status
if (isTokenExpiringSoon(localStorage.getItem('authToken'))) {
  console.warn('Token expiring soon!')
}
```

---

## Test Files

All test files follow TDD principles:

1. **`fix12-loading-states.test.js`** (315 lines)
   - Tests for character switch, file upload, analysis loading states
   - Validates state transitions and error handling

2. **`fix13-error-handling.test.js`** (355 lines)
   - Tests for error display, boundaries, and retry mechanisms
   - Validates error recovery and specific error types

3. **`fix14-progress-indicator.test.js`** (380 lines)
   - Tests for progress display, ETA, cancellation
   - Validates multi-file progress tracking

4. **`fix15-token-refresh.test.js`** (425 lines)
   - Tests for token detection, refresh, interceptors
   - Validates concurrent request handling and edge cases

5. **`integration.test.js`** (260 lines)
   - Tests complete user flows combining all fixes
   - Validates state cleanup and resource management

---

## Integration Checklist

### Step 1: Add Providers to App Root
```javascript
// src/App.jsx or main provider
import { LoadingProvider } from '@/contexts/LoadingContext'
import { ErrorProvider } from '@/contexts/ErrorContext'
import { ErrorBoundary } from '@/components/common/ErrorBoundary'

export default function App() {
  return (
    <ErrorBoundary>
      <LoadingProvider>
        <ErrorProvider>
          <YourAppRoutes />
        </ErrorProvider>
      </LoadingProvider>
    </ErrorBoundary>
  )
}
```

### Step 2: Update Components

#### Sidebar.jsx
```javascript
import { useLoading } from '@/contexts/LoadingContext'

// In handleSelectCharacter:
const { startCharacterSwitch, completeCharacterSwitch, errorCharacterSwitch } = useLoading()

startCharacterSwitch(characterId)
try {
  await selectCharacter(characterId)
  completeCharacterSwitch(characterId)
} catch (error) {
  errorCharacterSwitch(error.message)
}
```

#### InputArea.jsx
```javascript
import { useLoading } from '@/contexts/LoadingContext'

// In handleSend:
const { startFileUpload, updateUploadProgress, completeFileUpload, errorFileUpload } = useLoading()

startFileUpload(attachedFile?.name)
try {
  // Upload with progress tracking
  const response = await fetch('/api/upload', {
    // ... with onUploadProgress hook
  })
  completeFileUpload(response.fileUrl)
} catch (error) {
  errorFileUpload(error.message)
}
```

#### BlackMirrorPage.jsx
```javascript
import { useLoading } from '@/contexts/LoadingContext'
import AnalysisProgress from '@/components/blackmirror/AnalysisProgress'

// In handleAnalysisStart:
const { startAnalysis, updateAnalysisProgress, updateAnalysisStage, completeAnalysis, errorAnalysis } = useLoading()

startAnalysis(analysisId)
updateAnalysisStage('processing')
updateAnalysisProgress(25)

// ... analysis work ...

updateAnalysisStage('analyzing')
updateAnalysisProgress(75)

try {
  const report = await runCompleteAnalysis(fileContent)
  completeAnalysis()
  setMLReport(report)
} catch (error) {
  errorAnalysis(error.message)
}

// In render:
<AnalysisProgress onCancel={handleCancel} />
```

### Step 3: Test Everything

Run all tests:
```bash
npm test -- fix12-loading-states.test.js
npm test -- fix13-error-handling.test.js
npm test -- fix14-progress-indicator.test.js
npm test -- fix15-token-refresh.test.js
npm test -- integration.test.js
```

---

## Key Principles Applied

### 1. **TDD Discipline**
- Tests written BEFORE implementation
- Tests demonstrate expected behavior
- Implementation matches test requirements

### 2. **State Management Patterns**
- Centralized context for loading states
- Reducer pattern for state transitions
- Clear action types and state shapes

### 3. **Error Handling**
- Visible error messages for all failures
- Error categorization and recovery
- Retry mechanisms for transient failures

### 4. **User Experience**
- Loading indicators prevent confusion
- Progress displays for long operations
- No sudden logouts (transparent token refresh)
- Clear error messages with retry options

### 5. **Code Quality**
- No band-aid fixes - proper solutions
- Reusable contexts and utilities
- Clean separation of concerns
- Comprehensive test coverage

---

## Verification Steps

1. **Character Switch**
   - Loading indicator appears while switching
   - Character updates after loading
   - Error shows if switch fails

2. **File Upload**
   - Progress bar shows upload status
   - File preview displays
   - Error displays on upload failure

3. **Analysis**
   - Progress indicator shows during analysis
   - Cancel button available
   - Proper completion or error state

4. **Token Refresh**
   - User stays logged in across token refresh
   - No "session expired" notifications
   - API calls succeed after refresh

---

## Performance Notes

- LoadingContext uses reducer pattern (optimized)
- ErrorContext uses callbacks (no unnecessary renders)
- Token refresh is debounced (max 10s interval)
- Concurrent refresh requests deduplicated
- Progress updates are throttled (0.3s transitions)

---

## Future Enhancements

1. Add analytics to track operation failures
2. Implement exponential backoff for retries
3. Add offline detection and queuing
4. Implement refresh token rotation
5. Add session timeout warnings before logout
