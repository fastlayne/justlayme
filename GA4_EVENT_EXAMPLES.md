# GA4 Event Tracking Examples

Complete code examples for tracking all recommended events in the JustLayMe application.

---

## 1. Authentication Events

### Login Event

**Location:** `src/pages/LoginPage.jsx`

```javascript
import { useAnalytics } from '../hooks/useAnalytics'

export function LoginPage() {
  const { trackLogin, setUserId, setUserProperties } = useAnalytics()

  const handleGoogleLogin = async (credentialResponse) => {
    try {
      // Decode and authenticate
      const decoded = jwtDecode(credentialResponse.credential)
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: credentialResponse.credential })
      })
      const user = await response.json()

      // Track login event
      trackLogin('google', {
        signup_source: 'login_page',
        has_existing_account: true
      })

      // Set authenticated user ID
      setUserId(user.id)

      // Set user properties for segmentation
      setUserProperties({
        user_type: user.isPremium ? 'premium' : 'free',
        account_age_days: Math.floor((Date.now() - new Date(user.createdAt)) / 86400000),
        subscription_tier: user.subscriptionTier || 'none'
      })

      // Navigate to chat
      navigate('/chat')
    } catch (error) {
      console.error('Login failed:', error)
    }
  }

  const handleEmailLogin = async (email, password) => {
    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      })
      const user = await response.json()

      // Track login with email method
      trackLogin('email', {
        signup_source: 'login_page',
        has_existing_account: true
      })

      setUserId(user.id)
      setUserProperties({
        user_type: user.isPremium ? 'premium' : 'free'
      })

      navigate('/chat')
    } catch (error) {
      console.error('Login failed:', error)
    }
  }

  return (/* JSX for login form */)
}
```

### Sign Up Event

**Location:** `src/pages/LoginPage.jsx` (Sign Up Tab)

```javascript
const handleSignUp = async (email, password, name) => {
  try {
    const response = await fetch('/api/auth/signup', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, name })
    })
    const newUser = await response.json()

    // Track sign up event
    trackSignUp('email', {
      signup_source: 'landing_page',
      referral_code: urlParams.get('ref') || null,
      marketing_channel: urlParams.get('utm_source') || null
    })

    // Set user ID
    setUserId(newUser.id)

    // Set initial user properties
    setUserProperties({
      user_type: 'free',
      account_age_days: 0,
      subscription_tier: 'none'
    })

    navigate('/chat')
  } catch (error) {
    console.error('Sign up failed:', error)
  }
}
```

---

## 2. Chat Page Events

### Chat Message Sent

**Location:** `src/pages/ChatPage.jsx`

```javascript
import { useAnalytics } from '../hooks/useAnalytics'

export function ChatPage() {
  const { trackChatMessage } = useAnalytics()
  const [messages, setMessages] = useState([])
  const [currentCharacter, setCurrentCharacter] = useState(null)

  const handleSendMessage = async (messageText) => {
    try {
      // Send message to API
      const response = await fetch('/api/chat/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          characterId: currentCharacter.id,
          message: messageText
        })
      })
      const result = await response.json()

      // Track the message sent event
      trackChatMessage({
        character_id: currentCharacter.id,
        character_name: currentCharacter.name,
        character_type: currentCharacter.type, // 'neural', 'custom', 'preset'
        message_length: messageText.length,
        has_attachment: false,
        conversation_length: messages.length + 1,
        response_time_ms: result.processingTime || 0
      })

      setMessages([...messages, result])
    } catch (error) {
      console.error('Message send failed:', error)
    }
  }

  const handleSendMessageWithAttachment = async (messageText, file) => {
    try {
      const formData = new FormData()
      formData.append('message', messageText)
      formData.append('file', file)
      formData.append('characterId', currentCharacter.id)

      const response = await fetch('/api/chat/send', {
        method: 'POST',
        body: formData
      })
      const result = await response.json()

      // Track message with attachment
      trackChatMessage({
        character_id: currentCharacter.id,
        character_type: currentCharacter.type,
        message_length: messageText.length,
        has_attachment: true,
        attachment_type: file.type.split('/')[0], // 'image', 'audio', 'text', etc.
        attachment_size_kb: Math.round(file.size / 1024)
      })

      setMessages([...messages, result])
    } catch (error) {
      console.error('Message with attachment failed:', error)
    }
  }

  return (/* Chat UI */)
}
```

### Character Creation Event

**Location:** `src/components/NeuralCharacterBuilder.jsx` (or similar)

