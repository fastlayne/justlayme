/**
 * Google Analytics 4 (GA4) Service
 *
 * Provides functions to track events, page views, user properties, and conversions
 * to Google Analytics 4. Works seamlessly in development mode when GA is not configured.
 *
 * Environment Variable Required:
 * VITE_GA_MEASUREMENT_ID - Your Google Analytics 4 Measurement ID (e.g., G-XXXXXXXXXX)
 */

/**
 * Check if Google Analytics is available and configured
 */
const isGAAvailable = () => {
  return typeof window !== 'undefined' && typeof window.gtag === 'function'
}

/**
 * Initialize Google Analytics with the measurement ID
 * This function should be called once at application startup
 *
 * @param {string} measurementId - GA4 Measurement ID (e.g., G-XXXXXXXXXX)
 * @returns {boolean} - True if initialization was successful, false otherwise
 */
export const initializeGA = (measurementId) => {
  if (!measurementId || measurementId === 'G-XXXXXXXXXX') {
    console.warn(
      'Google Analytics not configured. Set VITE_GA_MEASUREMENT_ID environment variable with your GA4 Measurement ID.'
    )
    return false
  }

  if (typeof window === 'undefined') {
    console.warn('Google Analytics initialization attempted in non-browser environment')
    return false
  }

  try {
    // Create dataLayer if it doesn't exist
    window.dataLayer = window.dataLayer || []

    // Create gtag function
    if (typeof window.gtag === 'undefined') {
      window.gtag = function () {
        window.dataLayer.push(arguments)
      }
    }

    // Set default properties
    window.gtag('js', new Date())
    window.gtag('config', measurementId, {
      allow_google_signals: true,
      allow_ad_personalization_signals: true,
    })

    console.log('Google Analytics initialized with measurement ID:', measurementId)
    return true
  } catch (error) {
    console.error('Error initializing Google Analytics:', error)
    return false
  }
}

/**
 * Track a page view event
 * Automatically called when routes change with useAnalytics hook
 *
 * @param {string} pagePath - The page path (e.g., '/chat', '/premium')
 * @param {string} pageTitle - The page title for GA4
 * @param {object} additionalParams - Additional GA4 parameters (optional)
 */
export const trackPageView = (pagePath, pageTitle = '', additionalParams = {}) => {
  if (!isGAAvailable()) {
    console.debug('GA not available, skipping page view:', pagePath)
    return
  }

  try {
    window.gtag('config', window.gtag.measurementId || '', {
      page_path: pagePath,
      page_title: pageTitle,
      ...additionalParams,
    })
  } catch (error) {
    console.error('Error tracking page view:', error)
  }
}

/**
 * Track custom events
 * Use this for tracking user actions like button clicks, form submissions, etc.
 *
 * @param {string} eventName - The event name (snake_case recommended by GA4)
 * @param {object} eventData - Event parameters as key-value pairs
 *
 * @example
 * trackEvent('login', { method: 'google' })
 * trackEvent('chat_message_sent', { character_id: 'char_123', message_length: 150 })
 * trackEvent('character_created', { character_type: 'custom' })
 */
export const trackEvent = (eventName, eventData = {}) => {
  if (!isGAAvailable()) {
    console.debug('GA not available, skipping event:', eventName, eventData)
    return
  }

  try {
    window.gtag('event', eventName, eventData)
  } catch (error) {
    console.error('Error tracking event:', error)
  }
}

/**
 * Set user properties
 * Use this to identify and segment users in GA4
 *
 * @param {object} userProperties - User property key-value pairs
 *
 * @example
 * setUserProperties({
 *   user_type: 'premium',
 *   signup_date: '2024-01-15'
 * })
 */
export const setUserProperties = (userProperties = {}) => {
  if (!isGAAvailable()) {
    console.debug('GA not available, skipping user properties:', userProperties)
    return
  }

  try {
    window.gtag('set', userProperties)
  } catch (error) {
    console.error('Error setting user properties:', error)
  }
}

/**
 * Track user ID for cross-platform tracking
 * Call this after user authentication
 *
 * @param {string} userId - The authenticated user ID
 */
export const setUserId = (userId) => {
  if (!isGAAvailable()) {
    console.debug('GA not available, skipping user ID:', userId)
    return
  }

  try {
    window.gtag('set', { 'user_id': userId })
  } catch (error) {
    console.error('Error setting user ID:', error)
  }
}

