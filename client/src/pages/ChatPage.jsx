import { Helmet } from 'react-helmet-async';
import ChatLayout from '@/components/chat/ChatLayout';
import ErrorBoundary from '@/components/ErrorBoundary';
import PropTypes from 'prop-types';
import './ChatPage.scss';

/**
 * ChatPage Component
 * Main chat interface page
 * Renders the full chat layout with sidebar, messages, and input
 * ARCHITECTURAL FIX: Wrapped in ErrorBoundary for graceful error handling
 */

export default function ChatPage() {
  return (
    <ErrorBoundary
      fallback={({ error, reset }) => (
        <div className="error-container">
          <div className="error-content">
            <h2>😔 Chat Error</h2>
            <p>We encountered an issue loading your conversations.</p>
            <p className="error-hint">This might be a temporary network problem.</p>
            {error?.circuitOpen && (
              <p className="circuit-message">
                ⚡ Too many failed requests. Please wait a moment before trying again.
              </p>
            )}
            <button onClick={reset} className="retry-button">
              Try Again
            </button>
          </div>
        </div>
      )}
    >
      <Helmet>
        <title>Chat with AI - JustLayMe</title>
        <meta name="description" content="Chat with advanced AI without restrictions. Enjoy unfiltered conversations with custom characters powered by cutting-edge language models." />
        <link rel="canonical" href="https://justlay.me/chat" />
        <meta property="og:title" content="Chat with AI - JustLayMe" />
        <meta property="og:description" content="Chat with advanced AI without restrictions. Enjoy unfiltered conversations with custom characters powered by cutting-edge language models." />
        <meta property="og:url" content="https://justlay.me/chat" />
        <meta property="og:type" content="website" />
        <meta property="og:image" content="https://justlay.me/og-image.jpg" />
        <meta property="og:image:width" content="1200" />
        <meta property="og:image:height" content="630" />
        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:title" content="Chat with AI - JustLayMe" />
        <meta name="twitter:description" content="Chat with advanced AI without restrictions. Enjoy unfiltered conversations with custom characters powered by cutting-edge language models." />
        <meta name="twitter:image" content="https://justlay.me/twitter-image.jpg" />
      </Helmet>

      <div className="chat-page">
        <ChatLayout />
      </div>
    </ErrorBoundary>
  )
}

ChatPage.propTypes = {
  children: PropTypes.node,
};
