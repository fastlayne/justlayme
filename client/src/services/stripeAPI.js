import apiClient from './client'

/**
 * Stripe Payment API Service
 * Handles all Stripe-related API calls for premium features
 */

export const stripeAPI = {
  /**
   * Get Stripe configuration (publishable key, prices)
   * @returns {Promise<Object>} Stripe config with prices
   */
  getConfig: async () => {
    try {
      return await apiClient.get('/stripe-config')
    } catch (error) {
      console.error('Failed to fetch Stripe config:', error)
      throw error
    }
  },

  /**
   * Create Stripe checkout session for subscription
   * @param {string} priceId - Stripe price ID (monthly/yearly/lifetime)
   * @param {string} email - User email
   * @returns {Promise<{url: string}>} Checkout session URL
   */
  createCheckoutSession: async (priceId, email) => {
    try {
      return await apiClient.post('/stripe-checkout', {
        priceId,
        email,
        successUrl: `${window.location.origin}/chat?premium=success`,
        cancelUrl: `${window.location.origin}/chat?premium=cancelled`
      })
    } catch (error) {
      console.error('Failed to create checkout session:', error)
      throw error
    }
  },

  /**
   * Get user's subscription status
   * @returns {Promise<Object>} Subscription details
   */
  getSubscriptionStatus: async () => {
    try {
      return await apiClient.get('/subscription-status')
    } catch (error) {
      console.error('Failed to fetch subscription status:', error)
      throw error
    }
  },

  /**
   * Cancel user's subscription
   * @param {string} subscriptionId
   * @returns {Promise<Object>} Updated subscription
   */
  cancelSubscription: async (subscriptionId) => {
    try {
      return await apiClient.post('/cancel-subscription', { subscriptionId })
    } catch (error) {
      console.error('Failed to cancel subscription:', error)
      throw error
    }
  },

  /**
   * Create Payment Intent for embedded checkout
   * @param {string} priceId - Stripe price ID (monthly/yearly/lifetime)
   * @param {string} email - User email
   * @returns {Promise<{clientSecret: string}>} Payment Intent client secret
   */
  createPaymentIntent: async (priceId, email) => {
    try {
      return await apiClient.post('/create-payment-intent', {
        priceId,
        email
      })
    } catch (error) {
      console.error('Failed to create payment intent:', error)
      throw error
    }
  }
}
