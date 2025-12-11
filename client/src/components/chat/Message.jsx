import { memo } from 'react'
import './Message.scss'

/**
 * Message Component
 * Individual message bubble supporting user, character, and system variants
 * Handles message formatting, timestamps, and actions
 * Memoized to prevent unnecessary re-renders in long message lists
 */

function Message({ message = {}, variant = 'user' }) {
  const {
    id,
    content = '',
    timestamp,
    senderName = '',
    senderAvatar = '',
    metadata = {},
  } = message

  // Format timestamp
  const formattedTime = timestamp
    ? new Date(timestamp).toLocaleTimeString('en-US', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: true,
      })
    : ''

  // Determine if message has multiple lines
  const hasMultipleLines = content.split('\n').length > 1

  return (
    <div className={`message message-${variant}`}>
      {variant === 'character' && senderAvatar && (
        <div className="message-avatar">
          <img src={senderAvatar} alt={senderName} />
        </div>
      )}

      <div className="message-bubble">
        {variant === 'character' && senderName && (
          <div className="message-sender">{senderName}</div>
        )}

        <div className={`message-content ${hasMultipleLines ? 'multiline' : ''}`}>
          {content}
        </div>

        {formattedTime && <div className="message-time">{formattedTime}</div>}
      </div>

      {variant === 'user' && (
        <div className="message-actions">
          <button className="action-btn" title="Copy message">
            📋
          </button>
          <button className="action-btn" title="Delete message">
            🗑️
          </button>
        </div>
      )}
    </div>
  )
}

/**
 * Custom comparison function for React.memo
 * Only re-render if message content, variant, or timestamp changed
 */
function arePropsEqual(prevProps, nextProps) {
  return (
    prevProps.message?.id === nextProps.message?.id &&
    prevProps.message?.content === nextProps.message?.content &&
    prevProps.message?.timestamp === nextProps.message?.timestamp &&
    prevProps.variant === nextProps.variant
  )
}

export default memo(Message, arePropsEqual)
