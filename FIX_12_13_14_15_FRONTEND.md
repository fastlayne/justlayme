# FRONTEND FIXES 12-15: Loading States & Error Handling

## FIX 12: Loading States Everywhere

### BlackMirrorPage.jsx
```jsx
// Add to useState section:
const [isAnalyzing, setIsAnalyzing] = useState(false);
const [analysisProgress, setAnalysisProgress] = useState(0);

// Update upload handler:
const handleAnalysisStart = async () => {
  if (files.length === 0) return;

  try {
    setIsAnalyzing(true);
    setAnalysisProgress(0);

    // Show spinner during upload
    const fileContent = await files[0].text();

    // Show progress during analysis
    const report = await runCompleteAnalysis(fileContent, 'text');

    if (report.success) {
      setMLReport(report);
      setAnalysisProgress(100);
    } else {
      setError(report.error || 'Analysis failed');
    }
  } catch (err) {
    setError(err.message);
  } finally {
    setIsAnalyzing(false);
  }
};

// In JSX, show spinner:
{isAnalyzing && (
  <div className="analysis-progress">
    <Spinner />
    <p>Analyzing... {analysisProgress}%</p>
  </div>
)}
```

### Sidebar.jsx - Character Switch
```jsx
const [isSwitching, setIsSwitching] = useState(false);

const handleCharacterSwitch = async (characterId) => {
  setIsSwitching(true);
  try {
    // Switch logic
  } catch (err) {
    console.error('Character switch failed:', err);
  } finally {
    setIsSwitching(false);
  }
};

// Show spinner during switch:
{isSwitching && <Spinner />}
```

### InputArea.jsx - File Upload
```jsx
const [isUploading, setIsUploading] = useState(false);

const handleFileUpload = async (file) => {
  setIsUploading(true);
  try {
    // Upload logic
  } catch (err) {
    showError(err.message);
  } finally {
    setIsUploading(false);
  }
};

// Show loading state:
<button disabled={isUploading}>
  {isUploading ? 'Uploading...' : 'Upload'}
</button>
```

## FIX 13: Error Handling for Async Operations

```jsx
// Template for all async operations:
const handleAsyncOperation = async () => {
  try {
    // operation
    const result = await someAsyncCall();
    return result;
  } catch (err) {
    // Proper error propagation
    if (err.response?.status === 401) {
      // Handle auth error
      showError('Please log in again');
      redirectToLogin();
    } else if (err.response?.status === 402) {
      // Handle paywall
      showError(err.response.data.message);
      openPremiumModal();
    } else {
      // Generic error
      showError(err.message || 'An error occurred');
    }
    console.error('Operation failed:', err);
    throw err; // Re-throw for caller
  }
};
```

## FIX 14: Grey Mirror Loading Indicator with Progress

```jsx
// AnalysisProgress.jsx component:
export default function AnalysisProgress({ progress, canCancel, onCancel }) {
  return (
    <div className="analysis-progress-container">
      <div className="spinner" />
      <p className="progress-text">Analyzing your relationships...</p>
      <div className="progress-bar">
        <div className="progress-fill" style={{ width: `${progress}%` }} />
      </div>
      <p className="progress-percent">{Math.round(progress)}%</p>
      {canCancel && (
        <button className="cancel-btn" onClick={onCancel}>
          Cancel Analysis
        </button>
      )}
    </div>
  );
}

// In BlackMirrorPage.jsx:
{isAnalyzing && (
  <AnalysisProgress
    progress={analysisProgress}
    canCancel={true}
    onCancel={handleCancelAnalysis}
  />
)}
```

## FIX 15: Token Expiration Auto-Refresh

### authAPI.js - Add Refresh Token Endpoint
```javascript
// Add refresh token method:
export const refreshToken = async () => {
  try {
    const token = localStorage.getItem('authToken');
    const response = await apiClient.post('/api/refresh-token', {
      token: token
    });

    if (response.token) {
      localStorage.setItem('authToken', response.token);
      return response.token;
    }
  } catch (error) {
    // Clear auth on refresh failure
    localStorage.removeItem('authToken');
    throw error;
  }
};

// Initialize interceptor on login:
initializeTokenRefresh(refreshToken);
```

### client.js - Add 401 Interceptor
```javascript
// In apiClient setup:
apiClient.interceptors.response.use(
  response => response,
  async error => {
    const originalRequest = error.config;

    // Handle 401 with refresh attempt
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      try {
        const newToken = await authAPI.refreshToken();
        originalRequest.headers.Authorization = `Bearer ${newToken}`;
        return apiClient(originalRequest);
      } catch (refreshError) {
        // Refresh failed, redirect to login
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  }
);
```

### Backend - Add /api/refresh-token endpoint
```javascript
// In ai-server.js:
app.post('/api/refresh-token', async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(401).json({ error: 'Token required' });
    }

    // Verify token validity (even if expired)
    let decoded;
    try {
      decoded = jwt.verify(token, JWT_SECRET, { ignoreExpiration: true });
    } catch (err) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    // Check if token is blacklisted
    if (authService.isTokenBlacklisted(token)) {
      return res.status(401).json({ error: 'Token revoked' });
    }

    // Generate new token
    const newToken = authService.generateToken({
      id: decoded.id,
      email: decoded.email
    });

    res.json({ token: newToken });
  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(500).json({ error: 'Token refresh failed' });
  }
});
```

---

## Implementation Checklist
- [ ] FIX 12: Add isLoading state to Sidebar, InputArea, BlackMirrorPage
- [ ] FIX 13: Wrap all async operations in try-catch
- [ ] FIX 14: Create AnalysisProgress component and integrate
- [ ] FIX 15: Implement token refresh interceptor
- [ ] FIX 15: Add /api/refresh-token backend endpoint
- [ ] Test token refresh on 401 errors
- [ ] Test loading states prevent double-clicks
