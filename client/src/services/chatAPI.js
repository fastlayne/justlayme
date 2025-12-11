import apiClient from './client'

/**
 * Chat API Service
 * Handles all chat-related API calls:
 * - Conversations (list, get, create, delete, archive)
 * - Messages (send, load, delete)
 */

export const chatAPI = {
  /**
   * Get all conversations for current user
   * @returns {Promise<Conversation[]>}
   */
  getConversations: async () => {
    try {
      return await apiClient.get('conversations')
    } catch (error) {
      console.error('Failed to fetch conversations:', error)
      throw error
    }
  },

  /**
   * Get specific conversation with metadata
   * @param {string} conversationId
   * @returns {Promise<Conversation>}
   */
  getConversation: async (conversationId) => {
    try {
      return await apiClient.get(`/conversations/${conversationId}`)
    } catch (error) {
      console.error('Failed to fetch conversation:', error)
      throw error
    }
  },

  /**
   * Get paginated messages for a conversation
   * Used for lazy loading older messages
   * @param {string} conversationId
   * @param {number} page - Page number (0-indexed)
   * @param {number} limit - Messages per page (default: 50)
   * @returns {Promise<{messages: Message[], hasMore: boolean, total: number}>}
   */
  getMessages: async (conversationId, page = 0, limit = 50) => {
    try {
      return await apiClient.get(`/conversations/${conversationId}/messages`, {
        params: { page, limit }
      })
    } catch (error) {
      console.error('Failed to fetch messages:', error)
      throw error
    }
  },

  /**
   * Start a new conversation with a character
   * @param {string} characterId
   * @returns {Promise<Conversation>}
   */
  startConversation: async (characterId) => {
    try {
      return await apiClient.post('conversations', {
        characterId,
        startedAt: new Date().toISOString()
      })
    } catch (error) {
      console.error('Failed to start conversation:', error)
      throw error
    }
  },

  /**
   * Send a message in a conversation
   * FIXED: Now calls /api/chat endpoint that backend actually implements
   * Backend expects: { message, character, history, conversationId, isCustomCharacter, customCharacterConfig, characterName }
   *
   * @param {string} conversationId
   * @param {string} content - Message text
   * @param {string} fileUrl - Optional file attachment URL
   * @param {object} metadata - Additional message metadata (contains character info)
   * @returns {Promise<{message: Message, response: Message}>} User message and character response
   */
  sendMessage: async (conversationId, content, fileUrl = null, metadata = {}) => {
    try {
      // Determine character from metadata or conversation
      let character = metadata.character || metadata.characterId || 'layme_v1'
      let characterName = metadata.characterName || null
      let isCustomCharacter = metadata.isCustomCharacter || false
      let customCharacterConfig = metadata.customCharacterConfig || null

      // If no character info in metadata, try to get from conversation details
      if (!metadata.character && !metadata.characterId) {
        try {
          const conversation = await apiClient.get(`/conversations/${conversationId}`)
          if (conversation && conversation.characterId) {
            character = conversation.characterId
            characterName = conversation.characterName || null
            isCustomCharacter = conversation.isCustomCharacter || false
            if (isCustomCharacter && conversation.customCharacterConfig) {
              customCharacterConfig = conversation.customCharacterConfig
            }
          }
        } catch (convError) {
          console.warn('Could not fetch conversation details, using default character')
        }
      }

      // Build conversation history from local messages (if available)
      // This is more efficient than fetching from server again
      let history = metadata.history || []

      // Call the ACTUAL backend endpoint: /api/chat
      // Match the exact format the backend expects
      const response = await apiClient.post('/chat', {
        message: content,
        character: character,
        characterName: characterName,
        isCustomCharacter: isCustomCharacter,
        customCharacterConfig: customCharacterConfig,
        conversationId: conversationId,
        history: history,
        fileUrl: fileUrl
      })

      // FIX 7: Backend now returns message ID from server
      // { response: "text", conversationId: "id", message: { id, timestamp } }
      const responseText = response.response || response
      const messageId = response.message?.id || `msg-${Date.now()}-user`
      const messageTimestamp = response.message?.timestamp || new Date().toISOString()

      return {
        message: {
          id: messageId,
          conversationId: conversationId,
          role: 'user',
          content: content,
          fileUrl: fileUrl,
          timestamp: messageTimestamp
        },
        response: {
          id: `msg-${Date.now()}-assistant`,
          conversationId: conversationId,
          role: 'assistant',
          content: responseText, // Extract the actual response text from the response object
          timestamp: new Date().toISOString()
        }
      }
    } catch (error) {
      console.error('Failed to send message:', error)
      throw error
    }
  },

  /**
   * Delete a specific message
   * @param {string} conversationId
   * @param {string} messageId
   * @returns {Promise<void>}
   */
  deleteMessage: async (conversationId, messageId) => {
    try {
      return await apiClient.delete(`/conversations/${conversationId}/messages/${messageId}`)
    } catch (error) {
      console.error('Failed to delete message:', error)
      throw error
    }
  },

  /**
   * Delete entire conversation
   * @param {string} conversationId
   * @returns {Promise<void>}
   */
  deleteConversation: async (conversationId) => {
    try {
      return await apiClient.delete(`/conversations/${conversationId}`)
    } catch (error) {
      console.error('Failed to delete conversation:', error)
      throw error
    }
  },

  /**
   * Archive a conversation (soft delete)
   * @param {string} conversationId
   * @returns {Promise<Conversation>}
   */
  archiveConversation: async (conversationId) => {
    try {
      return await apiClient.patch(`/conversations/${conversationId}`, {
        archived: true,
        archivedAt: new Date().toISOString()
      })
    } catch (error) {
      console.error('Failed to archive conversation:', error)
      throw error
    }
  },

  /**
   * Search conversations by keyword
   * @param {string} query
   * @returns {Promise<Conversation[]>}
   */
  searchConversations: async (query) => {
    try {
      return await apiClient.get('conversations/search', {
        params: { q: query }
      })
    } catch (error) {
      console.error('Failed to search conversations:', error)
      throw error
    }
  }
}
