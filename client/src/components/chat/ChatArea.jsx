import { useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useChat } from '@/hooks/useChat'
import { useCharacters } from '@/hooks/useCharacters'
import { useModal } from '@/hooks/useModal'
import { useNotification } from '@/hooks/useNotification'
import { useAuth } from '@/hooks/useAuth'
import { usePageTransition } from '@/hooks/usePageTransition'
import ShinyText from '@/components/common/ShinyText'
import MessageList from './MessageList'
import InputArea from './InputArea'
import TypingIndicator from './TypingIndicator'
import './ChatArea.scss'

/**
 * ChatArea Component
 * Main chat display area containing message list and input
 * Shows active character info and handles message composition
 */

export default function ChatArea() {
  const navigate = useNavigate()
  const { startTransition } = usePageTransition()
  const { activeConversationId, messages, isLoadingMessages, typingIndicator } = useChat()
  const { characters, activeCharacterId } = useCharacters()
  const { user } = useAuth()
  const settingsModal = useModal('settings')
  const premiumModal = useModal('premium-paywall')
  const notification = useNotification()

  const handleCharacterInfo = () => {
    notification.info('Character information panel coming soon!')
  }

  const handleSettingsClick = () => {
    settingsModal.openModal()
  }

  const handleBlackMirrorClick = () => {
    // ARCHITECTURAL FIX: Force full page reload to ensure navigation works
    // TransitionWrapper is blocking React Router navigation, so use native navigation
    console.log('[ChatArea] Grey Mirror button clicked, forcing page reload')
    window.location.href = '/grey-mirror'
  }

  // Find active character
  const activeCharacter = characters.find((c) => c.id === activeCharacterId)

  // Early return if no active conversation
  if (!activeConversationId) {
    return (
      <div className="chat-area empty">
        <div className="empty-state">
          <div className="empty-icon">💬</div>
          <h2><ShinyText speed={5}>Select a conversation to start</ShinyText></h2>
          <p><ShinyText speed={5}>Choose a conversation from the sidebar or create a new one</ShinyText></p>
        </div>
      </div>
    )
  }

  return (
    <div className="chat-area">
      {/* Chat Header */}
      <div className="chat-header">
        <div className="header-character">
          <div className="character-avatar-mini">
            {activeCharacter?.avatar ? (
              <img src={activeCharacter.avatar} alt={activeCharacter?.name} />
            ) : (
              <div className="avatar-placeholder">{activeCharacter?.name?.charAt(0) || 'C'}</div>
            )}
          </div>
          <div className="header-info">
            <h2>{activeCharacter?.name || 'Character'}</h2>
            <p className="header-status">Online</p>
          </div>
        </div>

        {/* Header Actions */}
        <div className="header-actions">
          <button className="header-btn" title="Character info" onClick={handleCharacterInfo}>
            ℹ️
          </button>
          <button className="header-btn" title="Settings" onClick={handleSettingsClick}>
            ⚙️
          </button>
        </div>
      </div>

      {/* Messages Container */}
      <MessageList messages={messages} isLoading={isLoadingMessages} activeCharacterId={activeCharacterId} />

      {/* Typing Indicator */}
      {typingIndicator.isVisible && (
        <TypingIndicator characterName={typingIndicator.characterName} />
      )}

      {/* Input Area */}
      <InputArea
        activeConversationId={activeConversationId}
        activeCharacterId={activeCharacterId}
        activeCharacter={activeCharacter}
      />

      {/* Floating The Grey Mirror Button */}
      <button
        className="floating-black-mirror-btn"
        onClick={handleBlackMirrorClick}
        title="The Grey Mirror Analysis"
        aria-label="Open The Grey Mirror Analysis"
      >
        🪞
      </button>
    </div>
  )
}
