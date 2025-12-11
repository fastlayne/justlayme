/**
 * useAnalytics Hook
 *
 * Provides analytics functionality throughout the application
 * Automatically tracks page views on route changes
 * Exports trackEvent and trackPageView functions for custom event tracking
 *
 * Usage:
 * const { trackEvent, trackPageView } = useAnalytics()
 * trackEvent('button_click', { button_name: 'submit' })
 */

import { useEffect } from 'react'
import { useLocation } from 'react-router-dom'
import * as analyticsService from '../services/analytics'

export const useAnalytics = () => {
  const location = useLocation()

  // Track page views whenever the location (route) changes
  useEffect(() => {
    // Get the current page path and title
    const pagePath = location.pathname
    const pageTitle = getPageTitle(pagePath)

    // Track the page view
    analyticsService.trackPageView(pagePath, pageTitle)
  }, [location.pathname])

  /**
   * Get a friendly page title based on the current path
   * Used for GA4 page_title parameter
   */
  const getPageTitle = (pathname) => {
    const pathToTitle = {
      '/': 'Home',
      '/login': 'Login',
      '/chat': 'Chat',
      '/grey-mirror': 'The Grey Mirror Analysis',
      '/premium': 'Premium',
    }

    return pathToTitle[pathname] || pathname
  }

  /**
   * Track a custom event
   *
   * @param {string} eventName - Event name (snake_case)
   * @param {object} eventData - Event parameters
   *
   * @example
   * trackEvent('chat_message_sent', { character_id: 'char_123' })
   */
  const trackEvent = (eventName, eventData = {}) => {
    analyticsService.trackEvent(eventName, eventData)
  }

  /**
   * Manually track a page view (usually not needed, automatic via useEffect)
   *
   * @param {string} pagePath - Page path
   * @param {string} pageTitle - Page title
   * @param {object} additionalParams - Additional GA4 parameters
   */
  const trackPageViewManual = (pagePath, pageTitle = '', additionalParams = {}) => {
    analyticsService.trackPageView(pagePath, pageTitle, additionalParams)
  }

  /**
   * Set user properties for GA4 segmentation
   *
   * @param {object} userProperties - User properties
   *
   * @example
   * setUserProperties({ user_type: 'premium', signup_date: '2024-01-15' })
   */
  const setUserProperties = (userProperties = {}) => {
    analyticsService.setUserProperties(userProperties)
  }

  /**
   * Set user ID (typically after authentication)
   *
   * @param {string} userId - User ID from auth system
   */
  const setUserId = (userId) => {
    analyticsService.setUserId(userId)
  }

  // Export analytics functions and helpers
  return {
    trackEvent,
    trackPageView: trackPageViewManual,
    setUserProperties,
    setUserId,
    trackLogin: analyticsService.trackLogin,
    trackSignUp: analyticsService.trackSignUp,
    trackChatMessage: analyticsService.trackChatMessage,
    trackCharacterCreated: analyticsService.trackCharacterCreated,
    trackBlackMirrorAccess: analyticsService.trackBlackMirrorAccess,
    trackPremiumView: analyticsService.trackPremiumView,
    trackPurchase: analyticsService.trackPurchase,
    trackBeginCheckout: analyticsService.trackBeginCheckout,
    trackException: analyticsService.trackException,
    trackOutboundLink: analyticsService.trackOutboundLink,
    trackFeatureUsage: analyticsService.trackFeatureUsage,
  }
}

export default useAnalytics
