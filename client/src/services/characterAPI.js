import apiClient from './client'

/**
 * Character API Service
 * Handles all character-related API calls:
 * - Character CRUD operations
 * - Character search and filtering
 */

export const characterAPI = {
  /**
   * Get all characters for current user
   * @returns {Promise<Character[]>}
   */
  getCharacters: async () => {
    try {
      return await apiClient.get('characters')
    } catch (error) {
      console.error('Failed to fetch characters:', error)
      throw error
    }
  },

  /**
   * Get specific character by ID
   * @param {string} id
   * @returns {Promise<Character>}
   */
  getCharacter: async (id) => {
    try {
      return await apiClient.get(`/characters/${id}`)
    } catch (error) {
      console.error('Failed to fetch character:', error)
      throw error
    }
  },

  /**
   * Create a new character
   * @param {object} characterData
   * @returns {Promise<Character>}
   */
  createCharacter: async (characterData) => {
    try {
      // Align with backend schema: personality is a string, voiceSettings is JSON in config column
      return await apiClient.post('characters', {
        name: characterData.name,
        bio: characterData.bio,
        avatar: characterData.avatar,
        // Backend expects personality as a string (not an object)
        personality: typeof characterData.personality === 'string'
          ? characterData.personality
          : (characterData.personality?.traits?.join(', ') || ''),
        // Backend stores this in the config column as JSON
        voiceSettings: {
          voiceId: characterData.voiceSettings?.voiceId || 'default',
          pitch: characterData.voiceSettings?.pitch || 1,
          speed: characterData.voiceSettings?.speed || 1
        },
        systemPrompt: characterData.systemPrompt || ''
      })
    } catch (error) {
      console.error('Failed to create character:', error)
      throw error
    }
  },

  /**
   * Update existing character
   * @param {string} id
   * @param {object} updates
   * @returns {Promise<Character>}
   */
  updateCharacter: async (id, updates) => {
    try {
      return await apiClient.patch(`/characters/${id}`, {
        ...updates,
        updatedAt: new Date().toISOString()
      })
    } catch (error) {
      console.error('Failed to update character:', error)
      throw error
    }
  },

  /**
   * Delete a character
   * @param {string} id
   * @returns {Promise<void>}
   */
  deleteCharacter: async (id) => {
    try {
      return await apiClient.delete(`/characters/${id}`)
    } catch (error) {
      console.error('Failed to delete character:', error)
      throw error
    }
  },

  /**
   * Test character response generation
   * Used for live preview in character creator
   * @param {object} characterData - Incomplete character data for testing
   * @param {string} testPrompt - Test message to send to character
   * @returns {Promise<string>} Character's response to test prompt
   */
  testCharacterResponse: async (characterData, testPrompt) => {
    try {
      return await apiClient.post('characters/test-response', {
        character: {
          name: characterData.name,
          bio: characterData.bio,
          personality: characterData.personality,
          systemPrompt: characterData.systemPrompt
        },
        prompt: testPrompt,
        timestamp: new Date().toISOString()
      })
    } catch (error) {
      console.error('Failed to test character response:', error)
      throw error
    }
  },

  /**
   * Get recent characters
   * Characters most recently used in conversations
   * @param {number} limit - Number of recent characters (default: 5)
   * @returns {Promise<Character[]>}
   */
  getRecentCharacters: async (limit = 5) => {
    try {
      return await apiClient.get('characters/recent', {
        params: { limit }
      })
    } catch (error) {
      console.error('Failed to fetch recent characters:', error)
      throw error
    }
  },

  /**
   * Search characters by name or bio
   * @param {string} query
   * @returns {Promise<Character[]>}
   */
  searchCharacters: async (query) => {
    try {
      return await apiClient.get('characters/search', {
        params: { q: query }
      })
    } catch (error) {
      console.error('Failed to search characters:', error)
      throw error
    }
  }
}
