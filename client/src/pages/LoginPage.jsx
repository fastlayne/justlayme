import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Helmet } from 'react-helmet-async'
import { useAuth } from '@/hooks/useAuth'
import { usePageTransition } from '@/hooks/usePageTransition'
import apiClient from '@/services/client'
import './LoginPage.scss'

// Conditionally import Google OAuth components
let GoogleLogin
try {
  const googleOAuth = require('@react-oauth/google')
  GoogleLogin = googleOAuth.GoogleLogin
} catch {
  GoogleLogin = null
}

export default function LoginPage() {
  const [isLogin, setIsLogin] = useState(true)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [username, setUsername] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const navigate = useNavigate()
  const { login, signup, setUser } = useAuth()
  const { startTransition } = usePageTransition()

  const [showVerificationMessage, setShowVerificationMessage] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      if (isLogin) {
        // Login flow
        console.log('Attempting login with email:', email)
        const result = await login(email, password)
        console.log('Login successful:', result)

        // Redirect to chat with transition
        startTransition('/chat')
        setTimeout(() => navigate('/chat'), 100)
      } else {
        // Signup flow
        console.log('Attempting signup with email:', email, 'username:', username)
        const result = await signup(email, password, username)
        console.log('Signup successful:', result)

        // Show verification message after successful signup
        setShowVerificationMessage(true)
        setLoading(false)

        // Auto-redirect to chat after 3 seconds (they can still use the app while unverified)
        setTimeout(() => {
          startTransition('/chat')
          navigate('/chat')
        }, 3000)
      }
    } catch (err) {
      console.error('Auth error:', err)

      // Provide helpful error messages
      let errorMessage = err.message || 'Authentication failed. Please try again.'

      if (isLogin) {
        // Check for common login errors and provide helpful suggestions
        if (errorMessage.toLowerCase().includes('not found') ||
            errorMessage.toLowerCase().includes('invalid') ||
            errorMessage.toLowerCase().includes('no user')) {
          errorMessage = "Account not found. Don't have an account? Click 'Sign Up' below to create one."
        } else if (errorMessage.toLowerCase().includes('password')) {
          errorMessage = 'Incorrect password. Please try again or reset your password.'
        }
      } else {
        // Signup errors
        if (errorMessage.toLowerCase().includes('already exists') ||
            errorMessage.toLowerCase().includes('already registered')) {
          errorMessage = "An account with this email already exists. Try signing in instead."
        } else if (errorMessage.toLowerCase().includes('validation failed') || err.details) {
          // Show specific validation errors
          if (err.details && Array.isArray(err.details)) {
            errorMessage = err.details.map(d => d.message).join('\n')
          } else if (err.response?.data?.details) {
            errorMessage = err.response.data.details.map(d => d.message).join('\n')
          }
        }
      }

      setError(errorMessage)
      setLoading(false)
    }
  }

  // Google OAuth login handler - receives ID token from Google
  const handleGoogleSuccess = async (credentialResponse) => {
    setLoading(true)
    setError('')

    try {
      console.log('Google sign-in success, sending to backend...')

      // Send the ID token to backend for verification
      const response = await apiClient.post('/auth/google', {
        credential: credentialResponse.credential
      })

      // Save auth token and user info
      localStorage.setItem('authToken', response.token)
      setUser(response.user)

      // Redirect to chat
      startTransition('/chat')
      setTimeout(() => navigate('/chat'), 100)
    } catch (err) {
      console.error('Google login error:', err)
      setError(err.message || 'Google sign-in failed. Please try again.')
      setLoading(false)
    }
  }

  const handleGoogleError = () => {
    console.error('Google sign-in failed')
    setError('Google sign-in failed. Please try again.')
    setLoading(false)
  }

  // Show Google OAuth button only if GoogleLogin component is available
  const showGoogleButton = !!GoogleLogin

  return (
    <div className="login-page">
      <Helmet>
        <title>Sign In to JustLayMe - Unfiltered AI Chat</title>
        <meta name="description" content="Log in to your JustLayMe account to access your AI conversations, custom characters, and The Grey Mirror analysis tool." />
        <link rel="canonical" href="https://justlay.me/login" />
        <meta property="og:title" content="Sign In to JustLayMe - Unfiltered AI Chat" />
        <meta property="og:description" content="Log in to your JustLayMe account to access your AI conversations, custom characters, and The Grey Mirror analysis tool." />
        <meta property="og:url" content="https://justlay.me/login" />
        <meta property="og:type" content="website" />
        <meta property="og:image" content="https://justlay.me/og-image.jpg" />
        <meta property="og:image:width" content="1200" />
        <meta property="og:image:height" content="630" />
        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:title" content="Sign In to JustLayMe - Unfiltered AI Chat" />
        <meta name="twitter:description" content="Log in to your JustLayMe account to access your AI conversations, custom characters, and The Grey Mirror analysis tool." />
        <meta name="twitter:image" content="https://justlay.me/twitter-image.jpg" />
      </Helmet>

      <div className="login-container">
        <div className="login-box">
          <h1 className="login-title">Justlay.Me</h1>
          <p className="login-subtitle">Unfiltered AI Conversations</p>

          {/* Show verification success message after signup */}
          {showVerificationMessage && (
            <div className="success-message">
              <div className="success-icon">&#10003;</div>
              <h3>Account Created!</h3>
              <p>Check your email ({email}) for a verification link.</p>
              <p className="redirect-notice">Redirecting to chat in a moment...</p>
            </div>
          )}

          {/* Google OAuth - show FIRST if configured */}
          {showGoogleButton && (
            <>
              <div className="google-signin-wrapper">
                <GoogleLogin
                  onSuccess={handleGoogleSuccess}
                  onError={handleGoogleError}
                  theme="filled_blue"
                  size="large"
                  text={isLogin ? "signin_with" : "signup_with"}
                  width="100%"
                  logo_alignment="left"
                />
              </div>

              <div className="divider">
                <span>OR</span>
              </div>
            </>
          )}

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
              />
            </div>

            {!isLogin && (
              <div className="form-group">
                <label htmlFor="username">Username</label>
                <input
                  id="username"
                  type="text"
                  placeholder="Choose a username"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  required
                  disabled={loading}
                />
              </div>
            )}

            <div className="form-group">
              <label htmlFor="password">Password</label>
              <input
                id="password"
                type="password"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                disabled={loading}
                pattern={!isLogin ? "^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&#])[A-Za-z\d@$!%*?&#]{8,}$" : undefined}
              />
              {!isLogin && (
                <p className="password-requirements">
                  Must include: 8+ chars, uppercase, lowercase, number, and special character (@$!%*?&#)
                </p>
              )}
              {isLogin && (
                <div style={{ textAlign: 'right', marginTop: '0.5rem' }}>
                  <button
                    type="button"
                    className="toggle-button"
                    onClick={() => navigate('/forgot-password')}
                    disabled={loading}
                    style={{ fontSize: '0.9rem', padding: '0' }}
                  >
                    Forgot password?
                  </button>
                </div>
              )}
            </div>

            {error && <div className="error-message">{error}</div>}

            <button type="submit" className="btn-login" disabled={loading}>
              {loading ? 'Processing...' : isLogin ? 'Sign In' : 'Create Account'}
            </button>
          </form>

          <div className="login-toggle">
            <p>
              {isLogin ? "Don't have an account? " : 'Already have an account? '}
              <button
                type="button"
                className="toggle-button"
                onClick={() => {
                  setIsLogin(!isLogin)
                  setError('')
                }}
                disabled={loading}
              >
                {isLogin ? 'Sign Up' : 'Sign In'}
              </button>
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
