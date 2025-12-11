# Error Handling Issues - Quick Reference Guide

## Location Index by File

### `/home/fastl/JustLayMe/src/sqlite-chat-history.js`
- **Line 7-40:** `initializePreparedStatements()` catches errors but continues
- **Line 66:** `result.rows[0]` accessed without null check
- **Line 95:** Same - `result.rows[0]` without bounds check
- **Issue:** Database format inconsistency, silent failures
- **Risk:** Server crashes on unexpected database format

### `/home/fastl/JustLayMe/src/conversations-api-bridge.js`
- **Line 115:** `result.rows || result` defensive pattern unclear
- **Line 157, 191, 230, 250, 299:** Array access without bounds checks
- **Line 374-407:** Axios call without proper error handling
- **Line 400:** `chatResponse.data.response || chatResponse.data` - nested property access
- **Issue:** Unhandled HTTP errors, missing null checks
- **Risk:** Crashes on API failures, undefined accesses

### `/home/fastl/JustLayMe/src/routes/upload.js`
- **Line 68-70:** Race condition - exists check then mkdir
- **Line 78:** `fs.renameSync()` blocks event loop, can overwrite
- **Line 97-102:** Cleanup error swallowed
- **Issue:** File system race conditions, synchronous I/O
- **Risk:** Lost temp files, concurrent upload corruption

### `/home/fastl/JustLayMe/src/character-memory-api.js`
- **Line 50-71:** `fetch()` without timeout, no validation
- **Line 70:** `response.json()` not wrapped in try-catch
- **Line 71:** `data.response` access without checking existence
- **Line 81:** Regex match destructuring assumes format
- **Issue:** LLM service errors cause crashes
- **Risk:** Memory extraction silently fails

### `/home/fastl/JustLayMe/src/custom-characters-api.js`
- **Line 8-86:** Schema setup errors swallowed
- **Line 33-62:** ALTER TABLE success assumed
- **Line 57:** Only checks for "duplicate column" error
- **Line 146:** `result.rows || result || []` pattern
- **Issue:** Inconsistent database schema, missing columns
- **Risk:** Endpoints crash on undefined properties

### `/home/fastl/JustLayMe/src/services/auth.js`
- **Line 426-460:** Promise.race timeout doesn't cleanup DB query
- **Line 449:** `String(user.id)` could create "undefined" strings
- **Line 451:** `user.email.toLowerCase()` crashes if null
- **Line 457:** Returns null on ANY error (loses context)
- **Issue:** Database connection leaks, invalid user IDs
- **Risk:** Memory leaks under timeout, invalid auth states

### `/home/fastl/JustLayMe/src/middleware/auth.js`
- **Line 43:** `await authService.getUserFromToken()` no timeout
- **Line 82:** `authService.generateErrorResponse()` could throw
- **Line 91-120:** `optionalAuth` silently continues on errors
- **Line 112:** Both "no token" and "invalid token" same result
- **Line 119:** `next()` call without error handling
- **Issue:** Request hangs, auth errors indistinguishable
- **Risk:** Requests timeout during auth checks

### `/home/fastl/JustLayMe/src/database.js`
- **Line 166-290:** Callback hell with nested Promise constructor
- **Line 226:** Regex groups assumed but not validated
- **Line 279:** `this.changes` context binding issue
- **Line 219, 273:** Original error code/message lost
- **Issue:** Difficult error tracing, context loss
- **Risk:** Hard to debug, promise chain violations

### `/home/fastl/JustLayMe/src/advanced-rag-memory-engine.js`
- **Line 79-95:** AsyncJobQueue no timeout on jobs
- **Line 94:** `_processNext()` throws unhandled
- **Line 90:** Queue can grow unbounded
- **Issue:** Hung jobs block queue, memory leaks
- **Risk:** Application hangs, OOM conditions

### `/home/fastl/JustLayMe/src/ollama-embedding-service.js`
- **Line 79:** axios.get() no timeout - infinite wait possible
- **Line 92:** Nested `pullEmbeddingModel()` also no timeout
- **Line 97-99:** Service unreachable treated as "not found"
- **Issue:** Startup hangs if Ollama unavailable
- **Risk:** Application fails to start

### `/home/fastl/JustLayMe/src/routes/analytics.js`
- **Line 27-50:** Promise.all on inserts - one failure loses all
- **Line 44:** `JSON.stringify(event.properties)` unprotected
- **Line 199-212:** Same Promise.all pattern
- **Line 209:** `result.rows?.[0]?.count` unclear DB format
- **Issue:** Partial failure handling, JSON crashes
- **Risk:** Analytics lost, one bad event breaks batch

### `/home/fastl/JustLayMe/src/database-pool-manager.js`
- **Line 126-148:** Race condition on activeCount
- **Line 134-144:** createConnection .catch missing cleanup
- **Line 100-106:** Timeout handler could remove wrong request
- **Issue:** Connection count exceeds limit, leaks
- **Risk:** Resource exhaustion under load

### `/home/fastl/JustLayMe/src/error-recovery-manager.js`
- **Line 80-99:** Recovery strategies with nested awaits
- **Line 82-84:** `context.restartWorker()` could throw/hang
- **Line 91-92:** `context.worker.terminate()` already terminated
- **Issue:** Recovery itself could fail indefinitely
- **Risk:** Cascading failures

