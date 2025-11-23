import { useEffect } from 'react'
import { useLocation } from 'react-router-dom'
import { usePageTransition } from '@/hooks/usePageTransition'
import './TransitionWrapper.scss'

export default function TransitionWrapper({ children }) {
  const location = useLocation()
  const { isTransitioning, endTransition } = usePageTransition()

  // Determine logo text based on current page
  const logoText = location.pathname === '/grey-mirror' ? 'The Grey Mirror' : 'JustLayMe'

  // ARCHITECTURAL FIX: Add key to force remount on location change
  // This ensures Routes component sees the location update
  console.log('[TransitionWrapper] Rendering with location:', location.pathname)

  // Handle transition completion
  useEffect(() => {
    if (isTransitioning) {
      // Portal overlay animation duration is 1200ms (logo fade in 800ms + stay 400ms + fade out 400ms)
      // End transition as overlay fades out
      const timer = setTimeout(() => {
        endTransition()
      }, 1200)

      return () => clearTimeout(timer)
    }
  }, [isTransitioning, endTransition])

  return (
    <div className="transition-wrapper">
      {/* Portal overlay appears during transition */}
      {isTransitioning && (
        <div className="page-transition-overlay portal-glow">
          {/* JustLayMe Logo with fade animation */}
          <div className="logo-container">
            <div className="justlayme-logo">
              <span className="logo-text">{logoText}</span>
              <span className="logo-subtitle">{logoText === 'The Grey Mirror' ? 'Deep Analysis' : 'AI Chat'}</span>
            </div>
          </div>
        </div>
      )}

      {/* Page content with transition animations */}
      <div className={`route-content ${isTransitioning ? 'transitioning-out' : 'transitioning-in'}`}>
        {children}
      </div>
    </div>
  )
}
