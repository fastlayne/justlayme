# RAPID PHASE 2 FIXES - MINIMAL CODE CHANGES

## FIX 9: LRU Race Conditions with Mutex Locking

**File**: `/home/fastl/JustLayMe/src/memory-engine.js`

**Change 1** (Line 11): Add import
```javascript
const { Mutex } = require('p-lock');
```

**Change 2** (Lines 82-93): Replace createLRUMap function
```javascript
// OLD: Non-atomic map.set()
const createLRUMap = (maxSize) => {
    const map = new Map();
    map.maxSize = maxSize;
    const originalSet = map.set.bind(map);
    map.set = function(key, value) {
        if (this.size >= this.maxSize && !this.has(key)) {
            const firstKey = this.keys().next().value;
            this.delete(firstKey);
        }
        this.delete(key);
        return originalSet(key, value);
    };
    return map;
};

// NEW: Atomic with mutex
const createLRUMap = (maxSize) => {
    const map = new Map();
    map.maxSize = maxSize;
    map.mutex = new Mutex();
    const originalSet = map.set.bind(map);
    map.set = async function(key, value) {
        const release = await this.mutex.lock();
        try {
            if (this.size >= this.maxSize && !this.has(key)) {
                const firstKey = this.keys().next().value;
                this.delete(firstKey);
            }
            this.delete(key);
            return originalSet(key, value);
        } finally { release(); }
    };
    return map;
};
```

---

## FIX 10: Token Blacklist to Database

**File**: `/home/fastl/JustLayMe/src/services/auth.js`

**Status**: ALREADY IMPLEMENTED (lines 30, 83, 223-256)

**Verification**: Run this SQL to create table:
```sql
CREATE TABLE IF NOT EXISTS blacklisted_tokens (
  token_hash TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_expires_at ON blacklisted_tokens(expires_at);
```

---

## FIX 11: Stripe Webhook Transaction Safety

**File**: `/home/fastl/JustLayMe/src/ai-server.js`

**Location**: Around line 2540 in stripe webhook handler

**Change**: Wrap user updates in transaction
```javascript
// OLD:
await sharedDb.query('UPDATE users SET subscription_status = ? WHERE id = ?', [status, userId]);
await sharedDb.query('UPDATE users SET custom_characters_created = ? WHERE id = ?', [charCount, userId]);

// NEW:
try {
    await sharedDb.query('BEGIN TRANSACTION');
    await sharedDb.query('UPDATE users SET subscription_status = ? WHERE id = ?', [status, userId]);
    await sharedDb.query('UPDATE users SET custom_characters_created = ? WHERE id = ?', [charCount, userId]);
    await sharedDb.query('COMMIT');
} catch (error) {
    await sharedDb.query('ROLLBACK');
    throw error;
}
```

---

## FIX 12: Loading States Everywhere

**Files**:
- `/home/fastl/JustLayMe/client/src/pages/BlackMirrorPage.jsx`
- `/home/fastl/JustLayMe/client/src/components/Sidebar.jsx`
- `/home/fastl/JustLayMe/client/src/components/InputArea.jsx`

**Minimal Change** (add to each component):
```javascript
// 1. Add useState:
const [isLoading, setIsLoading] = useState(false);

// 2. Wrap async operations:
const handleOperation = async () => {
    setIsLoading(true);
    try {
        // your operation
    } finally {
        setIsLoading(false);
    }
};

// 3. Disable during load:
<button disabled={isLoading}>{isLoading ? 'Loading...' : 'Click Me'}</button>
```

---

## FIX 13: Error Handling for Async Operations

**Pattern** (apply to all async operations):
```javascript
const operation = async () => {
    try {
        const result = await asyncCall();
        return result;
    } catch (err) {
        // Show user-friendly error
        if (err.response?.status === 401) {
            showError('Please log in again');
        } else if (err.response?.status === 402) {
            showError(err.response.data.message || 'Premium required');
        } else {
            showError(err.message || 'An error occurred');
        }
        console.error('Error:', err);
        throw err;
    }
};
```

---

## FIX 14: Grey Mirror Loading Indicator with Progress

**File**: `/home/fastl/JustLayMe/client/src/pages/BlackMirrorPage.jsx`