### `/home/fastl/JustLayMe/src/resource-lifecycle-manager.js`
- **Line 51-59:** Interval errors swallowed with no recovery
- **Issue:** No exponential backoff on failing intervals
- **Risk:** Silent background process failures

### `/home/fastl/JustLayMe/src/password-reset-api.js`
- **Line 83, 178:** `JSON.stringify()` without try-catch
- **Issue:** Circular references crash function
- **Risk:** Password reset broken by bad metadata

### `/home/fastl/JustLayMe/src/middleware/rate-limit.js`
- **Line 48:** Redis connection doesn't wait for async connect
- **Issue:** Could use memory store before Redis ready
- **Risk:** Rate limit inconsistency between restarts

### `/home/fastl/JustLayMe/src/memory-cache.js`
- **Line 477, 485:** Concurrent map modifications
- **Issue:** No locking on cache during parallel operations
- **Risk:** Cache corruption under concurrent access

### `/home/fastl/JustLayMe/src/memory-engine.js`
- **Line 80-97:** LRU cache `this.keys().next().value` undefined
- **Issue:** Cache can exceed maxSize
- **Risk:** Memory leaks from unbounded cache

---

## Error Patterns - Detection Regex

### Unhandled Promises
```regex
await\s+\w+\..+\(\)  # await without try-catch context
\.then\([^)]*\)(?!\.catch)  # .then() without .catch()
```

### Missing Null Checks
```regex
\[0\](?!\s*\?)  # Array[0] access without prior existence check
\.\w+\(  # Method call on potentially null object
```

### JSON Operations
```regex
JSON\.parse\s*\(  # JSON.parse without try-catch
JSON\.stringify\s*\(  # JSON.stringify without try-catch
```

### Callback Hell
```regex
\([^)]*=>[^}]*\([^)]*=>[^}]*\([^)]*=>  # Nested callbacks 3+ levels
```

---

## Quick Fix Template

### For Unhandled Promise Rejections:
```javascript
// BEFORE
const result = await db.query(sql, params);

// AFTER
let result;
try {
    result = await db.query(sql, params);
} catch (error) {
    console.error('Query failed:', error);
    return res.status(500).json({ error: 'Database operation failed' });
}
```

### For Missing Null Checks:
```javascript
// BEFORE
const user = users[0];
console.log(user.email);

// AFTER
const users = result.rows || [];
if (!users.length) {
    return null;  // or appropriate error handling
}
const user = users[0];
if (!user || !user.email) {
    throw new Error('Invalid user object');
}
console.log(user.email);
```

### For JSON Operations:
```javascript
// BEFORE
const json = JSON.stringify(data);

// AFTER
let json;
try {
    json = JSON.stringify(data);
} catch (error) {
    console.error('JSON serialization failed:', error);
    json = '{}';  // or appropriate fallback
}
```

### For Timeout Protection:
```javascript
// BEFORE
const response = await axios.get(url);

// AFTER
const response = await Promise.race([
    axios.get(url),
    new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Request timeout')), 5000)
    )
]);
```

### For Race Conditions (Files):
```javascript
// BEFORE
if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
}

// AFTER
try {
    fs.mkdirSync(dir, { recursive: true });
} catch (err) {
    if (err.code !== 'EEXIST') throw err;
}
```

---

## Testing Checklist

### For Each Critical File:

- [ ] Run with `--expose-gc` and monitor heap growth
- [ ] Send malformed API responses (null, wrong type, missing fields)
- [ ] Simulate database timeouts (set very low socket timeout)
- [ ] Try concurrent operations (multiple users uploading, etc.)
- [ ] Simulate service unavailability (stop Ollama, Redis, etc.)
- [ ] Send JSON with circular references
- [ ] Interrupt long-running operations mid-execution
- [ ] Monitor unhandled rejections with:
  ```javascript
  process.on('unhandledRejection', (reason, promise) => {
      console.error('Unhandled Rejection:', reason);
      process.exit(1);
  });
  ```

---

## Monitoring Alerts to Add

```
1. Alert: Repeated "Error in interval" logs from same interval
2. Alert: Database query timeouts > 5 per minute
3. Alert: Temp file cleanup failures accumulating
4. Alert: Connection pool activeCount > maxConnections
5. Alert: Promise.race timeout wins > 1% of calls
6. Alert: JSON.stringify errors
7. Alert: Unhandled promise rejections detected
8. Alert: Memory growth > expected baseline
```

---

## Impact Assessment

**Files with Critical Issues:** 8
- conversations-api-bridge.js
- database.js
- sqlite-chat-history.js
- routes/upload.js
- services/auth.js
- middleware/auth.js
- advanced-rag-memory-engine.js
- ollama-embedding-service.js

**Estimated Risk:** HIGH
- Multiple unhandled promise paths could crash server
- Race conditions could cause data corruption
- Resource leaks could cause OOM under load
- Silent failures hide bugs until production

**Estimated Fix Time:** 40-60 hours
- Critical fixes: 24 hours
- High priority: 20 hours
- Medium/Low: 16 hours

---

**Last Updated:** November 18, 2025
**Status:** Assessment Report - No Changes Made
