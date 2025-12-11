# Phase 2 Frontend Fixes - Setup Instructions

## Step-by-Step Setup Guide

### Prerequisites
- Node.js 18+
- React 19+
- Existing project structure at `/home/fastl/JustLayMe`

### Installation

All files are already created. No npm packages need to be installed.

**Files to verify exist:**

```bash
ls -la /home/fastl/JustLayMe/client/src/contexts/LoadingContext.jsx
ls -la /home/fastl/JustLayMe/client/src/contexts/ErrorContext.jsx
ls -la /home/fastl/JustLayMe/client/src/utils/tokenRefreshInterceptor.js
ls -la /home/fastl/JustLayMe/client/src/__tests__/fixes/
```

### Integration Guide

#### 1. Update App.jsx (or main provider file)

```javascript
// src/App.jsx or src/providers/AppProviders.jsx

import { LoadingProvider } from '@/contexts/LoadingContext'
import { ErrorProvider } from '@/contexts/ErrorContext'
import { ErrorBoundary } from '@/components/common/ErrorBoundary' // If exists

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

#### 2. Update Sidebar.jsx

Location: `/home/fastl/JustLayMe/client/src/components/chat/Sidebar.jsx`

**Add import at top:**
```javascript
import { useLoading } from '@/contexts/LoadingContext'
import { useError } from '@/contexts/ErrorContext'
```

**Update handleSelectCharacter method (line 75-105):**
```javascript
const handleSelectCharacter = async (characterId) => {
  const { startCharacterSwitch, completeCharacterSwitch, errorCharacterSwitch } = useLoading()
  const { addError } = useError()

  startCharacterSwitch(characterId)
  
  try {
    selectCharacter(characterId)

    const characterConversations = conversations.filter(
      conv => conv.model_type === characterId
    )

    if (characterConversations.length > 0) {
      const mostRecent = characterConversations[0]
      console.log(`[Sidebar] Resuming conversation ${mostRecent.id} with character ${characterId}`)
      setActiveConversation(mostRecent.id)

      try {
        await fetchMessages(mostRecent.id)
      } catch (error) {
        console.error('Failed to load conversation messages:', error)
        addError(error.message, 'MESSAGE_LOAD_ERROR')
      }
    } else {
      console.log(`[Sidebar] No existing conversations for character ${characterId}, creating new one`)
      try {
        await startConversation(characterId)
      } catch (error) {
        console.error('Failed to start conversation:', error)
        addError(error.message, 'CONVERSATION_START_ERROR')
      }
    }
    
    completeCharacterSwitch(characterId)
  } catch (error) {
    console.error('Failed to select character:', error)
    errorCharacterSwitch(error.message)
  }
}
```

#### 3. Update InputArea.jsx

Location: `/home/fastl/JustLayMe/client/src/components/chat/InputArea.jsx`

**Add import at top:**
```javascript
import { useLoading } from '@/contexts/LoadingContext'
import { useError } from '@/contexts/ErrorContext'
```

**Update handleSend method (line 69-157):**
```javascript
const handleSend = async () => {
  const { startFileUpload, updateUploadProgress, completeFileUpload, errorFileUpload } = useLoading()
  const { addError, registerRetry } = useError()

  // Validation
  if (!message.trim() && !attachedFile) {
    notification.warning('Please enter a message or attach a file')
    return
  }

  if (!activeConversationId) {
    notification.error('No conversation selected')
    return
  }

  if (message.trim().length === 0 && !attachedFile) {
    notification.warning('Message cannot be empty')
    return
  }

  setIsSending(true)
  try {
    let fileUrl = null
    
    if (attachedFile) {
      startFileUpload(attachedFile.name)
      
      try {
        const formData = new FormData()
        formData.append('file', attachedFile)
        formData.append('conversationId', activeConversationId)

        const uploadResponse = await fetch('/api/upload', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('authToken')}`
          },
          body: formData
        })

        if (!uploadResponse.ok) {
          const errorData = await uploadResponse.json().catch(() => ({}))
          const errorMessage = errorData.message || `Upload failed with status ${uploadResponse.status}`
          throw new Error(errorMessage)
        }

        const uploadData = await uploadResponse.json()
        fileUrl = uploadData.fileUrl || uploadData.url
        completeFileUpload(fileUrl)
      } catch (error) {
        console.error('File upload failed:', error)
        const errorId = addError(
          error.message || 'File upload failed',
          'UPLOAD_ERROR',
          { canRetry: true }
        )
        registerRetry(errorId, () => {
          // Retry upload
          return fetch('/api/upload', {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${localStorage.getItem('authToken')}` },
            body: new FormData(Object.entries({ file: attachedFile, conversationId: activeConversationId }))
          })
        }, 2)
        errorFileUpload(error.message)
        return
      }
    }

    const characterMetadata = activeCharacter ? {
      character: activeCharacter.id || activeCharacterId,
      characterName: activeCharacter.name,
      isCustomCharacter: activeCharacter.isCustom !== false,
      customCharacterConfig: {
        systemPrompt: activeCharacter.system_prompt || activeCharacter.systemPrompt || activeCharacter.personality,
        personality: activeCharacter.personality,
        description: activeCharacter.description,
        model: activeCharacter.config?.model || 'sushruth/solar-uncensored:latest',
        temperature: parseFloat(activeCharacter.config?.temperature) || 0.85,
        top_p: parseFloat(activeCharacter.config?.top_p) || 0.95,
        max_tokens: parseInt(activeCharacter.config?.max_tokens) || 250,
        repeat_penalty: parseFloat(activeCharacter.config?.repeat_penalty) || 1.1
      }
    } : {}

    await sendMessage(message.trim() || '[Image attachment]', fileUrl, characterMetadata)

    setMessage('')
    setAttachedFile(null)
    setFilePreview(null)
    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }

    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto'
    }
  } catch (error) {
    console.error('Failed to send message:', error)
    const errorMessage = error?.message || 'Failed to send message'
    notification.error(errorMessage)
  } finally {
    setIsSending(false)
  }
}
```

#### 4. Update BlackMirrorPage.jsx

Location: `/home/fastl/JustLayMe/client/src/pages/BlackMirrorPage.jsx`

**Add import at top:**
```javascript
import { useLoading } from '@/contexts/LoadingContext'
import { useError } from '@/contexts/ErrorContext'
import AnalysisProgress from '@/components/blackmirror/AnalysisProgress'
```

**Update handleAnalysisStart method (line 142-167):**
```javascript
const handleAnalysisStart = async () => {
  if (files.length === 0) return

  const { startAnalysis, updateAnalysisProgress, updateAnalysisStage, completeAnalysis, errorAnalysis } = useLoading()
  const { addError } = useError()

  try {
    const analysisId = `analysis_${Date.now()}`
    startAnalysis(analysisId)
    setAnalysisId(analysisId)

    updateAnalysisStage('processing')
    updateAnalysisProgress(25)

    const fileContent = await files[0].text()

    updateAnalysisStage('analyzing')
    updateAnalysisProgress(50)

    const report = await runCompleteAnalysis(fileContent, 'text')

    updateAnalysisStage('compiling')
    updateAnalysisProgress(75)

    if (report.success) {
      updateAnalysisProgress(100)
      setMLReport(report)
      completeAnalysis()
    } else {
      const error = report.error || 'Analysis failed'
      setError(error)
      errorAnalysis(error)
      addError(error, 'ANALYSIS_ERROR', { canRetry: true })
    }
  } catch (err) {
    const errorMsg = err.message || 'Analysis failed'
    setError(errorMsg)
    errorAnalysis(errorMsg)
    addError(errorMsg, 'ANALYSIS_ERROR', { canRetry: true })
  }
}
```

**Add AnalysisProgress component to render:**
```javascript
return (
  <>
    <Helmet>
      {/* ... existing helmet config ... */}
    </Helmet>

    <div className="blackmirror-page-eye">
      <canvas ref={canvasRef} className="scanline-canvas" />

      {/* ADD THIS: AnalysisProgress Component */}
      <AnalysisProgress
        onCancel={handleCancel}
        showETA={true}
      />

      {showResults && mlReport ? (
        // ... existing results section ...
      ) : (
        // ... existing upload section ...
      )}
    </div>
  </>
)
```

#### 5. Verify Client.js Setup

File: `/home/fastl/JustLayMe/client/src/services/client.js`

**Should have these imports (already added):**
```javascript
import axios from 'axios'
import { setupTokenRefreshInterceptor } from '@/utils/tokenRefreshInterceptor'
```

**Should have this export (already added):**
```javascript
export function initializeTokenRefresh(refreshTokenFn) {
  if (tokenRefreshInitialized) return

  try {
    setupTokenRefreshInterceptor(apiClient, refreshTokenFn)
    tokenRefreshInitialized = true
    console.log('[API Client] Token refresh interceptor initialized')
  } catch (error) {
    console.error('[API Client] Failed to setup token refresh interceptor:', error)
  }
}
```

#### 6. Verify AuthAPI.js Setup

File: `/home/fastl/JustLayMe/client/src/services/authAPI.js`

**Should have these imports (already added):**
```javascript
import apiClient, { initializeTokenRefresh } from './client'
```

**Login method should have (already added):**
```javascript
// FIX 15: Initialize token refresh interceptor on successful login
initializeTokenRefresh(authAPI.refreshToken)
```

**Signup method should have (already added):**
```javascript
// FIX 15: Initialize token refresh interceptor on successful signup
initializeTokenRefresh(authAPI.refreshToken)
```

---

## Verification

### 1. Check All Files Exist

```bash
# Contexts
ls -la /home/fastl/JustLayMe/client/src/contexts/LoadingContext.jsx
ls -la /home/fastl/JustLayMe/client/src/contexts/ErrorContext.jsx

