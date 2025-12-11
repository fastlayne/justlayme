/**
 * @deprecated This file is deprecated. Use stripeAPI.js instead.
 * Stripe Payment Service
 * Handles all Stripe payment operations for JustLayMe
 */

import { loadStripe } from '@stripe/stripe-js';

let stripePromise = null;
let stripeConfig = null;

/**
 * Initialize Stripe with publishable key from backend
 */
export const initializeStripe = async () => {
  if (stripePromise) return stripePromise;

  try {
    // Fetch Stripe configuration from backend
    const response = await fetch('/api/stripe-config');
    const config = await response.json();

    stripeConfig = config;

    if (!config.publishableKey) {
      console.error('Stripe publishable key not available');
      return null;
    }

    stripePromise = loadStripe(config.publishableKey);
    return stripePromise;
  } catch (error) {
    console.error('Failed to initialize Stripe:', error);
    return null;
  }
};

/**
 * Get Stripe configuration (prices, etc.)
 */
export const getStripeConfig = async () => {
  if (stripeConfig) return stripeConfig;

  try {
    const response = await fetch('/api/stripe-config');
    stripeConfig = await response.json();
    return stripeConfig;
  } catch (error) {
    console.error('Failed to fetch Stripe config:', error);
    throw error;
  }
};

/**
 * Create a checkout session and redirect to Stripe
 * @param {string} priceId - Stripe price ID
 * @param {string} email - User email
 * @returns {Promise<void>}
 */
export const redirectToCheckout = async (priceId, email) => {
  try {
    const response = await fetch('/api/stripe-checkout', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        priceId,
        email,
        successUrl: `${window.location.origin}/chat?premium=success`,
        cancelUrl: `${window.location.origin}/premium?cancelled=true`,
      }),
    });

    if (!response.ok) {
      throw new Error('Failed to create checkout session');
    }

    const { url } = await response.json();

    // Redirect to Stripe Checkout
    window.location.href = url;
  } catch (error) {
    console.error('Checkout error:', error);
    throw error;
  }
};

/**
 * Check subscription status for a user
 * @param {string} email - User email
 * @returns {Promise<object>} Subscription status
 */
export const checkSubscriptionStatus = async (email) => {
  try {
    const response = await fetch(`/api/subscription-status/${encodeURIComponent(email)}`);

    if (!response.ok) {
      throw new Error('Failed to check subscription status');
    }

    return await response.json();
  } catch (error) {
    console.error('Subscription status error:', error);
    throw error;
  }
};

/**
 * Cancel a subscription
 * @param {string} subscriptionId - Stripe subscription ID
 * @returns {Promise<object>} Cancellation result
 */
export const cancelSubscription = async (subscriptionId) => {
  try {
    const response = await fetch('/api/cancel-subscription', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ subscriptionId }),
    });

    if (!response.ok) {
      throw new Error('Failed to cancel subscription');
    }

    return await response.json();
  } catch (error) {
    console.error('Cancellation error:', error);
    throw error;
  }
};

/**
 * Format price for display
 * @param {number} amount - Amount in cents
 * @param {string} currency - Currency code
 * @returns {string} Formatted price
 */
export const formatPrice = (amount, currency = 'USD') => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
  }).format(amount / 100);
};

export default {
  initializeStripe,
  getStripeConfig,
  redirectToCheckout,
  checkSubscriptionStatus,
  cancelSubscription,
  formatPrice,
};
