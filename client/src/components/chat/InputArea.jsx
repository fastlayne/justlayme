import { useState, useRef, useEffect } from 'react'
import { useChat } from '@/hooks/useChat'
import { useNotification } from '@/hooks/useNotification'
import './InputArea.scss'

/**
 * InputArea Component
 * Message composition area with auto-expanding textarea
 * Handles message sending with error handling
 */

export default function InputArea({ activeConversationId = null, activeCharacterId = null, activeCharacter = null }) {
  const [message, setMessage] = useState('')
  const [isSending, setIsSending] = useState(false)
  const [attachedFile, setAttachedFile] = useState(null)
  const [filePreview, setFilePreview] = useState(null)
  const textareaRef = useRef(null)
  const fileInputRef = useRef(null)
  const { sendMessage } = useChat()
  const notification = useNotification()

  // Auto-expand textarea height as content grows
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto'
      textareaRef.current.style.height = Math.min(textareaRef.current.scrollHeight, 120) + 'px'
    }
  }, [message])

  // Handle file attachment selection
  const handleFileSelect = (e) => {
    const file = e.target.files?.[0]
    if (!file) return

    // Validate file size (max 5MB)
    const maxSize = 5 * 1024 * 1024 // 5MB in bytes
    if (file.size > maxSize) {
      notification.error('File size exceeds 5MB limit')
      return
    }

    // Validate file type (images only for now)
    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
    if (!allowedTypes.includes(file.type)) {
      notification.error('Only image files (JPG, PNG, GIF, WebP) are supported')
      return
    }

    setAttachedFile(file)

    // Create preview for images
    const reader = new FileReader()
    reader.onload = (e) => {
      setFilePreview(e.target.result)
    }
    reader.readAsDataURL(file)
  }

  // Remove attached file
  const handleRemoveFile = () => {
    setAttachedFile(null)
    setFilePreview(null)
    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  // Handle message submission
  const handleSend = async () => {
    // Validation
    if (!message.trim() && !attachedFile) {
      notification.warning('Please enter a message or attach a file')
      return
    }

    if (!activeConversationId) {
      notification.error('No conversation selected')
      return
    }

    // ARCHITECTURAL FIX: Validate message isn't just whitespace
    if (message.trim().length === 0 && !attachedFile) {
      notification.warning('Message cannot be empty')
      return
    }

    // Send message
    setIsSending(true)
    try {
      // If there's an attached file, upload it first
      let fileUrl = null
      if (attachedFile) {
        const formData = new FormData()
        formData.append('file', attachedFile)
        formData.append('conversationId', activeConversationId)

        // Upload file to backend
        const uploadResponse = await fetch('/api/upload', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('authToken')}`
          },
          body: formData
        })

        if (!uploadResponse.ok) {
          // ARCHITECTURAL FIX: Better error messages based on status
          const errorData = await uploadResponse.json().catch(() => ({}))
          const errorMessage = errorData.message || `Upload failed with status ${uploadResponse.status}`
          throw new Error(errorMessage)
        }

        const uploadData = await uploadResponse.json()

        // FIX 8: Validate response has required fileUrl field
        if (!uploadData.fileUrl && !uploadData.url) {
          throw new Error('Upload succeeded but no file URL returned - invalid server response')
        }

        fileUrl = uploadData.fileUrl || uploadData.url
      }

      // Build character metadata for personality integration
      const characterMetadata = activeCharacter ? {
        character: activeCharacter.id || activeCharacterId,
        characterName: activeCharacter.name,
        isCustomCharacter: activeCharacter.isCustom !== false, // Default to true for custom chars
        customCharacterConfig: {
          systemPrompt: activeCharacter.system_prompt || activeCharacter.systemPrompt || activeCharacter.personality,
          personality: activeCharacter.personality,
          description: activeCharacter.description,
          model: activeCharacter.config?.model || 'sushruth/solar-uncensored:latest',
          temperature: parseFloat(activeCharacter.config?.temperature) || 0.85,
          top_p: parseFloat(activeCharacter.config?.top_p) || 0.95,
          max_tokens: parseInt(activeCharacter.config?.max_tokens, 10) || 250,
          repeat_penalty: parseFloat(activeCharacter.config?.repeat_penalty) || 1.1
        }
      } : {};

      // Send message with optional file attachment AND character metadata
      await sendMessage(message.trim() || '[Image attachment]', fileUrl, characterMetadata)

      // Clear input on success
      setMessage('')
      setAttachedFile(null)
      setFilePreview(null)
      if (fileInputRef.current) {
        fileInputRef.current.value = ''
      }

      // Reset textarea height
      if (textareaRef.current) {
        textareaRef.current.style.height = 'auto'
      }
    } catch (error) {
      console.error('Failed to send message:', error)
      // ARCHITECTURAL FIX: More specific error messages
      const errorMessage = error?.message || 'Failed to send message'
      notification.error(errorMessage)
    } finally {
      setIsSending(false)
    }
  }

  // Handle Enter key (Cmd+Enter or Ctrl+Enter to send)
  const handleKeyDown = (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
      e.preventDefault()
      handleSend()
    }
    // Allow normal Enter for newline
    if (e.key === 'Enter' && !e.ctrlKey && !e.metaKey) {
      // Let default behavior (newline) occur
    }
  }

  return (
    <div className="input-area">
      {/* File Preview */}
      {filePreview && (
        <div className="file-preview-container">
          <div className="file-preview">
            <img src={filePreview} alt="Attached file preview" />
            <button
              className="remove-file-btn"
              onClick={handleRemoveFile}
              title="Remove attachment"
            >
              ✕
            </button>
          </div>
          <div className="file-info">
            <span className="file-name">{attachedFile?.name}</span>
            <span className="file-size">
              {attachedFile?.size ? (attachedFile.size / 1024).toFixed(1) : '0'} KB
            </span>
          </div>
        </div>
      )}

      <div className="input-container">
        <textarea
          ref={textareaRef}
          className="message-input"
          placeholder="Type your message... (Ctrl+Enter to send)"
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          onKeyDown={handleKeyDown}
          disabled={isSending || !activeConversationId}
          rows={1}
        />

        <div className="input-actions">
          {/* Hidden file input */}
          <input
            ref={fileInputRef}
            type="file"
            accept="image/jpeg,image/png,image/gif,image/webp"
            onChange={handleFileSelect}
            style={{ display: 'none' }}
            aria-label="Attach file"
          />

          <button
            className="action-button secondary"
            title="Attach file (images only, max 5MB)"
            onClick={() => fileInputRef.current?.click()}
            disabled={isSending || !activeConversationId || attachedFile}
          >
            📎
          </button>

          <button
            className="action-button primary"
            onClick={handleSend}
            disabled={isSending || (!message.trim() && !attachedFile) || !activeConversationId}
            title="Send message (Ctrl+Enter)"
          >
            {isSending ? '⏳' : '→'}
          </button>
        </div>
      </div>

      <div className="input-hint">
        <span className="hint-text">Ctrl+Enter to send</span>
        {attachedFile && (
          <span className="hint-text"> · File attached: {attachedFile.name}</span>
        )}
      </div>
    </div>
  )
}