```javascript
import { useAnalytics } from '../hooks/useAnalytics'

export function NeuralCharacterBuilder() {
  const { trackCharacterCreated, trackEvent } = useAnalytics()
  const [characterData, setCharacterData] = useState({
    name: '',
    traits: [],
    background: '',
    personality: ''
  })

  const handleCreateCharacter = async () => {
    try {
      const response = await fetch('/api/characters/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(characterData)
      })
      const newCharacter = await response.json()

      // Track character creation
      trackCharacterCreated({
        character_id: newCharacter.id,
        character_name: newCharacter.name,
        character_type: 'neural_custom',
        traits_count: characterData.traits.length,
        background_length: characterData.background.length,
        personality_length: characterData.personality.length,
        creation_time_seconds: timer.elapsed / 1000
      })

      // Track additional detail event
      trackEvent('custom_character_details', {
        has_background: !!characterData.background,
        has_personality: !!characterData.personality,
        voice_enabled: characterData.voiceSettings?.enabled || false,
        visibility: characterData.visibility || 'private' // 'private', 'public', 'shared'
      })

      navigate(`/chat?character=${newCharacter.id}`)
    } catch (error) {
      console.error('Character creation failed:', error)
    }
  }

  const handleModifyCharacter = async (characterId, updates) => {
    try {
      const response = await fetch(`/api/characters/${characterId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updates)
      })
      const updated = await response.json()

      // Track character modification
      trackEvent('character_modified', {
        character_id: characterId,
        modified_fields: Object.keys(updates).join(','),
        field_count: Object.keys(updates).length
      })
    } catch (error) {
      console.error('Character modification failed:', error)
    }
  }

  return (/* Character Builder UI */)
}
```

### Character Deletion Event

```javascript
const handleDeleteCharacter = async (characterId) => {
  try {
    await fetch(`/api/characters/${characterId}`, {
      method: 'DELETE'
    })

    trackEvent('character_deleted', {
      character_id: characterId,
      deletion_reason: deletionReason || 'user_initiated'
    })

    // Refresh character list
    loadCharacters()
  } catch (error) {
    console.error('Delete failed:', error)
  }
}
```

---

## 3. Black Mirror Analysis Events

### Black Mirror Access Event

**Location:** `src/pages/BlackMirrorPage.jsx`

```javascript
import { useAnalytics } from '../hooks/useAnalytics'

export function BlackMirrorPage() {
  const { trackBlackMirrorAccess, trackEvent } = useAnalytics()
  const [selectedConversation, setSelectedConversation] = useState(null)
  const [analysisResults, setAnalysisResults] = useState(null)

  const handlePerformAnalysis = async (conversationData) => {
    try {
      const startTime = Date.now()

      // Call analysis API
      const response = await fetch('/api/black-mirror/analyze', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: conversationData.messages,
          participants: conversationData.participants,
          analysisType: conversationData.analysisType
        })
      })
      const results = await response.json()
      setAnalysisResults(results)

      const analysisTime = Date.now() - startTime

      // Track Black Mirror analysis access
      trackBlackMirrorAccess({
        analysis_type: conversationData.analysisType, // 'conversation_analysis', 'relationship_analysis', 'pattern_analysis'
        participants_count: conversationData.participants.length,
        message_count: conversationData.messages.length,
        time_period_days: conversationData.timePeriodDays || null,
        analysis_depth: results.depth, // 'basic', 'standard', 'deep'
        processing_time_ms: analysisTime,
        has_custom_parameters: conversationData.customParams ? true : false
      })

      // Track additional analysis details
      trackEvent('black_mirror_analysis_complete', {
        insights_count: results.insights?.length || 0,
        patterns_found: results.patterns?.length || 0,
        sentiment_scores_calculated: results.sentimentAnalysis ? true : false,
        health_score: results.relationshipHealth || null
      })

    } catch (error) {
      console.error('Analysis failed:', error)
      trackEvent('black_mirror_analysis_error', {
        error_type: error.name,
        error_message: error.message
      })
    }
  }

  const handleExportAnalysis = async (format) => {
    try {
      const response = await fetch('/api/black-mirror/export', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          analysisId: analysisResults.id,
          format: format // 'pdf', 'json', 'csv'
        })
      })

      // Track export event
      trackEvent('black_mirror_export', {
        export_format: format,
        analysis_type: analysisResults.type,
        file_size_kb: response.headers.get('content-length') / 1024
      })

      // Trigger download
      downloadFile(response)
    } catch (error) {
      console.error('Export failed:', error)
    }
  }

  return (/* Black Mirror UI */)
}
```

---

## 4. Premium Page Events

### Premium View Event

**Location:** `src/pages/PremiumPage.jsx`

```javascript
import { useAnalytics } from '../hooks/useAnalytics'

