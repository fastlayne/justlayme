import './LoadingSpinner.scss'

/**
 * LoadingSpinner Component
 * Reusable loading spinner for Suspense fallbacks and loading states
 * Supports different sizes and centered/inline modes
 */

export default function LoadingSpinner({
  size = 'medium',
  message = 'Loading...',
  centered = true
}) {
  return (
    <div className={`loading-spinner ${centered ? 'centered' : ''}`}>
      <div className={`spinner spinner-${size}`}>
        <div className="spinner-ring"></div>
        <div className="spinner-ring"></div>
        <div className="spinner-ring"></div>
      </div>
      {message && <p className="loading-message">{message}</p>}
    </div>
  )
}