/**
 * Track login event
 *
 * @param {string} method - Login method (e.g., 'google', 'email', 'password')
 * @param {object} additionalData - Additional event data (optional)
 */
export const trackLogin = (method = 'email', additionalData = {}) => {
  trackEvent('login', {
    method,
    ...additionalData,
  })
}

/**
 * Track sign up event
 *
 * @param {string} method - Sign up method (e.g., 'google', 'email')
 * @param {object} additionalData - Additional event data (optional)
 */
export const trackSignUp = (method = 'email', additionalData = {}) => {
  trackEvent('sign_up', {
    method,
    ...additionalData,
  })
}

/**
 * Track chat message sent event
 *
 * @param {object} data - Event data (character_id, message_length, etc.)
 */
export const trackChatMessage = (data = {}) => {
  trackEvent('chat_message_sent', {
    timestamp: new Date().toISOString(),
    ...data,
  })
}

/**
 * Track character creation event
 *
 * @param {object} data - Character data (type, name, etc.)
 */
export const trackCharacterCreated = (data = {}) => {
  trackEvent('character_created', {
    timestamp: new Date().toISOString(),
    ...data,
  })
}

/**
 * Track The Grey Mirror analysis access
 *
 * @param {object} data - Analysis data (analysis_type, etc.)
 */
export const trackBlackMirrorAccess = (data = {}) => {
  trackEvent('black_mirror_analysis', {
    timestamp: new Date().toISOString(),
    ...data,
  })
}

/**
 * Track premium page view
 *
 * @param {object} data - Additional data (subscription_tier, etc.)
 */
export const trackPremiumView = (data = {}) => {
  trackEvent('premium_view', {
    timestamp: new Date().toISOString(),
    ...data,
  })
}

/**
 * Track purchase/subscription event
 *
 * @param {object} data - Purchase data (value, currency, tier, etc.)
 */
export const trackPurchase = (data = {}) => {
  trackEvent('purchase', {
    timestamp: new Date().toISOString(),
    ...data,
  })
}

/**
 * Track purchase/subscription begin event
 *
 * @param {object} data - Data about the subscription started
 */
export const trackBeginCheckout = (data = {}) => {
  trackEvent('begin_checkout', {
    timestamp: new Date().toISOString(),
    ...data,
  })
}

/**
 * Track error/exception
 *
 * @param {string} errorMessage - Description of the error
 * @param {boolean} isFatal - Whether the error is fatal
 */
export const trackException = (errorMessage, isFatal = false) => {
  trackEvent('exception', {
    description: errorMessage,
    fatal: isFatal,
  })
}

/**
 * Track scroll depth (how far down the page user scrolled)
 *
 * @param {number} scrollDepth - Percentage of page scrolled (0-100)
 */
export const trackScrollDepth = (scrollDepth) => {
  trackEvent('scroll_depth', {
    value: Math.round(scrollDepth),
  })
}

/**
 * Track video/media engagement
 *
 * @param {string} action - Action type (play, pause, complete)
 * @param {object} data - Media data (title, duration, etc.)
 */
export const trackMediaEvent = (action, data = {}) => {
  trackEvent(`video_${action}`, {
    timestamp: new Date().toISOString(),
    ...data,
  })
}

/**
 * Track outbound link clicks
 *
 * @param {string} linkUrl - URL being clicked
 * @param {object} additionalData - Additional event data
 */
export const trackOutboundLink = (linkUrl, additionalData = {}) => {
  trackEvent('click_outbound_link', {
    link_url: linkUrl,
    timestamp: new Date().toISOString(),
    ...additionalData,
  })
}

/**
 * Track feature usage
 *
 * @param {string} featureName - Name of the feature
 * @param {object} data - Additional feature data
 */
export const trackFeatureUsage = (featureName, data = {}) => {
  trackEvent('feature_usage', {
    feature_name: featureName,
    timestamp: new Date().toISOString(),
    ...data,
  })
}

export default {
  initializeGA,
  trackPageView,
  trackEvent,
  setUserProperties,
  setUserId,
  trackLogin,
  trackSignUp,
  trackChatMessage,
  trackCharacterCreated,
  trackBlackMirrorAccess,
  trackPremiumView,
  trackPurchase,
  trackBeginCheckout,
  trackException,
  trackScrollDepth,
  trackMediaEvent,
  trackOutboundLink,
  trackFeatureUsage,
  isGAAvailable,
}