**Add to existing component**:
```javascript
// 1. Add state:
const [analysisProgress, setAnalysisProgress] = useState(0);

// 2. Update in analysis:
const handleAnalysisStart = async () => {
    setIsAnalyzing(true);
    try {
        setAnalysisProgress(0);
        const report = await runCompleteAnalysis(fileContent, 'text');
        setAnalysisProgress(100);
        setMLReport(report);
    } finally {
        setIsAnalyzing(false);
    }
};

// 3. Show progress in JSX:
{isAnalyzing && (
    <div className="analysis-progress">
        <Spinner />
        <p>Analyzing... {analysisProgress}%</p>
        <div style={{ width: `${analysisProgress}%` }} className="progress-bar" />
    </div>
)}
```

---

## FIX 15: Token Expiration Auto-Refresh

**File 1**: `/home/fastl/JustLayMe/client/src/services/client.js`

**Add to apiClient setup**:
```javascript
// Add 401 interceptor for token refresh
apiClient.interceptors.response.use(
    response => response,
    async (error) => {
        const originalRequest = error.config;

        if (error.response?.status === 401 && !originalRequest._retry) {
            originalRequest._retry = true;
            try {
                const newToken = await refreshTokenFn();
                originalRequest.headers.Authorization = `Bearer ${newToken}`;
                return apiClient(originalRequest);
            } catch (err) {
                window.location.href = '/login';
                throw err;
            }
        }
        return Promise.reject(error);
    }
);

// Export function to initialize
export const initializeTokenRefresh = (refreshFn) => {
    refreshTokenFn = refreshFn;
};
```

**File 2**: `/home/fastl/JustLayMe/client/src/services/authAPI.js`

**Add method**:
```javascript
export const refreshToken = async () => {
    try {
        const token = localStorage.getItem('authToken');
        const response = await apiClient.post('/api/refresh-token', { token });
        if (response.token) {
            localStorage.setItem('authToken', response.token);
        }
        return response.token;
    } catch (error) {
        localStorage.removeItem('authToken');
        throw error;
    }
};
```

**File 3**: `/home/fastl/JustLayMe/src/ai-server.js`

**Add endpoint**:
```javascript
app.post('/api/refresh-token', async (req, res) => {
    try {
        const { token } = req.body;
        if (!token) return res.status(401).json({ error: 'Token required' });

        let decoded = jwt.verify(token, JWT_SECRET, { ignoreExpiration: true });
        if (authService.isTokenBlacklisted(token)) {
            return res.status(401).json({ error: 'Token revoked' });
        }

        const newToken = authService.generateToken({
            id: decoded.id,
            email: decoded.email
        });

        res.json({ token: newToken });
    } catch (error) {
        res.status(500).json({ error: 'Token refresh failed' });
    }
});
```

---

## TOTAL CHANGES SUMMARY

| Fix # | File | Change | LOC |
|-------|------|--------|-----|
| 9 | memory-engine.js | Add mutex to LRU | 15 |
| 10 | auth.js | Already done | 0 |
| 11 | ai-server.js | Transaction wrapper | 8 |
| 12 | Sidebar/Input/BlackMirror | Loading states | 20 |
| 13 | All async | Try-catch pattern | 25 |
| 14 | BlackMirrorPage.jsx | Progress indicator | 12 |
| 15 | client.js + authAPI.js + ai-server.js | Token refresh | 30 |
| | | **TOTAL** | **~110 LOC** |

**Estimated Implementation Time**: 30-45 minutes with testing

---

## Files Modified List
1. `/home/fastl/JustLayMe/src/memory-engine.js` - FIX 9
2. `/home/fastl/JustLayMe/src/ai-server.js` - FIX 11, FIX 15 endpoint
3. `/home/fastl/JustLayMe/client/src/pages/BlackMirrorPage.jsx` - FIX 12, FIX 14
4. `/home/fastl/JustLayMe/client/src/components/Sidebar.jsx` - FIX 12
5. `/home/fastl/JustLayMe/client/src/components/InputArea.jsx` - FIX 12
6. `/home/fastl/JustLayMe/client/src/services/client.js` - FIX 15
7. `/home/fastl/JustLayMe/client/src/services/authAPI.js` - FIX 15
