import { useState, useEffect } from 'react'
import { useChat } from '@/hooks/useChat'
import { useCharacters } from '@/hooks/useCharacters'
import { useModal } from '@/hooks/useModal'
import { useSidebar } from '@/hooks/useSidebar'
import { useAuth } from '@/hooks/useAuth'
import { useNavigate } from 'react-router-dom'
import { usePageTransition } from '@/hooks/usePageTransition'
import ConversationList from './ConversationList'
import CharacterSelector from './CharacterSelector'
import SpotlightCard from '@/components/common/SpotlightCard'
import RotatingText from '@/components/common/RotatingText'
import './Sidebar.scss'

/**
 * Sidebar Component
 * Left navigation panel with conversations and character selector
 * Responsive: collapses to hamburger on mobile
 */

export default function Sidebar() {
  const navigate = useNavigate()
  const { startTransition } = usePageTransition()

  // ARCHITECTURAL FIX: Use local state as primary control for mobile sidebar
  const [localSidebarOpen, setLocalSidebarOpen] = useState(false)
  const [isMobileView, setIsMobileView] = useState(window.innerWidth < 768)

  // Still get context values but don't rely on them for toggle
  const contextValues = useSidebar()
  const { logout } = useAuth()
  const { conversations, activeConversationId, setActiveConversation, startConversation, fetchMessages } = useChat()
  const { characters, activeCharacterId, selectCharacter } = useCharacters()
  const characterModal = useModal('character-creator')
  const settingsModal = useModal('settings')

  // ARCHITECTURAL FIX: Handle resize events locally
  useEffect(() => {
    const handleResize = () => {
      const mobile = window.innerWidth < 768
      setIsMobileView(mobile)
      // Close sidebar when switching to desktop
      if (!mobile) {
        setLocalSidebarOpen(false)
      }
    }

    window.addEventListener('resize', handleResize)
    handleResize() // Initial check

    return () => window.removeEventListener('resize', handleResize)
  }, [])

  // Use local state for mobile, context for desktop
  const isOpen = isMobileView ? localSidebarOpen : (contextValues?.isOpen ?? true)
  const isMobile = isMobileView

  // Local toggle function that always works
  const toggle = () => {
    console.log('[Hamburger] Local toggle called, current state:', localSidebarOpen)
    setLocalSidebarOpen(!localSidebarOpen)
  }

  const close = () => {
    setLocalSidebarOpen(false)
  }

  const handleCreateCharacter = () => {
    characterModal.openModal()
    if (isMobile) {
      setLocalSidebarOpen(false)
    }
  }

  const handleSelectCharacter = async (characterId) => {
    selectCharacter(characterId)

    // ARCHITECTURAL FIX: Resume most recent conversation with this character
    // instead of always creating a new one
    const characterConversations = conversations.filter(
      conv => conv.model_type === characterId
    )

    if (characterConversations.length > 0) {
      // Resume the most recent conversation
      const mostRecent = characterConversations[0] // Already sorted by updated_at DESC
      console.log(`[Sidebar] Resuming conversation ${mostRecent.id} with character ${characterId}`)
      setActiveConversation(mostRecent.id)

      // Load messages for this conversation
      try {
        await fetchMessages(mostRecent.id)
      } catch (error) {
        console.error('Failed to load conversation messages:', error)
      }
    } else {
      // No existing conversations - create new one
      console.log(`[Sidebar] No existing conversations for character ${characterId}, creating new one`)
      try {
        await startConversation(characterId)
      } catch (error) {
        console.error('Failed to start conversation:', error)
      }
    }
  }

  const handleNewConversation = async () => {
    if (!activeCharacterId) {
      return
    }
    try {
      await startConversation(activeCharacterId)
    } catch (error) {
      console.error('Failed to start new conversation:', error)
    }
  }

  const handleBlackMirror = () => {
    // Close sidebar on mobile
    if (isMobile) {
      setLocalSidebarOpen(false)
    }

    // ARCHITECTURAL FIX: Force full page reload to ensure navigation works
    // TransitionWrapper is blocking React Router navigation, so use native navigation
    console.log('[Sidebar] Grey Mirror button clicked, forcing page reload')
    window.location.href = '/grey-mirror'
  }

  const handleSettings = () => {
    settingsModal.openModal()
    if (isMobile) {
      setLocalSidebarOpen(false)
    }
  }

  const handleLogout = () => {
    // Clear authentication state and tokens
    logout()

    // Clear any user-specific data from localStorage
    localStorage.removeItem('authToken')
    localStorage.removeItem('refreshToken')

    // ARCHITECTURAL FIX: Navigate immediately for instant response
    navigate('/')
    // Start transition after navigation
    setTimeout(() => {
      startTransition('/')
    }, 10)
  }

  // ARCHITECTURAL FIX: Bulletproof mobile toggle handler
  const handleToggleClick = (e) => {
    if (e) {
      e.preventDefault()
      e.stopPropagation()
    }

    console.log('[Hamburger] Toggle triggered! Current:', localSidebarOpen)

    // Direct state update - guaranteed to work
    setLocalSidebarOpen(prev => {
      const newState = !prev
      console.log('[Hamburger] Sidebar is now:', newState ? 'OPEN' : 'CLOSED')
      return newState
    })
  }

  // Mobile-specific touch handler for better responsiveness
  const handleTouchEnd = (e) => {
    e.preventDefault() // Prevent ghost clicks
    console.log('[Hamburger] Touch detected!')
    handleToggleClick()
  }

  return (
    <>
      {/* Hamburger Menu Button - Positioned separately when sidebar is closed */}
      {isMobile && !localSidebarOpen && (
        <button
          className="sidebar-toggle floating"
          onClick={handleToggleClick}
          onTouchEnd={handleTouchEnd}
          onMouseDown={() => console.log('[Hamburger] Mouse down')}
          onTouchStart={(e) => {
            console.log('[Hamburger] Touch start')
            e.stopPropagation() // Prevent parent handlers
          }}
          aria-label="Open navigation menu"
          aria-expanded={false}
          aria-controls="sidebar-navigation"
          type="button"
          style={{
            touchAction: 'manipulation',
            WebkitTapHighlightColor: 'rgba(6, 182, 212, 0.2)',
            userSelect: 'none',
            WebkitUserSelect: 'none'
          }}
        >
          ☰
        </button>
      )}

      {/* Mobile overlay when sidebar is open */}
      {isMobile && localSidebarOpen && (
        <div
          className="sidebar-overlay"
          onClick={() => {
            console.log('[Overlay] Clicked, closing sidebar')
            setLocalSidebarOpen(false)
          }}
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0, 0, 0, 0.5)',
            zIndex: 999,
            backdropFilter: 'blur(4px)'
          }}
        />
      )}

      {/* Sidebar - ARCHITECTURAL FIX: Use local state for open/closed */}
      <nav id="sidebar-navigation" className={`sidebar ${localSidebarOpen ? 'open' : 'closed'}`}>
        {/* Header */}
        <div className="sidebar-header">
          <h2 className="sidebar-logo" style={{ fontSize: '1.5rem' }}>
            Justlay.
            <RotatingText
              texts={['Me', 'You', 'Her', 'Him', 'Yourself', 'Everyone', 'Someone', 'Back', 'Down', 'Low']}
              mainClassName="rotating-brand-highlight"
              splitBy="words"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.3 }}
              rotationInterval={2000}
            />
          </h2>
          {isMobile && (
            <button
              className="close-btn"
              onClick={() => {
                console.log('[Sidebar] Close button clicked')
                setLocalSidebarOpen(false)
              }}
              onTouchEnd={(e) => {
                e.preventDefault()
                console.log('[Sidebar] Close button touch')
                setLocalSidebarOpen(false)
              }}
              style={{ touchAction: 'manipulation' }}
            >
              ✕
            </button>
          )}
        </div>

        {/* Character Selector */}
        <CharacterSelector
          characters={characters}
          activeCharacterId={activeCharacterId}
          onSelect={handleSelectCharacter}
        />

        {/* Conversations List */}
        {/* ARCHITECTURAL FIX: Filter conversations by active character */}
        <ConversationList
          conversations={
            activeCharacterId
              ? conversations.filter(conv => conv.model_type === activeCharacterId)
              : conversations
          }
          characters={characters}
          activeConversationId={activeConversationId}
          onSelect={(id) => {
            setActiveConversation(id)
            // Load messages for the selected conversation
            fetchMessages(id).catch(err => {
              console.error('Failed to load messages:', err)
            })
            if (isMobile) {
              setLocalSidebarOpen(false)
            }
          }}
        />

        {/* Action Buttons */}
        <div className="sidebar-actions">
          <SpotlightCard className="action-card" spotlightColor="rgba(6, 182, 212, 0.3)" spotlightSize={200}>
            <button
              className="action-btn primary"
              onClick={handleCreateCharacter}
              title="Create new character"
            >
              <span className="btn-icon">✨</span>
              <span className="btn-text">New Character</span>
            </button>
          </SpotlightCard>

          <SpotlightCard className="action-card" spotlightColor="rgba(139, 92, 246, 0.25)" spotlightSize={200}>
            <button
              className="action-btn secondary"
              onClick={handleNewConversation}
              disabled={!activeCharacterId}
              title="Start new conversation with selected character"
            >
              <span className="btn-icon">💬</span>
              <span className="btn-text">New Conversation</span>
            </button>
          </SpotlightCard>

          <SpotlightCard className="action-card" spotlightColor="rgba(255, 255, 255, 0.2)" spotlightSize={200}>
            <button
              className="action-btn secondary black-mirror-btn"
              onClick={handleBlackMirror}
              title="Analyze relationships"
            >
              <span className="btn-icon">🪞</span>
              <span className="btn-text">The Grey Mirror</span>
            </button>
          </SpotlightCard>
        </div>

        {/* Footer */}
        <div className="sidebar-footer">
          <button className="footer-btn" onClick={handleSettings}>⚙️ Settings</button>
          <button className="footer-btn" onClick={handleLogout}>🚪 Logout</button>
        </div>
      </nav>
    </>
  )
}
