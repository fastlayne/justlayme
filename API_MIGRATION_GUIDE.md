# API Migration Guide - Security Fixes

## Quick Reference: Updated API Endpoints

This guide shows the changes needed in frontend code after the authorization bypass security fixes.

---

## Conversations API

### List Conversations
```javascript
// OLD (Vulnerable)
fetch(`/api/conversations/${userId}`)

// NEW (Secure)
fetch('/api/conversations')
```

### Get Conversation Messages
```javascript
// OLD (Vulnerable)
fetch(`/api/conversations/${userId}/${conversationId}`)

// NEW (Secure)
fetch(`/api/conversations/${conversationId}`)
```

### Update Conversation Title
```javascript
// OLD (Vulnerable)
fetch(`/api/conversations/${conversationId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId, title })
})

// NEW (Secure)
fetch(`/api/conversations/${conversationId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title })  // userId removed
})
```

### Delete Conversation
```javascript
// OLD (Vulnerable)
fetch(`/api/conversations/${conversationId}`, {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId })
})

// NEW (Secure)
fetch(`/api/conversations/${conversationId}`, {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json' }
    // No body needed - userId from JWT
})
```

---

## Memory Analytics API

### Get Memory Profile
```javascript
// OLD (Vulnerable)
fetch(`/api/memory/${userId}`)

// NEW (Secure)
fetch('/api/memory')
```

---

## Premium Verification API

### Verify Premium Status
```javascript
// OLD (Vulnerable)
fetch(`/api/verify-premium/${userId}`, {
    method: 'POST'
})

// NEW (Secure)
fetch('/api/verify-premium', {
    method: 'POST'
})
```

---

## Voice Cloning API

### Upload Voice Samples
```javascript
// OLD (Vulnerable)
const formData = new FormData();
formData.append('userId', userId);
formData.append('characterId', characterId);
formData.append('voice1', voiceFile1);

fetch('/api/voice-clone', {
    method: 'POST',
    body: formData
})

// NEW (Secure)
const formData = new FormData();
// Don't send userId - it comes from JWT
formData.append('characterId', characterId);
formData.append('voice1', voiceFile1);

fetch('/api/voice-clone', {
    method: 'POST',
    body: formData
})
```

### List Voice Samples
```javascript
// OLD (Vulnerable)
fetch('/api/voice/samples', {
    headers: { 'user-id': userId }
})
// OR
fetch(`/api/voice/samples?userId=${userId}`)

// NEW (Secure)
fetch('/api/voice/samples')
// userId automatically extracted from JWT
```

### Get Voice Sample Audio
```javascript
// OLD (Vulnerable)
fetch(`/api/voice/sample/${sampleId}/audio`, {
    headers: { 'user-id': userId }
})

// NEW (Secure)
fetch(`/api/voice/sample/${sampleId}/audio`)
// userId automatically extracted from JWT
```

### Delete Voice Sample
```javascript
// OLD (Vulnerable)
fetch(`/api/voice/sample/${sampleId}`, {
    method: 'DELETE',
    headers: { 'user-id': userId }
})

// NEW (Secure)
fetch(`/api/voice/sample/${sampleId}`, {
    method: 'DELETE'
})
// userId automatically extracted from JWT
```

---

## Legacy Voice Upload (if used)

### Upload Voice for Cloning
```javascript
// OLD (Vulnerable)
const formData = new FormData();
formData.append('u', userId);  // Using 'u' as key
formData.append('v', voiceFile);

fetch('/api/vc', {
    method: 'POST',
    body: formData
})

// NEW (Secure)
const formData = new FormData();
// Don't send 'u' (userId) - it comes from JWT
formData.append('v', voiceFile);

fetch('/api/vc', {
    method: 'POST',
    body: formData
})
```

---

## Authentication Headers

All requests must include the JWT token in the Authorization header:

```javascript
fetch('/api/conversations', {
    headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
    }
})
```

Or use cookies (if configured):
```javascript
// Token stored in httpOnly cookie 'authToken'
fetch('/api/conversations', {
    credentials: 'include'  // Send cookies
})
```

---

## Key Changes Summary

1. **Remove userId from URLs** - It's extracted from the JWT token
2. **Remove userId from request bodies** - Not needed anymore
3. **Remove userId from headers** - JWT provides identity
4. **Remove userId from query parameters** - JWT provides identity
5. **Keep JWT token in Authorization header** - This is how the server identifies you

---

## Error Handling

### Unauthorized Errors
```javascript
fetch('/api/conversations')
    .then(response => {
        if (response.status === 401) {
            // Token invalid or missing
            // Redirect to login
        }
        if (response.status === 403) {
            // Forbidden - may need premium
        }
        return response.json();
    })
```

---

## Testing Checklist

After updating your frontend code, verify:

- [ ] Can access own conversations
- [ ] Cannot access other users' conversations (should get 403/404)
- [ ] Can upload voice samples
- [ ] Can list own voice samples
- [ ] Cannot access other users' voice samples
- [ ] Can check own premium status
- [ ] Cannot check other users' premium status
- [ ] All JWT tokens are properly included in requests
- [ ] Proper error handling for 401/403 responses

---

## Migration Priority

### Critical (Do First)
1. Conversations API updates
2. Authentication header verification

### High Priority
1. Voice cloning API updates
2. Premium verification updates

### Medium Priority
1. Memory analytics updates
2. Error handling improvements

---

## Need Help?

If you encounter issues:

1. Check browser console for 401/403 errors
2. Verify JWT token is being sent correctly
3. Check that userId is not being sent in request
4. Review the detailed audit report: `SECURITY_AUDIT_REPORT.md`

---

*Last Updated: 2025-12-07*
*Security Audit ID: SA-2025-12-07-001*
