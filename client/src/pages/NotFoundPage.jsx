import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Helmet } from 'react-helmet-async'
import { usePageTransition } from '@/hooks/usePageTransition'
import Magnet from '@/components/common/Magnet'
import LightRays from '@/components/common/LightRays'
import './NotFoundPage.scss'

/**
 * NotFoundPage Component
 * 404 error page for missing routes
 * Displays friendly error message with navigation options
 * Includes SEO meta tags with react-helmet-async
 */

export default function NotFoundPage() {
  const navigate = useNavigate()
  const { startTransition } = usePageTransition()
  const [hoveredButton, setHoveredButton] = useState(null)

  const handleNavigate = (path) => {
    startTransition(path)
    setTimeout(() => navigate(path), 100)
  }

  return (
    <>
      <Helmet>
        <title>404 - Page Not Found | JustLayMe</title>
        <meta name="description" content="The page you're looking for doesn't exist. Return to JustLayMe to continue your journey." />
        <meta name="robots" content="noindex, follow" />
        <meta property="og:title" content="404 - Page Not Found | JustLayMe" />
        <meta property="og:description" content="The page you're looking for doesn't exist. Return to JustLayMe." />
      </Helmet>

      <div className="not-found-page">
        {/* LightRays Background */}
        <LightRays
          raysOrigin="bottom-center"
          raysSpeed={0.3}
          lightSpread={0.15}
          rayLength={1.2}
          fadeDistance={1.1}
          saturation={0.8}
          mouseInfluence={0.3}
          noiseAmount={0}
          distortion={0}
          pulsating={true}
        />

        {/* Main Content */}
        <main className="not-found-content">
          <div className="container">
            {/* Error Code */}
            <div className="error-header">
              <div className="error-code">
                <span className="digit">4</span>
                <span className="digit animated">0</span>
                <span className="digit">4</span>
              </div>
            </div>

            {/* Error Message */}
            <div className="error-message-section">
              <h1 className="error-title">Oops! Page Not Found</h1>
              <p className="error-subtitle">
                The page you're looking for doesn't exist or has been moved. Don't worry, we'll help you find your way back.
              </p>
            </div>

            {/* Navigation Options */}
            <nav className="error-nav" role="navigation" aria-label="404 page navigation">
              <Magnet padding={80} magnetStrength={3}>
                <button
                  className={`btn-nav-primary ${hoveredButton === 'home' ? 'hovered' : ''}`}
                  onClick={() => handleNavigate('/')}
                  onMouseEnter={() => setHoveredButton('home')}
                  onMouseLeave={() => setHoveredButton(null)}
                >
                  <span className="btn-icon">↩</span>
                  <span className="btn-text">Back to Home</span>
                </button>
              </Magnet>

              <Magnet padding={80} magnetStrength={3}>
                <button
                  className={`btn-nav-secondary ${hoveredButton === 'chat' ? 'hovered' : ''}`}
                  onClick={() => handleNavigate('/chat')}
                  onMouseEnter={() => setHoveredButton('chat')}
                  onMouseLeave={() => setHoveredButton(null)}
                >
                  <span className="btn-icon">💬</span>
                  <span className="btn-text">Go to Chat</span>
                </button>
              </Magnet>
            </nav>

            {/* Help Section */}
            <div className="error-help">
              <p className="help-text">Looking for something specific?</p>
              <ul className="help-links" role="list">
                <li><a href="#features">Features</a></li>
                <li><a href="#pricing">Pricing</a></li>
                <li><a href="#about">About</a></li>
              </ul>
            </div>
          </div>
        </main>

        {/* Decorative Elements */}
        <div className="decoration particles">
          <div className="particle" style={{ '--delay': '0s' }} />
          <div className="particle" style={{ '--delay': '0.5s' }} />
          <div className="particle" style={{ '--delay': '1s' }} />
          <div className="particle" style={{ '--delay': '1.5s' }} />
          <div className="particle" style={{ '--delay': '2s' }} />
        </div>
      </div>
    </>
  )
}
