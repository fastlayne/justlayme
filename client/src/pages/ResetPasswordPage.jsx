import { useState, useEffect } from 'react'
import { useNavigate, useSearchParams, Link } from 'react-router-dom'
import { Helmet } from 'react-helmet-async'
import { useAuth } from '@/hooks/useAuth'
import { usePageTransition } from '@/hooks/usePageTransition'
import apiClient from '@/services/client'
import './LoginPage.scss' // Reuse login page styles

export default function ResetPasswordPage() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const { setUser } = useAuth()
  const { startTransition } = usePageTransition()

  const [token, setToken] = useState('')
  const [email, setEmail] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [verifying, setVerifying] = useState(true)
  const [tokenValid, setTokenValid] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)

  // Verify token on component mount
  useEffect(() => {
    const tokenParam = searchParams.get('token')

    if (!tokenParam) {
      setError('Invalid reset link. No token provided.')
      setVerifying(false)
      return
    }

    setToken(tokenParam)
    verifyToken(tokenParam)
  }, [searchParams])

  const verifyToken = async (tokenToVerify) => {
    try {
      const response = await apiClient.get(`/password-reset/verify?token=${tokenToVerify}`)

      if (response.valid) {
        setTokenValid(true)
        setEmail(response.email)
      } else {
        setError(response.error || 'Invalid or expired reset link')
        setTokenValid(false)
      }
    } catch (err) {
      console.error('Token verification error:', err)
      setError(err.response?.data?.error || 'Invalid or expired reset link')
      setTokenValid(false)
    } finally {
      setVerifying(false)
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')

    // Validate passwords match
    if (newPassword !== confirmPassword) {
      setError('Passwords do not match')
      return
    }

    // Validate password strength (client-side check)
    const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&#])[A-Za-z\d@$!%*?&#]{8,}$/
    if (!passwordRegex.test(newPassword)) {
      setError('Password must be at least 8 characters with uppercase, lowercase, number, and special character')
      return
    }

    setLoading(true)

    try {
      const response = await apiClient.post('/password-reset/complete', {
        token,
        newPassword
      })

      if (response.success) {
        // Save auth token and user data
        localStorage.setItem('authToken', response.token)
        setUser(response.user)

        setSuccess(true)

        // Redirect to chat after 2 seconds
        setTimeout(() => {
          startTransition('/chat')
          navigate('/chat')
        }, 2000)
      }
    } catch (err) {
      console.error('Password reset error:', err)
      setError(err.response?.data?.error || 'Failed to reset password. Please try again.')
      setLoading(false)
    }
  }

  // Show loading state while verifying token
  if (verifying) {
    return (
      <div className="login-page">
        <Helmet>
          <title>Reset Password - JustLayMe</title>
        </Helmet>
        <div className="login-container">
          <div className="login-box">
            <h1 className="login-title">Verifying...</h1>
            <p className="login-subtitle">Please wait while we verify your reset link</p>
          </div>
        </div>
      </div>
    )
  }

  // Show error if token is invalid
  if (!tokenValid) {
    return (
      <div className="login-page">
        <Helmet>
          <title>Reset Password - JustLayMe</title>
        </Helmet>
        <div className="login-container">
          <div className="login-box">
            <h1 className="login-title">Invalid Link</h1>
            <div className="error-message">{error}</div>
            <div style={{ marginTop: '1.5rem' }}>
              <Link to="/forgot-password" className="btn-login">
                Request New Reset Link
              </Link>
            </div>
            <div className="login-toggle">
              <p>
                <Link to="/login" className="toggle-button">
                  Back to Sign In
                </Link>
              </p>
            </div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="login-page">
      <Helmet>
        <title>Reset Password - JustLayMe</title>
        <meta name="description" content="Create a new password for your JustLayMe account" />
      </Helmet>

      <div className="login-container">
        <div className="login-box">
          <h1 className="login-title">Reset Password</h1>
          <p className="login-subtitle">
            Create a new password for <strong>{email}</strong>
          </p>

          {success ? (
            <div className="success-message">
              <div className="success-icon">&#10003;</div>
              <h3>Password Reset Successful!</h3>
              <p>You're now logged in and will be redirected shortly...</p>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="login-form">
              <div className="form-group">
                <label htmlFor="newPassword">New Password</label>
                <input
                  id="newPassword"
                  type="password"
                  placeholder="••••••••"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  required
                  disabled={loading}
                  autoFocus
                  pattern="^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&#])[A-Za-z\d@$!%*?&#]{8,}$"
                />
                <p className="password-requirements">
                  Must include: 8+ chars, uppercase, lowercase, number, and special character (@$!%*?&#)
                </p>
              </div>

              <div className="form-group">
                <label htmlFor="confirmPassword">Confirm Password</label>
                <input
                  id="confirmPassword"
                  type="password"
                  placeholder="••••••••"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  required
                  disabled={loading}
                />
              </div>

              {error && <div className="error-message">{error}</div>}

              <button type="submit" className="btn-login" disabled={loading}>
                {loading ? 'Resetting Password...' : 'Reset Password'}
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
