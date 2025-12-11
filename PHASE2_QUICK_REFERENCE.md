# Phase 2 Quick Reference Guide

## TL;DR - What Was Implemented

| Fix | Problem | Solution | Status |
|-----|---------|----------|--------|
| 12 | Blank UI during async ops | LoadingContext with proper state transitions | ✅ Complete |
| 13 | Silent failures, no retries | ErrorContext with retry mechanism | ✅ Complete |
| 14 | No progress during analysis | AnalysisProgress with spinner, %, ETA | ✅ Complete |
| 15 | Session expires without warning | Token refresh interceptor (proactive) | ✅ Complete |

---

## Files You Need to Know

### New Files (Must Include)

```
/client/src/contexts/LoadingContext.jsx       ← Character, upload, analysis loading
/client/src/contexts/ErrorContext.jsx         ← Error management with retries
/client/src/utils/tokenRefreshInterceptor.js  ← Auto token refresh
/client/src/__tests__/fixes/fix12-*.test.js   ← 82 total tests
```

### Modified Files

```
/client/src/services/client.js      ← Added token refresh setup
/client/src/services/authAPI.js     ← Initialize token refresh on login
/client/src/components/blackmirror/AnalysisProgress.jsx  ← Already exists, ready to use
```

---

## 3-Step Integration

### Step 1: Add Providers (App.jsx)
```javascript
import { LoadingProvider } from '@/contexts/LoadingContext'
import { ErrorProvider } from '@/contexts/ErrorContext'

export default function App() {
  return (
    <LoadingProvider>
      <ErrorProvider>
        <Routes />
      </ErrorProvider>
    </LoadingProvider>
  )
}
```

### Step 2: Update Components
Use the hooks in your components:
```javascript
const { startCharacterSwitch, completeCharacterSwitch, errorCharacterSwitch } = useLoading()
const { addError, retryError } = useError()
```

### Step 3: Test
```bash
npm test -- __tests__/fixes/
```

---

## Quick API Reference

### LoadingContext (FIX 12)
```javascript
// Hook
const { characterSwitch, fileUpload, analysis } = useLoading()

// Methods
startCharacterSwitch(char)
completeCharacterSwitch(char)
errorCharacterSwitch(error)

startFileUpload(fileName)
updateUploadProgress(0-100)
completeFileUpload(url)
errorFileUpload(error)

startAnalysis(id)
updateAnalysisProgress(0-100)
updateAnalysisStage('processing'|'analyzing'|'compiling')
completeAnalysis()
errorAnalysis(error)
cancelAnalysis()
```

### ErrorContext (FIX 13)
```javascript
// Hook
const { addError, clearError, retryError, registerRetry } = useError()

// Methods
addError(message, type, { canRetry: true })
clearError(errorId)
retryError(errorId)
registerRetry(errorId, retryFn, maxRetries)

// Helpers
hasErrors()
getActiveError()
canRetryError(errorId)
```

### Token Refresh (FIX 15)
```javascript
import { isTokenExpiringSoon, setupTokenRefreshInterceptor } from '@/utils/tokenRefreshInterceptor'

// Automatic: happens in authAPI.login/signup
// Manual:
initializeTokenRefresh(authAPI.refreshToken)
```

---

## Test Each Fix

### FIX 12: Loading States
```bash
npm test -- fix12-loading-states.test.js
```
✅ 13 tests for character switch, upload, analysis loading

### FIX 13: Error Handling
```bash
npm test -- fix13-error-handling.test.js
```
✅ 16 tests for error display, retry, recovery

### FIX 14: Progress Indicator
```bash
npm test -- fix14-progress-indicator.test.js
```
✅ 18 tests for progress display, ETA, cancellation

### FIX 15: Token Refresh
```bash
npm test -- fix15-token-refresh.test.js
```
✅ 21 tests for token detection, refresh, deduplication

### Integration Tests
```bash
npm test -- integration.test.js
```
✅ 14 tests for complete user flows

---

## Common Scenarios

### Scenario 1: User Switches Character
1. User clicks character in Sidebar
2. `startCharacterSwitch(id)` called
3. Loading spinner appears
4. API call happens
5. `completeCharacterSwitch(id)` called
6. Loading spinner disappears
7. UI updates

**Code:**
```javascript
const { startCharacterSwitch, completeCharacterSwitch, errorCharacterSwitch } = useLoading()

try {
  startCharacterSwitch(id)
  await selectCharacterAPI(id)
  completeCharacterSwitch(id)
} catch (error) {
  errorCharacterSwitch(error.message)
}
```

### Scenario 2: File Upload Fails
1. User selects file
2. `startFileUpload(name)` called
3. Upload progresses
4. Error occurs
5. `errorFileUpload(error)` called
6. Error message shows with "Retry" button
7. User clicks retry
8. `retryError(errorId)` called
9. Upload retries automatically

