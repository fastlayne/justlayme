import { useState, useEffect } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { Helmet } from 'react-helmet-async'
import apiClient from '@/services/client'
import './VerifyEmailPage.scss'

/**
 * Email Verification Page
 *
 * This page handles email verification when users click the link in their verification email.
 * Flow:
 * 1. User clicks link in email: https://justlay.me/verify-email?token=XXX
 * 2. This page extracts the token from URL params
 * 3. Sends POST request to /api/verify-email with the token
 * 4. Shows success/error message and redirects to login
 */
export default function VerifyEmailPage() {
  const [status, setStatus] = useState('verifying') // 'verifying' | 'success' | 'error' | 'expired'
  const [message, setMessage] = useState('')
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()

  useEffect(() => {
    const verifyEmail = async () => {
      const token = searchParams.get('token')

      if (!token) {
        setStatus('error')
        setMessage('No verification token provided. Please check your email link.')
        return
      }

      // Validate token format (should be 64 hex characters)
      if (!/^[a-f0-9]{64}$/.test(token)) {
        setStatus('error')
        setMessage('Invalid verification link. Please request a new verification email.')
        return
      }

      try {
        const response = await apiClient.post('/verify-email', { token })

        setStatus('success')
        setMessage(response.message || 'Your email has been verified successfully!')

        // Redirect to login after 3 seconds
        setTimeout(() => {
          navigate('/login')
        }, 3000)
      } catch (err) {
        console.error('Verification error:', err)

        // Determine error type
        if (err.message?.toLowerCase().includes('expired')) {
          setStatus('expired')
          setMessage('This verification link has expired. Please request a new one by signing up again.')
        } else if (err.message?.toLowerCase().includes('already verified')) {
          setStatus('success')
          setMessage('Your email is already verified! You can sign in now.')
          setTimeout(() => navigate('/login'), 3000)
        } else {
          setStatus('error')
          setMessage(err.message || 'Verification failed. Please try again or contact support.')
        }
      }
    }

    verifyEmail()
  }, [searchParams, navigate])

  const getStatusIcon = () => {
    switch (status) {
      case 'verifying':
        return <div className="spinner" />
      case 'success':
        return <div className="icon success">&#10003;</div>
      case 'expired':
        return <div className="icon expired">&#8987;</div>
      case 'error':
        return <div className="icon error">&#10005;</div>
      default:
        return null
    }
  }

  const getStatusTitle = () => {
    switch (status) {
      case 'verifying':
        return 'Verifying Your Email...'
      case 'success':
        return 'Email Verified!'
      case 'expired':
        return 'Link Expired'
      case 'error':
        return 'Verification Failed'
      default:
        return ''
    }
  }

  return (
    <div className="verify-email-page">
      <Helmet>
        <title>Verify Email - JustLayMe</title>
        <meta name="robots" content="noindex, nofollow" />
      </Helmet>

      <div className="verify-container">
        <div className="verify-box">
          <h1 className="verify-title">JustLay.Me</h1>

          <div className={`status-display ${status}`}>
            {getStatusIcon()}
            <h2>{getStatusTitle()}</h2>
            <p>{message}</p>

            {status === 'success' && (
              <p className="redirect-notice">Redirecting to login...</p>
            )}

            {(status === 'error' || status === 'expired') && (
              <div className="action-buttons">
                <button
                  className="btn-primary"
                  onClick={() => navigate('/login')}
                >
                  Go to Login
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
