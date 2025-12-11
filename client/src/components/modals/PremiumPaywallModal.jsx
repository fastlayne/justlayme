import { useState, useEffect } from 'react'
import { useAuth } from '@/hooks/useAuth'
import { stripeAPI } from '@/services/stripeAPI'
import './PremiumPaywallModal.scss'

/**
 * PremiumPaywallModal Component
 * Displays premium pricing and initiates Stripe checkout
 * Shows when users hit premium features
 *
 * MOBILE-OPTIMIZED VERSION:
 * - Uses Stripe Hosted Checkout for MAXIMUM mobile conversion
 * - Single modal, single action - no friction
 * - Direct redirect to Stripe's mobile-optimized payment page
 * - Large touch-friendly buttons (minimum 48px height)
 * - Trust badges and security indicators
 * - Clear pricing with no surprises
 */

export default function PremiumPaywallModal({ modalId, onClose, feature = 'this premium feature' }) {
  const { user } = useAuth()
  const [loading, setLoading] = useState(false)
  const [prices, setPrices] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    loadPricing()
  }, [])

  const loadPricing = async () => {
    try {
      const config = await stripeAPI.getConfig()
      setPrices(config.prices)
    } catch (err) {
      console.error('Failed to load pricing:', err)
      setError('Failed to load pricing information')
    }
  }

  /**
   * MOBILE-OPTIMIZED: Direct redirect to Stripe Hosted Checkout
   * No embedded forms, no second modal - just ONE click to pay
   * Stripe's hosted page is fully optimized for mobile devices
   */
  const handleUpgrade = async (priceId, planName) => {
    setLoading(true)
    setError('')

    try {
      // Verify user is logged in
      if (!user || !user.email) {
        setError('Please log in to upgrade to premium')
        setLoading(false)
        return
      }

      // Create checkout session and redirect to Stripe
      // Stripe handles EVERYTHING from here - mobile optimized!
      const { url } = await stripeAPI.createCheckoutSession(priceId, user.email)

      // Show loading state while redirecting
      // User will see "Redirecting to secure checkout..."
      window.location.href = url

    } catch (err) {
      console.error('Checkout failed:', err)
      setError(err.message || 'Failed to start checkout. Please try again.')
      setLoading(false)
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="premium-paywall-modal" onClick={(e) => e.stopPropagation()}>
        <button className="modal-close" onClick={onClose} aria-label="Close modal">✕</button>

        <div className="paywall-header">
          <div className="premium-badge">Premium</div>
          <h2>Unlock Full Access</h2>
          <p className="feature-unlock">Get {feature} and all premium features</p>
          {user && user.email && (
            <p className="user-info">{user.email}</p>
          )}
        </div>

        {/* Trust & Security Indicators */}
        <div className="trust-indicators">
          <div className="trust-badge">
            <span className="icon">🔒</span>
            <span className="text">Secure Payment</span>
          </div>
          <div className="trust-badge">
            <span className="icon">⚡</span>
            <span className="text">Instant Access</span>
          </div>
          <div className="trust-badge">
            <span className="icon">↩️</span>
            <span className="text">Cancel Anytime</span>
          </div>
        </div>

        {error && (
          <div className="error-message">
            <span className="error-icon">⚠️</span>
            <span>{error}</span>
          </div>
        )}

        {prices && prices.monthly && prices.yearly && prices.lifetime && (
          <div className="pricing-tiers">
            {/* Monthly Plan */}
            {prices.monthly && (
              <div className="pricing-card">
                <div className="plan-badge">Most Flexible</div>
                <h3>Monthly</h3>
                <div className="price">
                  <span className="amount">${(prices.monthly.amount / 100).toFixed(2)}</span>
                  <span className="period">/month</span>
                </div>
                <ul className="features">
                  <li><span className="check">✓</span> Unlimited conversations</li>
                  <li><span className="check">✓</span> All character features</li>
                  <li><span className="check">✓</span> The Grey Mirror analysis</li>
                  <li><span className="check">✓</span> Priority support</li>
                </ul>
                <button
                  className="btn-upgrade"
                  onClick={() => handleUpgrade(prices.monthly.id, 'Monthly')}
                  disabled={loading}
                  aria-label="Subscribe to Monthly Plan"
                >
                  {loading ? 'Redirecting...' : 'Start Monthly Plan'}
                </button>
              </div>
            )}

            {/* Yearly Plan - FEATURED */}
            {prices.yearly && (
              <div className="pricing-card featured">
                <div className="plan-badge">Best Value - Save 20%</div>
                <h3>Yearly</h3>
                <div className="price">
                  <span className="amount">${(prices.yearly.amount / 100).toFixed(2)}</span>
                  <span className="period">/year</span>
                </div>
                <div className="savings">2 months free compared to monthly</div>
                <ul className="features">
                  <li><span className="check">✓</span> Everything in Monthly</li>
                  <li><span className="check">✓</span> 2 months free</li>
                  <li><span className="check">✓</span> Early access to features</li>
                  <li><span className="check">✓</span> Premium badge</li>
                </ul>
                <button
                  className="btn-upgrade primary"
                  onClick={() => handleUpgrade(prices.yearly.id, 'Yearly')}
                  disabled={loading}
                  aria-label="Subscribe to Yearly Plan"
                >
                  {loading ? 'Redirecting...' : 'Get Best Value'}
                </button>
              </div>
            )}

            {/* Lifetime Plan */}
            {prices.lifetime && (
              <div className="pricing-card">
                <div className="plan-badge">One-Time Payment</div>
                <h3>Lifetime</h3>
                <div className="price">
                  <span className="amount">${(prices.lifetime.amount / 100).toFixed(2)}</span>
                  <span className="period">once</span>
                </div>
                <ul className="features">
                  <li><span className="check">✓</span> Everything in Yearly</li>
                  <li><span className="check">✓</span> Pay once, access forever</li>
                  <li><span className="check">✓</span> Lifetime updates</li>
                  <li><span className="check">✓</span> Founding member status</li>
                </ul>
                <button
                  className="btn-upgrade"
                  onClick={() => handleUpgrade(prices.lifetime.id, 'Lifetime')}
                  disabled={loading}
                  aria-label="Get Lifetime Access"
                >
                  {loading ? 'Redirecting...' : 'Get Lifetime Access'}
                </button>
              </div>
            )}
          </div>
        )}

        {!prices && !error && (
          <div className="loading-pricing">
            <div className="spinner" />
            <p>Loading pricing...</p>
          </div>
        )}

        {/* Footer with powered by Stripe badge */}
        <div className="modal-footer">
          <div className="powered-by">
            <span className="lock-icon">🔒</span>
            <span>Powered by Stripe - Industry-leading security</span>
          </div>
          <p className="money-back">30-day money-back guarantee</p>
        </div>
      </div>
    </div>
  )
}
