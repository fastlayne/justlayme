# Google Analytics 4 (GA4) Implementation Guide

## Overview

This document outlines the comprehensive GA4 implementation for the JustLayMe React application. The implementation includes automatic page view tracking, custom event tracking, user identification, and e-commerce tracking capabilities.

## Files Created/Modified

### Created Files
1. **`/src/services/analytics.js`** - Core GA4 service with all tracking functions
2. **`/src/hooks/useAnalytics.js`** - React hook for using analytics throughout the app
3. **`GA4_IMPLEMENTATION_GUIDE.md`** - This implementation guide

### Modified Files
1. **`/src/App.jsx`** - Initializes GA4 and tracks page views
2. **`/index.html`** - GA4 script tag enabled
3. **`.env`** - Added `VITE_GA_MEASUREMENT_ID` environment variable

## Setup Instructions

### Step 1: Get Your GA4 Measurement ID

1. Go to [Google Analytics](https://analytics.google.com/)
2. Create a new property for JustLayMe or use existing
3. Navigate to Admin > Data Streams > Web
4. Create a new web stream for your domain
5. Copy the **Measurement ID** (format: `G-XXXXXXXXXX`)

### Step 2: Update Environment Variables

Edit `.env` file and replace the placeholder:

```env
VITE_GA_MEASUREMENT_ID=G-YOUR_ACTUAL_ID_HERE
```

### Step 3: Update index.html Script Tag

In `/index.html`, replace both instances of `G-XXXXXXXXXX` with your actual Measurement ID:

```html
<script async src="https://www.googletagmanager.com/gtag/js?id=G-YOUR_ACTUAL_ID_HERE"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-YOUR_ACTUAL_ID_HERE', {
    'allow_google_signals': true,
    'allow_ad_personalization_signals': true,
    'anonymize_ip': true
  });
</script>
```

### Step 4: Test the Implementation

1. Start your development server: `npm run dev`
2. Open Chrome DevTools > Network tab
3. Filter by "gtag" or "google-analytics"
4. Navigate between pages
5. You should see GA requests being sent

## Automatic Tracking

### Page Views (Automatic)

Page views are automatically tracked when users navigate between routes:

- `/` - Home
- `/login` - Login
- `/chat` - Chat
- `/black-mirror` - Black Mirror Analysis
- `/premium` - Premium

**Location:** `/src/App.jsx` - `AppContent` component

## Custom Event Tracking

### Using the useAnalytics Hook

The simplest way to track custom events is using the `useAnalytics` hook:

```jsx
import { useAnalytics } from '../hooks/useAnalytics'

export function MyComponent() {
  const { trackEvent, trackLogin, trackSignUp, trackChatMessage } = useAnalytics()

  const handleButtonClick = () => {
    trackEvent('button_clicked', { button_name: 'submit' })
  }

  const handleLogin = () => {
    trackLogin('google', { signup_source: 'header' })
  }

  return <button onClick={handleButtonClick}>Click Me</button>
}
```

### Using the Analytics Service Directly

For non-React code or more advanced scenarios:

```javascript
import * as analyticsService from '../services/analytics'

// Track any custom event
analyticsService.trackEvent('my_event', {
  custom_param_1: 'value1',
  custom_param_2: 42,
})

// Track user ID (after authentication)
analyticsService.setUserId('user_123')

// Set user properties
analyticsService.setUserProperties({
  user_type: 'premium',
  signup_date: '2024-01-15',
})
```

## Recommended Events to Track

### Authentication Events

```javascript
// Track login
import { useAnalytics } from '../hooks/useAnalytics'
const { trackLogin } = useAnalytics()

trackLogin('google') // or 'email', 'password'
```

```javascript
// Track sign up (in LoginPage or registration flow)
import { useAnalytics } from '../hooks/useAnalytics'
const { trackSignUp } = useAnalytics()

trackSignUp('google', { signup_source: 'landing_page' })
```

### Chat Events (ChatPage)

```javascript
import { useAnalytics } from '../hooks/useAnalytics'

export function ChatPage() {
  const { trackChatMessage } = useAnalytics()

  const handleMessageSend = (message) => {
    // Send message to API...

    // Track the event
    trackChatMessage({
      character_id: currentCharacter.id,
      message_length: message.length,
      has_attachment: false,
      character_type: 'neural', // or 'custom', 'preset'
    })
  }

  return <></>
}
```

### Character Creation (NeuralCharacterBuilder)

```javascript
import { useAnalytics } from '../hooks/useAnalytics'

export function NeuralCharacterBuilder() {
  const { trackCharacterCreated } = useAnalytics()

  const handleCreateCharacter = async (characterData) => {
    // Create character via API...

    // Track the event
    trackCharacterCreated({
      character_type: 'neural_custom',
      character_name: characterData.name,
      traits_count: characterData.traits.length,
    })
  }

  return <></>
}
```

### Premium Features (PremiumPage)

```javascript
import { useAnalytics } from '../hooks/useAnalytics'

export function PremiumPage() {
  const { trackPremiumView, trackBeginCheckout } = useAnalytics()

  useEffect(() => {
    // Track premium page view
    trackPremiumView({ premium_tier: 'pro' })
  }, [])

  const handleCheckout = () => {
    trackBeginCheckout({
      tier: 'pro',
      price: 9.99,
      currency: 'USD',
    })
  }

  return <></>
}
```

### Black Mirror Analysis (BlackMirrorPage)

```javascript
import { useAnalytics } from '../hooks/useAnalytics'

export function BlackMirrorPage() {
  const { trackBlackMirrorAccess } = useAnalytics()

  const handleAnalysis = async (data) => {
    // Perform analysis...

    trackBlackMirrorAccess({
      analysis_type: 'relationship',
      user_count: data.users.length,
      message_count: data.messages.length,
    })
  }

  return <></>
}
```

## Available Analytics Functions

### From useAnalytics Hook

```javascript
const {
  trackEvent,              // Custom event tracking
  trackPageView,           // Manual page view
  setUserProperties,       // Set user segments
  setUserId,              // Set authenticated user ID
  trackLogin,             // Login event
  trackSignUp,            // Sign up event
  trackChatMessage,       // Chat interaction
  trackCharacterCreated,  // Character creation
  trackBlackMirrorAccess, // Black Mirror analysis
  trackPremiumView,       // Premium page view
  trackPurchase,          // Purchase/subscription
  trackBeginCheckout,     // Checkout started
  trackException,         // Error tracking
  trackOutboundLink,      // External link clicks
  trackFeatureUsage,      // Feature usage
} = useAnalytics()
```

### From Analytics Service

All hook functions available plus:

```javascript
import * as analyticsService from '../services/analytics'

// Core functions
analyticsService.initializeGA(measurementId)
analyticsService.trackEvent(eventName, eventData)
analyticsService.trackPageView(pagePath, pageTitle, additionalParams)
analyticsService.setUserProperties(userProperties)
analyticsService.setUserId(userId)
analyticsService.isGAAvailable()

// Specialized tracking functions
analyticsService.trackLogin(method, additionalData)
analyticsService.trackSignUp(method, additionalData)
analyticsService.trackChatMessage(data)
analyticsService.trackCharacterCreated(data)
analyticsService.trackBlackMirrorAccess(data)
analyticsService.trackPremiumView(data)
analyticsService.trackPurchase(data)
analyticsService.trackBeginCheckout(data)
analyticsService.trackException(errorMessage, isFatal)
analyticsService.trackScrollDepth(percentage)
analyticsService.trackMediaEvent(action, data)
analyticsService.trackOutboundLink(url, additionalData)
analyticsService.trackFeatureUsage(featureName, data)
```

## Event Naming Conventions

GA4 uses **snake_case** for event names and parameter names. Follow these conventions:

### Event Names
- `page_view` - Page view (automatic)
- `login` - User login
- `sign_up` - User registration
- `purchase` - Purchase/subscription
- `chat_message_sent` - Message sent
- `character_created` - Character creation
- `black_mirror_analysis` - Analysis initiated

### Parameter Names
- `character_id` - Character identifier
- `character_type` - Type of character
- `message_length` - Length of message
- `user_type` - Type of user (premium, free)
- `subscription_tier` - Subscription level
- `analysis_type` - Type of analysis

## Best Practices

### 1. User Identification

Set user ID after authentication:

```javascript
// In LoginPage or AuthProvider
const { setUserId } = useAnalytics()

useEffect(() => {
  if (user && user.id) {
    setUserId(user.id)
  }
}, [user, setUserId])
```

### 2. User Segmentation

Set user properties to enable audience segmentation:

```javascript
const { setUserProperties } = useAnalytics()

useEffect(() => {
  if (user) {
    setUserProperties({
      user_type: user.isPremium ? 'premium' : 'free',
      signup_date: user.createdAt,
      last_login: new Date().toISOString(),
    })
  }
}, [user, setUserProperties])
```

### 3. Error Tracking

Track errors for debugging and monitoring:

```javascript
import { trackException } from '../services/analytics'

try {
  // Do something...
} catch (error) {
  trackException(error.message, true) // true = fatal error
}
```

### 4. Parameter Consistency

Always use the same parameter names across your app:

```javascript
// GOOD - Consistent
trackChatMessage({ character_id: 'char_123' })
trackCharacterCreated({ character_id: 'char_456' })

// BAD - Inconsistent
trackChatMessage({ id: 'char_123' })
trackCharacterCreated({ characterId: 'char_456' })
```

### 5. Event Limits

GA4 standard properties allow up to 25 custom parameters per event. Keep event payloads lean:

```javascript
// GOOD - Focused event data
trackChatMessage({
  character_id: 'char_123',
  message_length: 150,
})

// BAD - Too many parameters
trackChatMessage({
  character_id: 'char_123',
  character_name: 'name',
  character_type: 'type',
  message_length: 150,
  message_content: 'full message',
  user_id: 'user_123',
  user_name: 'name',
  timestamp: new Date().toISOString(),
  app_version: '1.0.0',
  // ... many more parameters
})
```

## Integration Points for Each Page

### IndexPage (/)
```javascript
// Already tracked automatically via page view
// Additional events as needed
```

### LoginPage (/login)
```javascript
import { useAnalytics } from '../hooks/useAnalytics'

// In form submission handler
const { trackLogin, trackSignUp, setUserId } = useAnalytics()

// After successful login
trackLogin('google')
setUserId(user.id)
setUserProperties({ user_type: user.isPremium ? 'premium' : 'free' })

// After successful sign up
trackSignUp('email')
setUserId(newUser.id)
```

### ChatPage (/chat)
```javascript
const { trackChatMessage, trackCharacterCreated } = useAnalytics()

// When message is sent
trackChatMessage({
  character_id: activeCharacter.id,
  message_length: message.length,
})

// When new character is created
trackCharacterCreated({
  character_type: characterType,
  source: 'chat_page',
})
```

### BlackMirrorPage (/black-mirror)
```javascript
const { trackBlackMirrorAccess } = useAnalytics()

// When analysis is performed
trackBlackMirrorAccess({
  analysis_type: 'conversation_analysis',
  participants_count: participants.length,
})
```

### PremiumPage (/premium)
```javascript
const { trackPremiumView, trackBeginCheckout } = useAnalytics()

// On page load
trackPremiumView()

// On checkout button click
trackBeginCheckout({
  tier: 'pro',
  price: 9.99,
  currency: 'USD',
})
```

## Development vs. Production

### Development Mode (Placeholder ID)

During development, GA4 won't send data if using the placeholder ID:

```env
VITE_GA_MEASUREMENT_ID=G-XXXXXXXXXX  # Development (GA disabled)
```

Check browser console for debug logs:
```
GA not available, skipping event: event_name {...}
```

### Production Mode (Real ID)

Replace with your actual ID:

```env
VITE_GA_MEASUREMENT_ID=G-YOUR_REAL_ID  # Production (GA enabled)
```

Data will be sent to Google Analytics.

## Testing GA4 Implementation

### 1. Check Network Requests

1. Open Chrome DevTools
2. Go to Network tab
3. Filter by "gtag" or "google-analytics"
4. Look for requests to `www.google-analytics.com`

### 2. Use Google Analytics DebugView

1. Go to [Google Analytics](https://analytics.google.com/)
2. Navigate to Configure > DebugView
3. Events should appear in real-time as you use the app

### 3. Check Browser Console

Development logs show when GA tracks events:

```javascript
// When GA is properly initialized
"Google Analytics initialized with measurement ID: G-XXXXXXXXXX"

// When GA is not available (development mode)
"GA not available, skipping page view: /chat"
```

### 4. Use Google Tag Manager Preview

1. Set up [Google Tag Manager](https://tagmanager.google.com/)
2. Enable preview mode
3. See real-time event firing in GTM interface

## Troubleshooting

### GA Not Tracking

**Problem:** Events not appearing in Google Analytics

**Solutions:**
1. Check that `VITE_GA_MEASUREMENT_ID` is set correctly (not `G-XXXXXXXXXX`)
2. Verify the script tag in `index.html` has the correct ID
3. Check browser console for errors
4. Use DebugView in Google Analytics to see real-time data
5. Ensure Google Analytics property is properly configured

### Events Have Wrong Names

**Problem:** Event names in GA don't match what you tracked

**Solution:** GA4 automatically converts parameter names, but event names must match exactly:

```javascript
// This creates an event named "chat_message_sent"
trackEvent('chat_message_sent', {...})

// This creates an event named "chatMessageSent" (might not match your GA configuration)
trackEvent('chatMessageSent', {...})
```

### Missing Parameters

**Problem:** Custom parameters not appearing in GA4 reports

**Solutions:**
1. Register custom events in GA4 admin interface
2. Ensure parameter names are consistent (snake_case)
3. Check that you're using the same parameter names across your app

### Performance Impact

**Consideration:** GA4 adds minimal overhead (~20KB gzipped)

**Optimization tips:**
1. The GA script loads asynchronously (async attribute)
2. GA only fires events when needed
3. Events don't block user interactions
4. Use `isGAAvailable()` to check if GA is configured before tracking

## Resources

- [Google Analytics 4 Documentation](https://support.google.com/analytics/answer/10089681)
- [GA4 Event Setup Guide](https://support.google.com/analytics/answer/9216061)
- [GA4 Implementation Guide](https://support.google.com/analytics/answer/9416520)
- [gtag.js Documentation](https://developers.google.com/analytics/devguides/collection/gtagjs)

## Summary

The GA4 implementation is fully integrated and ready to use:

- ✓ Automatic page view tracking
- ✓ Custom event tracking via hook
- ✓ User identification and segmentation
- ✓ Error and exception tracking
- ✓ E-commerce event helpers
- ✓ Development/production support
- ✓ Graceful handling when GA not configured
- ✓ Type-safe event tracking

Start using it by importing `useAnalytics` in any React component and calling tracking functions!
