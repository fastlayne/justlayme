import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Helmet } from 'react-helmet-async'
import apiClient from '@/services/client'
import './LoginPage.scss' // Reuse login page styles

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('')
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      const response = await apiClient.post('/password-reset/request', {
        email: email.trim().toLowerCase()
      })

      setSuccess(true)
      setLoading(false)
    } catch (err) {
      console.error('Password reset request error:', err)

      // Handle rate limiting
      if (err.response?.status === 429) {
        setError('Too many password reset requests. Please try again later.')
      } else {
        // For security, always show success message even on error
        // This prevents email enumeration attacks
        setSuccess(true)
      }

      setLoading(false)
    }
  }

  return (
    <div className="login-page">
      <Helmet>
        <title>Forgot Password - JustLayMe</title>
        <meta name="description" content="Reset your JustLayMe account password" />
      </Helmet>

      <div className="login-container">
        <div className="login-box">
          <h1 className="login-title">Forgot Password</h1>
          <p className="login-subtitle">
            Enter your email to receive a password reset link
          </p>

          {success ? (
            <div className="success-message">
              <div className="success-icon">&#10003;</div>
              <h3>Check Your Email</h3>
              <p>
                If an account exists with <strong>{email}</strong>, you will receive
                a password reset link shortly.
              </p>
              <p className="text-sm" style={{ marginTop: '1rem', color: '#666' }}>
                The link will expire in 1 hour for security.
              </p>
              <div style={{ marginTop: '1.5rem' }}>
                <Link to="/login" className="btn-login">
                  Back to Sign In
                </Link>
              </div>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="login-form">
              <div className="form-group">
                <label htmlFor="email">Email Address</label>
                <input
                  id="email"
                  type="email"
                  placeholder="your@email.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  disabled={loading}
                  autoFocus
                />
                <p className="password-requirements" style={{ fontSize: '0.85rem', marginTop: '0.5rem' }}>
                  We'll send you a secure link to reset your password
                </p>
              </div>

              {error && <div className="error-message">{error}</div>}

              <button type="submit" className="btn-login" disabled={loading}>
                {loading ? 'Sending...' : 'Send Reset Link'}
              </button>
            </form>
          )}

          {!success && (
            <div className="login-toggle">
              <p>
                Remember your password?{' '}
                <Link to="/login" className="toggle-button">
                  Sign In
                </Link>
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