export function PremiumPage() {
  const { trackPremiumView, trackBeginCheckout, trackEvent } = useAnalytics()
  const [selectedTier, setSelectedTier] = useState(null)
  const [showComparison, setShowComparison] = useState(false)

  useEffect(() => {
    // Track premium page view
    trackPremiumView({
      current_tier: currentUser?.subscriptionTier || 'free',
      view_source: location.state?.source || 'direct',
      is_upgrade_flow: location.state?.isUpgrade || false
    })
  }, [])

  const handleSelectTier = (tier) => {
    setSelectedTier(tier)

    // Track tier selection
    trackEvent('premium_tier_selected', {
      tier_id: tier.id,
      tier_name: tier.name,
      price: tier.price,
      currency: 'USD',
      billing_cycle: tier.billingCycle // 'monthly', 'annual'
    })
  }

  const handleShowComparison = () => {
    setShowComparison(true)

    trackEvent('premium_comparison_viewed', {
      comparison_type: 'feature_comparison',
      from_tier: currentUser?.subscriptionTier || 'free',
      to_tier: selectedTier?.id || null
    })
  }

  const handleStartCheckout = async (tier, billingCycle) => {
    try {
      // Create checkout session
      const response = await fetch('/api/premium/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          tierId: tier.id,
          billingCycle: billingCycle
        })
      })
      const checkoutSession = await response.json()

      // Track checkout initiation
      trackBeginCheckout({
        tier_id: tier.id,
        tier_name: tier.name,
        price: tier.price,
        currency: 'USD',
        billing_cycle: billingCycle,
        subscription_type: billingCycle === 'annual' ? 'annual_subscription' : 'monthly_subscription',
        from_upgrade: currentUser?.subscriptionTier ? true : false,
        from_tier: currentUser?.subscriptionTier || 'free'
      })

      // Redirect to payment
      window.location.href = checkoutSession.checkoutUrl
    } catch (error) {
      console.error('Checkout failed:', error)
      trackEvent('checkout_error', {
        error_type: error.name,
        tier_id: tier.id
      })
    }
  }

  const handleClaimFreeTrial = async () => {
    try {
      const response = await fetch('/api/premium/claim-trial', {
        method: 'POST'
      })
      const result = await response.json()

      // Track free trial claim
      trackEvent('free_trial_claimed', {
        trial_duration_days: result.trialDays,
        included_features: result.features.length,
        expiry_date: result.expiryDate
      })

    } catch (error) {
      console.error('Trial claim failed:', error)
    }
  }

  return (/* Premium Pricing UI */)
}
```

---

## 5. User Property Updates

### On Login/Signup

```javascript
// In AuthProvider or after successful login
const { setUserProperties, setUserId } = useAnalytics()

useEffect(() => {
  if (user && user.id) {
    // Set authenticated user ID
    setUserId(user.id)

    // Set user properties for segmentation
    setUserProperties({
      user_id: user.id,
      user_type: user.isPremium ? 'premium' : 'free',
      subscription_tier: user.subscriptionTier || 'none',
      signup_date: user.createdAt?.substring(0, 10) || null,
      account_age_days: user.createdAt ?
        Math.floor((Date.now() - new Date(user.createdAt)) / 86400000) : 0,
      email_verified: user.emailVerified || false,
      profile_complete: user.profileComplete || false,
      last_login_date: new Date().toISOString().substring(0, 10),
      chat_message_count: user.stats?.messageCount || 0,
      characters_created: user.stats?.characterCount || 0,
      black_mirror_analyses: user.stats?.analysisCount || 0
    })
  }
}, [user, setUserId, setUserProperties])
```

### On Subscription Change

```javascript
const handleUpgradeSubscription = async (newTier) => {
  try {
    const response = await fetch('/api/subscriptions/upgrade', {
      method: 'POST',
      body: JSON.stringify({ tierId: newTier.id })
    })
    const updatedUser = await response.json()

    // Update user properties
    setUserProperties({
      user_type: 'premium',
      subscription_tier: newTier.id,
      subscription_upgrade_date: new Date().toISOString().substring(0, 10),
      subscription_value: newTier.price
    })

    trackEvent('subscription_upgraded', {
      from_tier: currentUser.subscriptionTier,
      to_tier: newTier.id,
      price: newTier.price,
      billing_cycle: newTier.billingCycle
    })
  } catch (error) {
    console.error('Upgrade failed:', error)
  }
}
```

---

## 6. Error/Exception Tracking

### Comprehensive Error Tracking

```javascript
import { useAnalytics } from '../hooks/useAnalytics'

