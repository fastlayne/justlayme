import { useMemo } from 'react'
import './ConversationList.scss'

/**
 * ConversationList Component
 * Optimized list of conversations for performance
 * Displays recent conversations with last message preview
 * Uses CSS scrolling for smooth performance with large datasets
 */

export default function ConversationList({
  conversations = [],
  activeConversationId = null,
  onSelect = () => {},
  characters = [],
}) {
  // Early return if no conversations
  if (!conversations || conversations.length === 0) {
    return (
      <div className="conversation-list empty">
        <p>No conversations yet</p>
        <p className="text-sm">Start a new conversation to begin chatting</p>
      </div>
    )
  }

  // Memoize formatted conversations to prevent unnecessary formatting
  const formattedConversations = useMemo(() => {
    return conversations.map((conversation) => {
      const isActive = conversation.id === activeConversationId
      const lastMessage = conversation.lastMessage || {}

      // ARCHITECTURAL FIX: Format timestamp from updated_at or created_at
      const timestamp = conversation.updated_at || conversation.created_at
        ? new Date(conversation.updated_at || conversation.created_at).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
          })
        : lastMessage.timestamp
        ? new Date(lastMessage.timestamp).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
          })
        : ''

      // Find character name from model_type
      const character = characters.find(c => c.id === conversation.model_type)
      const characterName = character ? character.name : (conversation.model_type || 'Unknown')

      return {
        ...conversation,
        isActive,
        timestamp,
        characterName,
        preview: lastMessage.content ? lastMessage.content.substring(0, 50) : conversation.message_count > 0 ? `${conversation.message_count} messages` : 'No messages yet',
        hasMore: lastMessage.content && lastMessage.content.length > 50,
      }
    })
  }, [conversations, activeConversationId, characters])

  return (
    <div className="conversation-list">
      <div className="conversation-list-header">
        <h3>Conversations</h3>
      </div>
      <div className="conversation-list-container">
        {formattedConversations.map((conversation) => (
          <button
            key={conversation.id}
            className={`conversation-item ${conversation.isActive ? 'active' : ''}`}
            onClick={() => onSelect(conversation.id)}
            title={conversation.title || conversation.characterName}
          >
            <div className="conversation-header">
              <span className="conversation-title">
                {conversation.title || `Chat with ${conversation.characterName}`}
              </span>
              <span className="conversation-time">{conversation.timestamp}</span>
            </div>
            <div className="conversation-preview">
              {conversation.preview}
              {conversation.hasMore ? '...' : ''}
            </div>
          </button>
        ))}
      </div>
    </div>
  )
}
