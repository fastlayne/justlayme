import apiClient from './client'
import { stripeAPI } from './stripeAPI'

/**
 * Payment API Service
 * Handles subscription and payment operations
 * Integrates with Stripe for payment processing
 *
 * NOTE: This file contains some duplicate functionality with stripeAPI.js
 * New code should use stripeAPI.js directly for Stripe operations
 *
 * IMPORTANT: Uses the same Stripe Checkout flow as the old frontend
 * - Backend endpoints: /api/stripe-config, /api/create-checkout-session
 * - Uses Stripe Checkout Session (hosted checkout page)
 * - Redirects to Stripe's hosted payment page
 */

/**
 * @deprecated Use stripeAPI.getConfig() instead
 * Get Stripe configuration from backend
 * Returns publishable key and price IDs
 * @returns {Promise<{publishableKey: string, prices: object, available: boolean}>}
 */
export const getStripeConfig = async () => {
  try {
    return await apiClient.get('/stripe-config')
  } catch (error) {
    console.error('Failed to fetch Stripe config:', error)
    throw error
  }
}

/**
 * Create a Stripe Checkout Session and redirect user to payment page
 * This matches the old frontend implementation using Stripe Checkout
 *
 * @param {string} priceId - Stripe price ID (monthly, yearly, or lifetime)
 * @param {string} userId - Current user ID
 * @returns {Promise<{sessionId: string, url: string}>}
 */
export const createCheckoutSession = async (priceId, userId) => {
  try {
    const response = await apiClient.post('/create-checkout-session', {
      priceId,
      userId
    })

    // Response contains: { sessionId, url }
    // url is the Stripe Checkout page URL
    return response
  } catch (error) {
    console.error('Failed to create checkout session:', error)
    throw error
  }
}

/**
 * Redirect user to Stripe Checkout page
 * This is the main payment flow - same as old frontend
 *
 * @param {string} priceId - Stripe price ID
 * @param {string} userId - Current user ID
 */
export const redirectToCheckout = async (priceId, userId) => {
  try {
    const { url } = await createCheckoutSession(priceId, userId)

    // Redirect to Stripe Checkout page
    window.location.href = url
  } catch (error) {
    console.error('Failed to redirect to checkout:', error)
    throw error
  }
}

export const paymentAPI = {
  /**
   * Get Stripe configuration
   * @returns {Promise<{publishableKey: string, prices: object, available: boolean}>}
   */
  getConfig: async () => {
    return await getStripeConfig()
  },

  /**
   * Create subscription using Stripe Checkout (old frontend method)
   * Opens Stripe's hosted checkout page
   * @param {string} plan - Plan type: 'monthly', 'yearly', or 'lifetime'
   * @param {string} userId - Current user ID
   * @returns {Promise<void>}
   */
  createSubscription: async (plan, userId) => {
    try {
      // Get Stripe config to get price IDs
      const config = await getStripeConfig()

      if (!config.available) {
        throw new Error('Payment processing is currently unavailable')
      }

      // Map plan to price ID
      let priceId
      switch (plan) {
        case 'monthly':
          priceId = config.priceMonthly
          break
        case 'yearly':
          priceId = config.priceYearly
          break
        case 'lifetime':
          priceId = config.priceLifetime
          break
        default:
          throw new Error(`Invalid plan: ${plan}`)
      }

      if (!priceId) {
        throw new Error(`Price ID not configured for plan: ${plan}`)
      }

      // Redirect to Stripe Checkout (same as old frontend)
      await redirectToCheckout(priceId, userId)
    } catch (error) {
      console.error('Failed to create subscription:', error)
      throw error
    }
  },

  /**
   * Get user's current subscription status
   * @returns {Promise<{status: string, planName: string, renewsOn: string}>}
   */
  getSubscriptionStatus: async () => {
    try {
      return await apiClient.get('/subscription')
    } catch (error) {
      console.error('Failed to fetch subscription status:', error)
      throw error
    }
  },

  /**
   * Cancel user's subscription
   * @returns {Promise<{success: boolean, cancelledAt: string}>}
   */
  cancelSubscription: async () => {
    try {
      return await apiClient.post('/cancel-subscription')
    } catch (error) {
      console.error('Failed to cancel subscription:', error)
      throw error
    }
  }
}