export function ErrorBoundary() {
  const { trackException } = useAnalytics()

  const handleError = (error, info) => {
    // Track the error
    trackException(
      `${error.toString()} - ${info.componentStack}`,
      true // true = fatal error
    )

    // Log to error reporting service
    reportError(error, info)
  }

  return (/* error UI */)
}
```

### API Error Handling

```javascript
const handleAPIError = (error, context) => {
  const { trackException } = useAnalytics()

  const errorMessage = error.response?.data?.message || error.message

  trackException(
    `API Error [${error.response?.status}]: ${errorMessage} (Context: ${context})`,
    error.response?.status >= 500 // true = fatal if server error
  )

  console.error(`[${context}] API Error:`, error)
}
```

### Form Validation Error

```javascript
const { trackEvent } = useAnalytics()

const handleFormSubmit = (formData) => {
  const errors = validateForm(formData)

  if (Object.keys(errors).length > 0) {
    trackEvent('form_validation_error', {
      form_name: 'character_creation',
      error_fields: Object.keys(errors).join(','),
      error_count: Object.keys(errors).length
    })
    return
  }

  // Process valid form
}
```

---

## 7. Feature Usage Tracking

### Voice Clone Feature

```javascript
const { trackFeatureUsage } = useAnalytics()

const handleVoiceClone = async (characterId) => {
  trackFeatureUsage('voice_clone', {
    character_id: characterId,
    voice_quality: 'high', // 'low', 'standard', 'high'
    sample_duration_seconds: 5,
    language: 'en-US'
  })

  // Process voice cloning
}
```

### Relationship Analysis Feature

```javascript
const handleRelationshipAnalysis = async () => {
  trackFeatureUsage('relationship_analysis', {
    analysis_depth: 'detailed',
    include_recommendations: true,
    include_visualization: true
  })

  // Perform analysis
}
```

---

## 8. Outbound Link Tracking

### External Link Clicks

```javascript
import { useAnalytics } from '../hooks/useAnalytics'

export function ExternalLinks() {
  const { trackOutboundLink } = useAnalytics()

  const handleExternalLink = (url, linkName) => {
    trackOutboundLink(url, {
      link_name: linkName,
      link_category: 'social' // or 'documentation', 'support', etc.
    })

    // Open link
    window.open(url, '_blank')
  }

  return (
    <>
      <button onClick={() => handleExternalLink('https://twitter.com/justlayme', 'twitter')}>
        Follow on Twitter
      </button>
      <button onClick={() => handleExternalLink('https://discord.com/invite/justlayme', 'discord')}>
        Join Discord
      </button>
    </>
  )
}
```

---

## Summary of Recommended Implementation

| Event | Location | Triggers | Parameters |
|-------|----------|----------|-----------|
| `login` | LoginPage | User logs in | method, signup_source |
| `sign_up` | LoginPage | User creates account | method, signup_source, referral_code |
| `page_view` | App.jsx | Route change | (automatic) |
| `chat_message_sent` | ChatPage | Message sent | character_id, message_length, character_type |
| `character_created` | NeuralCharacterBuilder | Character created | character_type, traits_count, creation_time |
| `black_mirror_analysis` | BlackMirrorPage | Analysis performed | analysis_type, participants_count, message_count |
| `premium_view` | PremiumPage | Page loads | current_tier, view_source |
| `begin_checkout` | PremiumPage | Checkout starts | tier_id, price, billing_cycle |
| `exception` | Error handling | Error occurs | description, fatal |

---

## Testing Event Tracking

### Check Events in Browser

```javascript
// In Chrome DevTools console
window.gtag.config // View GA configuration
window.dataLayer // View all events fired

// Filter for specific event
window.dataLayer.filter(e => e[0] === 'event').map(e => e[1])
```

### Verify in Google Analytics

1. Go to [Google Analytics](https://analytics.google.com/)
2. Click Admin > DebugView
3. Events should appear in real-time
4. Click on event to see parameters

---

**Last Updated:** November 16, 2024