**Code:**
```javascript
const { startFileUpload, updateUploadProgress, completeFileUpload, errorFileUpload } = useLoading()
const { addError, registerRetry } = useError()

try {
  startFileUpload(file.name)
  await uploadWithProgress(file)
  completeFileUpload(url)
} catch (error) {
  const errorId = addError(error.message, 'UPLOAD_ERROR', { canRetry: true })
  registerRetry(errorId, () => uploadWithProgress(file), 3)
  errorFileUpload(error.message)
}
```

### Scenario 3: Long-Running Analysis
1. User uploads files
2. `startAnalysis(id)` called
3. AnalysisProgress component shows
4. Progress updates: 0% → 25% → 50% → 75% → 100%
5. Stages update: processing → analyzing → compiling
6. User can click Cancel if needed
7. Analysis completes
8. `completeAnalysis()` called
9. Results display

**Code:**
```javascript
const { startAnalysis, updateAnalysisProgress, updateAnalysisStage, completeAnalysis } = useLoading()

try {
  startAnalysis(id)

  updateAnalysisStage('processing')
  updateAnalysisProgress(25)

  updateAnalysisStage('analyzing')
  updateAnalysisProgress(50)

  const result = await runAnalysis()

  updateAnalysisStage('compiling')
  updateAnalysisProgress(100)

  completeAnalysis()
  setResults(result)
} catch (error) {
  errorAnalysis(error.message)
}
```

### Scenario 4: Token Expires During Use
1. User is logged in
2. 50 minutes pass (token has 10-minute expiration)
3. Token refresh interceptor detects expiration in 1 minute
4. **Transparently refreshes token in background**
5. User continues using app without interruption
6. No "session expired" message

**Automatic! No code needed.**

---

## Error Handling Patterns

### Pattern 1: Simple Error Display
```javascript
const { addError } = useError()

try {
  await someAsyncOp()
} catch (error) {
  addError(error.message, 'ERROR')
}
```

### Pattern 2: Error with Retry
```javascript
const { addError, registerRetry } = useError()

try {
  await someAsyncOp()
} catch (error) {
  const errorId = addError(error.message, 'ERROR', { canRetry: true })
  registerRetry(errorId, someAsyncOp, 3)
}
```

### Pattern 3: Global Error
```javascript
const { setGlobalError } = useError()

if (criticalFailure) {
  setGlobalError('Critical system error occurred', 'CRITICAL')
}
```

---

## Common Mistakes to Avoid

❌ **Don't:** Use old `isSending` state
✅ **Do:** Use `useLoading()` hook

❌ **Don't:** Forget to wrap with providers
✅ **Do:** Add LoadingProvider/ErrorProvider to App.jsx

❌ **Don't:** Update error state manually
✅ **Do:** Use `addError()` method

❌ **Don't:** Ignore token refresh
✅ **Do:** Call `initializeTokenRefresh()` after login

❌ **Don't:** Show generic errors
✅ **Do:** Use specific error types and messages

---

## Debugging Tips

### Check Loading State
```javascript
const { characterSwitch, fileUpload, analysis } = useLoading()
console.log('Loading state:', { characterSwitch, fileUpload, analysis })
```

### Check Errors
```javascript
const { errors, activeErrorId } = useError()
console.log('Errors:', errors)
console.log('Active error:', activeErrorId ? errors[activeErrorId] : null)
```

### Check Token
```javascript
import { isTokenExpired, isTokenExpiringSoon } from '@/utils/tokenRefreshInterceptor'
const token = localStorage.getItem('authToken')
console.log('Token expired:', isTokenExpired(token))
console.log('Expiring soon:', isTokenExpiringSoon(token))
```

---

## File Locations Summary

**Contexts:**
- LoadingContext: `/home/fastl/JustLayMe/client/src/contexts/LoadingContext.jsx`
- ErrorContext: `/home/fastl/JustLayMe/client/src/contexts/ErrorContext.jsx`

**Utilities:**
- Token Refresh: `/home/fastl/JustLayMe/client/src/utils/tokenRefreshInterceptor.js`

**Tests:**
- All tests: `/home/fastl/JustLayMe/client/src/__tests__/fixes/`

**Documentation:**
- Full guide: `/home/fastl/JustLayMe/PHASE2_IMPLEMENTATION.md`
- Summary: `/home/fastl/JustLayMe/PHASE2_SUMMARY.md`
- This file: `/home/fastl/JustLayMe/PHASE2_QUICK_REFERENCE.md`

---

## Success Criteria

✅ All 82 tests pass
✅ Character switch shows loading indicator
✅ File upload shows progress bar
✅ Analysis shows progress with ETA
✅ Failed operations show retry buttons
✅ Token refreshes automatically without logout
✅ No "session expired" appears suddenly
✅ All error messages are user-friendly
✅ No console errors

---

## Support

**Questions about implementation?**
→ See `PHASE2_IMPLEMENTATION.md` for detailed guide

**Want to know what was changed?**
→ See `PHASE2_SUMMARY.md` for complete file list

**Ready to integrate?**
→ Follow the 3-Step Integration above

**Need to test?**
→ Run `npm test -- __tests__/fixes/`

---

**Status: ✅ READY TO USE**
