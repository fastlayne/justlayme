import { Component } from 'react'
import './ErrorBoundary.scss'

/**
 * ErrorBoundary Component
 *
 * Catches JavaScript errors anywhere in the component tree and displays a fallback UI
 * instead of crashing the entire application. Critical for production stability.
 *
 * Usage:
 * <ErrorBoundary>
 *   <YourComponent />
 * </ErrorBoundary>
 *
 * Features:
 * - Catches rendering errors, lifecycle errors, and constructor errors
 * - Logs errors to console for debugging
 * - Provides user-friendly error message
 * - Offers recovery mechanism (reload/reset)
 * - Maintains error state until user action
 */
class ErrorBoundary extends Component {
  constructor(props) {
    super(props)
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null,
      errorCount: 0
    }
  }

  /**
   * Update state when error is caught
   * This lifecycle method is called after an error has been thrown by a descendant component
   */
  static getDerivedStateFromError(error) {
    return { hasError: true }
  }

  /**
   * Log error details
   * This lifecycle method is called after an error has been thrown by a descendant component
   * @param {Error} error - The error that was thrown
   * @param {object} errorInfo - Object with componentStack key containing component trace
   */
  componentDidCatch(error, errorInfo) {
    // Log error details for debugging
    console.error('ErrorBoundary caught an error:', error)
    console.error('Component stack:', errorInfo.componentStack)

    // Update state with error details
    this.setState(prevState => ({
      error,
      errorInfo,
      errorCount: prevState.errorCount + 1
    }))

    // In production, you might want to log to an error reporting service
    // Example: logErrorToService(error, errorInfo)
  }

  /**
   * Reset error state and allow retry
   * Clears error state and attempts to re-render the component tree
   */
  handleReset = () => {
    this.setState({
      hasError: false,
      error: null,
      errorInfo: null
    })
  }

  /**
   * Full page reload as fallback recovery
   * Used when simple reset doesn't work
   */
  handleReload = () => {
    window.location.reload()
  }

  render() {
    if (this.state.hasError) {
      // Custom fallback UI
      const { error, errorInfo, errorCount } = this.state
      const { fallback } = this.props

      // If custom fallback provided, use it
      if (fallback) {
        return typeof fallback === 'function'
          ? fallback({ error, errorInfo, reset: this.handleReset, reload: this.handleReload })
          : fallback
      }

      // Default error UI
      return (
        <div className="error-boundary">
          <div className="error-boundary-content">
            <div className="error-icon">⚠️</div>

            <h1 className="error-title">
              Oops! Something went wrong
            </h1>

            <p className="error-message">
              We encountered an unexpected error. Don't worry, your data is safe.
            </p>

            {/* Show error details in development */}
            {process.env.NODE_ENV === 'development' && error && (
              <details className="error-details">
                <summary>Error Details (Development Only)</summary>
                <div className="error-stack">
                  <p><strong>Error:</strong> {error.toString()}</p>
                  {errorInfo && (
                    <pre>{errorInfo.componentStack}</pre>
                  )}
                </div>
              </details>
            )}

            {/* Recovery actions */}
            <div className="error-actions">
              <button
                className="btn-primary"
                onClick={this.handleReset}
              >
                Try Again
              </button>

              <button
                className="btn-secondary"
                onClick={this.handleReload}
              >
                Reload Page
              </button>
            </div>

            {/* Show retry count if multiple errors */}
            {errorCount > 1 && (
              <p className="error-count">
                Error occurred {errorCount} times. If this persists, try reloading the page.
              </p>
            )}
          </div>
        </div>
      )
    }

    // No error, render children normally
    return this.props.children
  }
}

export default ErrorBoundary