# Utilities
ls -la /home/fastl/JustLayMe/client/src/utils/tokenRefreshInterceptor.js

# Tests
ls -la /home/fastl/JustLayMe/client/src/__tests__/fixes/

# Documentation
ls -la /home/fastl/JustLayMe/PHASE2_*.md
```

### 2. Verify Imports Work

```bash
cd /home/fastl/JustLayMe/client
npm run dev
# Open browser and check console for any import errors
```

### 3. Run All Tests

```bash
cd /home/fastl/JustLayMe/client
npm test -- __tests__/fixes/

# Or run individually:
npm test -- fix12-loading-states.test.js
npm test -- fix13-error-handling.test.js
npm test -- fix14-progress-indicator.test.js
npm test -- fix15-token-refresh.test.js
npm test -- integration.test.js
```

### 4. Manual Testing

- **FIX 12:** Click character in Sidebar → Should show loading spinner
- **FIX 13:** Upload file that fails → Should show retry button
- **FIX 14:** Upload files for analysis → Should show progress indicator
- **FIX 15:** Wait 50+ minutes logged in → Should stay logged in (token auto-refreshes)

---

## Troubleshooting

### Error: "useLoading must be used within LoadingProvider"
**Solution:** Make sure LoadingProvider wraps your entire app in App.jsx

### Error: "Cannot find module '@/utils/tokenRefreshInterceptor'"
**Solution:** Verify the file exists at `/home/fastl/JustLayMe/client/src/utils/tokenRefreshInterceptor.js`

### Tests fail with "Vitest not found"
**Solution:** Make sure Vitest is installed: `npm install -D vitest`

### Sidebar doesn't show loading state
**Solution:** 
1. Verify LoadingProvider is in App.jsx
2. Check that `startCharacterSwitch` is called before API
3. Check that `completeCharacterSwitch` is called after API succeeds

### Token doesn't auto-refresh
**Solution:**
1. Check browser console for errors
2. Verify `initializeTokenRefresh(authAPI.refreshToken)` called in login
3. Check token expiration: `localStorage.getItem('authToken')`

---

## Next Steps

1. ✅ All files created
2. ✅ All tests written  
3. ✅ All documentation complete
4. 📋 Run setup steps above
5. 📋 Run tests: `npm test -- __tests__/fixes/`
6. 📋 Manual testing in browser
7. 📋 Commit and deploy

---

## Support Files

- **Full Guide:** `/home/fastl/JustLayMe/PHASE2_IMPLEMENTATION.md`
- **Summary:** `/home/fastl/JustLayMe/PHASE2_SUMMARY.md`
- **Quick Ref:** `/home/fastl/JustLayMe/PHASE2_QUICK_REFERENCE.md`
- **This File:** `/home/fastl/JustLayMe/PHASE2_SETUP_INSTRUCTIONS.md`

---

**Status: ✅ READY FOR INTEGRATION**
