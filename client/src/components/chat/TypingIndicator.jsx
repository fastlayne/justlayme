import './TypingIndicator.scss'

/**
 * TypingIndicator Component
 * Shows animated typing indicator when character is composing response
 */

export default function TypingIndicator({ characterName = 'Character' }) {
  return (
    <div className="typing-indicator-container">
      <div className="typing-message">
        <div className="typing-dots">
          <span className="dot"></span>
          <span className="dot"></span>
          <span className="dot"></span>
        </div>
        <span className="typing-label">{characterName} is typing...</span>
      </div>
    </div>
  )
}
