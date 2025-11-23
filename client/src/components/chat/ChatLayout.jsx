import { useState, useEffect } from 'react'
import { useChat } from '@/hooks/useChat'
import { useCharacters } from '@/hooks/useCharacters'
import { useAuth } from '@/hooks/useAuth'
import Sidebar from './Sidebar'
import ChatArea from './ChatArea'
import './ChatLayout.scss'

/**
 * ChatLayout Component
 * Main layout orchestrating sidebar + chat area
 * Handles responsive behavior and state initialization
 */

export default function ChatLayout() {
  // ARCHITECTURAL FIX: Use local state for mobile sidebar visibility
  const [isMobile, setIsMobile] = useState(window.innerWidth < 768)

  const { fetchConversations } = useChat()
  const { fetchCharacters } = useCharacters()
  const { isAuthenticated } = useAuth()

  // Handle window resize
  useEffect(() => {
    const handleResize = () => {
      setIsMobile(window.innerWidth < 768)
    }

    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  // Load initial data for authenticated users
  // ARCHITECTURAL FIX: Now safe to include fetchConversations/fetchCharacters in deps
  // These functions have STABLE references from context (memoized with useCallback)
  // No infinite loop - they won't change between renders
  useEffect(() => {
    if (isAuthenticated) {
      fetchConversations().catch(err => {
        console.warn('Failed to load conversations:', err.message)
        // Circuit breaker handles retry limits - won't crash browser
      })
      fetchCharacters().catch(err => {
        console.warn('Failed to load characters:', err.message)
        // Circuit breaker handles retry limits - won't crash browser
      })
    }
  }, [isAuthenticated, fetchConversations, fetchCharacters])

  return (
    <div className="chat-layout">
      {/* Left Sidebar */}
      <Sidebar />

      {/* Main Chat Area */}
      <ChatArea />

      {/* Note: Overlay is now handled inside Sidebar component for better encapsulation */}
    </div>
  )
}
