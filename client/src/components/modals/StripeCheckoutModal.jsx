import { useState, useEffect } from 'react'
import { loadStripe } from '@stripe/stripe-js'
import { Elements, PaymentElement, useStripe, useElements } from '@stripe/react-stripe-js'
import './StripeCheckoutModal.scss'

/**
 * Embedded Stripe Checkout Form
 * Uses Stripe Elements and Payment Element for embedded checkout
 */
function CheckoutForm({ onSuccess, onError, onClose, email, amount, planName }) {
  const stripe = useStripe()
  const elements = useElements()
  const [isProcessing, setIsProcessing] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')

  const handleSubmit = async (event) => {
    event.preventDefault()

    if (!stripe || !elements) {
      return
    }

    setIsProcessing(true)
    setErrorMessage('')

    try {
      const { error } = await stripe.confirmPayment({
        elements,
        confirmParams: {
          return_url: `${window.location.origin}/chat?premium=success`,
        },
        redirect: 'if_required'
      })

      if (error) {
        setErrorMessage(error.message)
        onError(error.message)
      } else {
        onSuccess()
      }
    } catch (err) {
      setErrorMessage('Payment failed. Please try again.')
      onError(err.message || 'Payment failed')
    } finally {
      setIsProcessing(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="stripe-checkout-form">
      <div className="checkout-header">
        <h3>Complete Your Purchase</h3>
        <p className="plan-info">{planName} - ${(amount / 100).toFixed(2)}</p>
        <p className="email-info">Upgrading for: {email}</p>
      </div>

      <div className="payment-element-container">
        <PaymentElement
          options={{
            layout: {
              type: 'tabs',
              defaultCollapsed: false,
            },
          }}
        />
      </div>

      {errorMessage && (
        <div className="error-message">
          <span className="error-icon">⚠️</span>
          <span>{errorMessage}</span>
        </div>
      )}

      <div className="checkout-actions">
        <button
          type="submit"
          disabled={!stripe || isProcessing}
          className="btn-submit-payment"
        >
          {isProcessing ? 'Processing...' : `Pay $${(amount / 100).toFixed(2)}`}
        </button>
        <button
          type="button"
          onClick={onClose}
          className="btn-cancel"
          disabled={isProcessing}
        >
          Cancel
        </button>
      </div>

      <div className="secure-payment-info">
        <span className="lock-icon">🔒</span>
        <span>Secure payment powered by Stripe</span>
      </div>
    </form>
  )
}

/**
 * StripeCheckoutModal Component
 * Embedded modal for Stripe checkout using Payment Element
 * Supports Stripe Link for faster checkout
 */
export default function StripeCheckoutModal({
  modalId,
  onClose,
  priceId,
  email,
  amount,
  planName,
  publishableKey,
  onSuccess,
  onError
}) {
  const [stripePromise, setStripePromise] = useState(null)
  const [clientSecret, setClientSecret] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    // Load Stripe
    if (publishableKey) {
      setStripePromise(loadStripe(publishableKey))
    }
  }, [publishableKey])

  useEffect(() => {
    // Create Payment Intent
    createPaymentIntent()
  }, [priceId, email])

  const createPaymentIntent = async () => {
    try {
      setLoading(true)
      setError('')

      const response = await fetch('/api/create-payment-intent', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          priceId,
          email,
        }),
      })

      if (!response.ok) {
        throw new Error('Failed to create payment intent')
      }

      const data = await response.json()
      setClientSecret(data.clientSecret)
    } catch (err) {
      console.error('Failed to create payment intent:', err)
      setError(err.message || 'Failed to initialize checkout. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  const handleSuccess = () => {
    if (onSuccess) onSuccess()
    setTimeout(() => {
      onClose()
    }, 1000)
  }

  const handleError = (errorMsg) => {
    if (onError) onError(errorMsg)
  }

  const appearance = {
    theme: 'night',
    variables: {
      colorPrimary: '#00d4ff',
      colorBackground: '#1a1a2e',
      colorText: '#ffffff',
      colorDanger: '#ff6b6b',
      fontFamily: 'system-ui, -apple-system, sans-serif',
      borderRadius: '8px',
    },
  }

  return (
    <div className="modal-overlay stripe-checkout-overlay" onClick={onClose}>
      <div className="stripe-checkout-modal" onClick={(e) => e.stopPropagation()}>
        <button className="modal-close" onClick={onClose}>✕</button>

        {loading && (
          <div className="loading-checkout">
            <div className="spinner" />
            <p>Initializing secure checkout...</p>
          </div>
        )}

        {error && (
          <div className="error-container">
            <div className="error-message">
              <span className="error-icon">⚠️</span>
              <span>{error}</span>
            </div>
            <button onClick={createPaymentIntent} className="btn-retry">
              Try Again
            </button>
          </div>
        )}

        {!loading && !error && clientSecret && stripePromise && (
          <Elements
            stripe={stripePromise}
            options={{ clientSecret, appearance }}
          >
            <CheckoutForm
              onSuccess={handleSuccess}
              onError={handleError}
              onClose={onClose}
              email={email}
              amount={amount}
              planName={planName}
            />
          </Elements>
        )}
      </div>
    </div>
  )
}
