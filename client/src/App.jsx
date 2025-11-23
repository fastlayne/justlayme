import { useEffect, lazy, Suspense } from 'react'
import { BrowserRouter as Router, Routes, Route, useNavigate, Link, useLocation } from 'react-router-dom'
import { GoogleOAuthProvider } from '@react-oauth/google'
import * as analyticsService from './services/analytics'

// Eager load critical pages (IndexPage and LoginPage for fast initial load)
import IndexPage from './pages/IndexPage'
import LoginPage from './pages/LoginPage'

// Lazy load feature pages with intelligent preloading (PERFORMANCE OPTIMIZATION)
const ChatPage = lazy(() => import('./pages/ChatPage'))
const BlackMirrorPage = lazy(() => import('./pages/BlackMirrorPage'))
const PremiumPage = lazy(() => import('./pages/PremiumPage'))
const NotFoundPage = lazy(() => import('./pages/NotFoundPage'))
const VerifyEmailPage = lazy(() => import('./pages/VerifyEmailPage'))

// PERFORMANCE OPTIMIZATION: Preload routes on user interaction
const preloadChatPage = () => import('./pages/ChatPage')
const preloadBlackMirrorPage = () => import('./pages/BlackMirrorPage')
const preloadPremiumPage = () => import('./pages/PremiumPage')

// Loading component
import LoadingSpinner from './components/common/LoadingSpinner'

// Page Transition
import { PageTransitionProvider } from './contexts/PageTransitionContext'
import TransitionWrapper from './components/TransitionWrapper'

// Context Providers
import { AuthProvider } from './contexts/AuthContext'
import { ChatProvider } from './contexts/ChatContext'
import { CharacterProvider } from './contexts/CharacterContext'
import { UIProvider } from './contexts/UIContext'
import { BlackMirrorProvider } from './contexts/BlackMirrorContext'

// Modal System
import ModalRenderer from './components/ModalRenderer'

// Error Handling
import ErrorBoundary from './components/ErrorBoundary'

// Premium Target Cursor
import TargetCursor from './components/common/TargetCursor'

// Google OAuth Client ID (from environment variable)
const GOOGLE_CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID || ''

// Google Analytics 4 Measurement ID (from environment variable)
const GA_MEASUREMENT_ID = import.meta.env.VITE_GA_MEASUREMENT_ID || 'G-XXXXXXXXXX'

// Initialize Google Analytics on app startup
analyticsService.initializeGA(GA_MEASUREMENT_ID)

/**
 * AppContent Component
 * Inner component with Router context for auth event handling
 */
function AppContent() {
  const navigate = useNavigate()
  const location = useLocation()

  // Track page views on route changes
  useEffect(() => {
    const pagePath = location.pathname
    const pageTitle = getPageTitle(pagePath)
    analyticsService.trackPageView(pagePath, pageTitle)
  }, [location.pathname])

  /**
   * Get friendly page title for GA4
   */
  const getPageTitle = (pathname) => {
    const pathToTitle = {
      '/': 'Home',
      '/login': 'Login',
      '/chat': 'Chat',
      '/grey-mirror': 'The Grey Mirror Analysis',
      '/premium': 'Premium',
      '/verify-email': 'Email Verification',
    }
    return pathToTitle[pathname] || pathname
  }

  // Listen for unauthorized auth events (401 responses)
  useEffect(() => {
    const handleAuthUnauthorized = (event) => {
      console.warn('Session expired, redirecting to home')
      navigate('/')
    }

    window.addEventListener('auth:unauthorized', handleAuthUnauthorized)
    return () => window.removeEventListener('auth:unauthorized', handleAuthUnauthorized)
  }, [navigate])

  // PERFORMANCE OPTIMIZATION: Preload routes based on user auth state
  useEffect(() => {
    const token = localStorage.getItem('authToken')
    if (token) {
      // User is logged in, preload chat and black mirror pages
      setTimeout(() => {
        preloadChatPage()
        preloadBlackMirrorPage()
      }, 1000)
    }
  }, [])

  // Global error handler for unhandled promise rejections
  useEffect(() => {
    const handleUnhandledRejection = (event) => {
      console.error('[Global] Unhandled promise rejection:', event.reason)
      // Track unhandled rejections in analytics
      analyticsService.trackException(event.reason?.message || 'Unhandled promise rejection', false)
    }

    window.addEventListener('unhandledrejection', handleUnhandledRejection)
    return () => window.removeEventListener('unhandledrejection', handleUnhandledRejection)
  }, [])

  return (
    <TransitionWrapper>
      <Routes>
        <Route path="/" element={<IndexPage />} />
        <Route path="/login" element={<LoginPage />} />
        <Route
          path="/chat"
          element={
            <ErrorBoundary>
              <Suspense fallback={<LoadingSpinner message="Loading Chat..." />}>
                <ChatPage />
              </Suspense>
            </ErrorBoundary>
          }
        />
        <Route
          path="/grey-mirror"
          element={
            <ErrorBoundary>
              <Suspense fallback={<LoadingSpinner message="Loading The Grey Mirror..." />}>
                <BlackMirrorPage />
              </Suspense>
            </ErrorBoundary>
          }
        />
        <Route
          path="/premium"
          element={
            <ErrorBoundary>
              <Suspense fallback={<LoadingSpinner message="Loading Premium..." />}>
                <PremiumPage />
              </Suspense>
            </ErrorBoundary>
          }
        />
        <Route
          path="/verify-email"
          element={
            <ErrorBoundary>
              <Suspense fallback={<LoadingSpinner message="Verifying Email..." />}>
                <VerifyEmailPage />
              </Suspense>
            </ErrorBoundary>
          }
        />
        {/* 404 Catch-all route - must be last */}
        <Route
          path="*"
          element={
            <ErrorBoundary>
              <Suspense fallback={<LoadingSpinner message="Loading..." />}>
                <NotFoundPage />
              </Suspense>
            </ErrorBoundary>
          }
        />
      </Routes>
    </TransitionWrapper>
  )
}

/**
 * App Component
 * Root application component with all providers wrapped
 * Provider hierarchy (order matters):
 * 1. PageTransitionProvider - Page transition state
 * 2. AuthProvider - Authentication and user session
 * 3. ChatProvider - Chat messages and conversations
 * 4. CharacterProvider - Character management
 * 5. UIProvider - Modal, sidebar, notification state
 * 6. BlackMirrorProvider - The Grey Mirror analysis state
 * 7. Router - React Router
 * 8. AppContent - Auth event handling and routes
 */

function App() {
  // Conditionally wrap with GoogleOAuthProvider only if client ID is configured
  const AppProviders = ({ children }) => {
    if (GOOGLE_CLIENT_ID && GOOGLE_CLIENT_ID.trim() !== '') {
      return (
        <GoogleOAuthProvider clientId={GOOGLE_CLIENT_ID}>
          {children}
        </GoogleOAuthProvider>
      )
    }
    // If no Google client ID, render without Google OAuth
    return <>{children}</>
  }

  return (
    <AppProviders>
      <PageTransitionProvider>
        <AuthProvider>
          <ChatProvider>
            <CharacterProvider>
              <UIProvider>
                <BlackMirrorProvider>
                  <Router>
                    <TargetCursor />
                    <AppContent />
                    <ModalRenderer />
                  </Router>
                </BlackMirrorProvider>
              </UIProvider>
            </CharacterProvider>
          </ChatProvider>
        </AuthProvider>
      </PageTransitionProvider>
    </AppProviders>
  )
}

export default App
