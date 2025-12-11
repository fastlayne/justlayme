# GA4 Quick Start Guide

## 5-Minute Setup

### 1. Get Your GA4 ID

Visit [Google Analytics](https://analytics.google.com/) and get your Measurement ID (looks like `G-XXXXXXXXXX`)

### 2. Add to .env

```bash
VITE_GA_MEASUREMENT_ID=G-YOUR_ACTUAL_ID_HERE
```

### 3. Update index.html

Replace `G-XXXXXXXXXX` with your ID in these two places:

```html
<script async src="https://www.googletagmanager.com/gtag/js?id=G-YOUR_ID_HERE"></script>
<script>
  gtag('config', 'G-YOUR_ID_HERE', { ... });
</script>
```

### 4. Done!

Page views are automatically tracked. Start your dev server:

```bash
npm run dev
```

## Using GA4 in Components

### Track Login
```javascript
import { useAnalytics } from '../hooks/useAnalytics'

function LoginPage() {
  const { trackLogin, setUserId } = useAnalytics()

  const handleLogin = async (user) => {
    trackLogin('google')
    setUserId(user.id)
  }
}
```

### Track Custom Events
```javascript
const { trackEvent } = useAnalytics()

// Send chat message
trackEvent('chat_message_sent', {
  character_id: 'char_123',
  message_length: 150,
})

// Create character
trackEvent('character_created', {
  character_type: 'neural_custom',
})

// Access Black Mirror
trackEvent('black_mirror_analysis', {
  analysis_type: 'conversation',
})
```

### Track User Properties
```javascript
const { setUserProperties } = useAnalytics()

setUserProperties({
  user_type: 'premium',
  signup_date: '2024-01-15',
})
```

## Test It

1. Open Chrome DevTools → Network tab
2. Filter by "gtag"
3. Navigate between pages
4. You should see GA requests
5. Check [Google Analytics DebugView](https://analytics.google.com/) for real-time data

## All Available Functions

```javascript
const {
  // Core
  trackEvent,           // Any custom event
  trackPageView,        // Manual page tracking

  // Auth
  trackLogin,           // User login
  trackSignUp,          // User sign up
  setUserId,            // Set authenticated user
  setUserProperties,    // Set user segments

  // Features
  trackChatMessage,     // Chat interactions
  trackCharacterCreated, // Character creation
  trackBlackMirrorAccess, // Black Mirror analysis
  trackPremiumView,     // Premium features

  // Purchases
  trackPurchase,        // Purchase event
  trackBeginCheckout,   // Checkout started

  // Error Handling
  trackException,       // Errors and exceptions
  trackOutboundLink,    // External links
  trackFeatureUsage,    // Feature tracking
} = useAnalytics()
```

## Event Examples for Each Page

### LoginPage (/login)
```javascript
trackLogin('google')
trackSignUp('email')
setUserId(user.id)
```

### ChatPage (/chat)
```javascript
trackChatMessage({ character_id: 'char_123', message_length: 100 })
trackCharacterCreated({ character_type: 'neural_custom' })
```

### BlackMirrorPage (/black-mirror)
```javascript
trackBlackMirrorAccess({ analysis_type: 'relationship' })
```

### PremiumPage (/premium)
```javascript
trackPremiumView()
trackBeginCheckout({ tier: 'pro', price: 9.99 })
```

## Development vs Production

**Development** (GA disabled):
```env
VITE_GA_MEASUREMENT_ID=G-XXXXXXXXXX
```

**Production** (GA enabled):
```env
VITE_GA_MEASUREMENT_ID=G-YOUR_REAL_ID
```

## Files Overview

| File | Purpose |
|------|---------|
| `/src/services/analytics.js` | Core GA4 service - all tracking functions |
| `/src/hooks/useAnalytics.js` | React hook to use analytics in components |
| `/src/App.jsx` | GA4 initialization + automatic page tracking |
| `/.env` | GA4 Measurement ID configuration |
| `/index.html` | GA4 script tag |

## See Also

- Full guide: [GA4_IMPLEMENTATION_GUIDE.md](./GA4_IMPLEMENTATION_GUIDE.md)
- GA4 Docs: [Google Analytics 4](https://support.google.com/analytics)

---

**That's it!** You now have a fully functional GA4 implementation. Start tracking events and analyzing user behavior.
