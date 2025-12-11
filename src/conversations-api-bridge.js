/**
 * Conversations API Bridge
 *
 * Maps frontend API expectations to backend conversation endpoints
 *
 * Frontend expects:
 * - GET /api/conversations (get all conversations)
 * - POST /api/conversations (create conversation)
 * - GET /api/conversations/:id (get specific conversation)
 * - GET /api/conversations/:id/messages (get messages in conversation)
 * - POST /api/conversations/:id/messages (send message)
 *
 * This bridge adapts the backend endpoints to match frontend expectations
 */

const jwt = require('jsonwebtoken');

// SECURITY HARDENING: Require JWT_SECRET - no fallback secrets
const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET) {
    console.error('[BRIDGE] CRITICAL SECURITY ERROR: JWT_SECRET environment variable is required');
    throw new Error('JWT_SECRET is required for conversations API bridge');
}

/**
 * Extract user ID from JWT token - supports both cookie and Authorization header
 * SECURITY HARDENING: Dual authentication support for migration period
 * @param {Request} req - Express request object
 * @returns {string|null} User ID from token or null
 */
function extractUserIdFromToken(req) {
  // Try cookie first (new secure method)
  const cookieToken = req.cookies?.authToken;

  // Fallback to Authorization header (old method)
  const authHeader = req.headers.authorization;
  const headerToken = authHeader && authHeader.startsWith('Bearer ')
    ? authHeader.substring(7)
    : null;

  const token = cookieToken || headerToken;

  if (token) {
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      return decoded.id || decoded.userId || decoded.user_id;
    } catch (error) {
      console.error('[BRIDGE] JWT token extraction failed:', error.message);
    }
  }
  return null;
}

/**
 * Get user ID from request with proper authentication
 * Requires valid JWT token - no fallback to test users
 * @param {Request} req - Express request object
 * @returns {string} User ID from authenticated token
 * @throws {Error} If no valid authentication found
 */
function getUserId(req) {
  // Try JWT token first
  let userId = extractUserIdFromToken(req);

  // If no valid token, return error - don't allow unauthenticated access
  if (!userId || userId === 'undefined' || userId === 'null') {
    console.error('[BRIDGE] No valid user authentication found');
    throw new Error('Authentication required');
  }

  return userId;
}

/**
 * Setup conversation API bridges
 * @param {Express.App} app - Express application instance
 * @param {Database} db - Shared database instance
 */
function setupConversationsAPIBridge(app, db) {
  const { getUserConversations, getConversationMessages } = require('./sqlite-chat-history');

  /**
   * GET /api/conversations
   * Get all conversations for the current user
   */
  app.get('/api/conversations', async (req, res) => {
    try {
      let userId;
      try {
        userId = getUserId(req);
      } catch (authError) {
        return res.status(401).json({
          error: 'Authentication required',
          message: 'Please log in to access your conversations',
          code: 'AUTH_REQUIRED'
        });
      }
      console.log(`[BRIDGE] GET /api/conversations for user ${userId}`);

      // Use existing backend endpoint
      const response = await db.query(
        'SELECT id, model_type, title, message_count, created_at, updated_at FROM conversations WHERE user_id = ? ORDER BY updated_at DESC',
        [userId]
      );

      const conversations = response.rows || response || [];
      console.log(`[BRIDGE] Returning ${conversations.length} conversations for user ${userId}`);

      return res.json(conversations);
    } catch (error) {
      console.error('[BRIDGE] Error fetching conversations:', error);
      return res.status(500).json({ error: 'Failed to fetch conversations' });
    }
  });

  /**
   * POST /api/conversations
   * Create a new conversation
   */
  app.post('/api/conversations', async (req, res) => {
    try {
      let userId;
      try {
        userId = getUserId(req);
      } catch (authError) {
        return res.status(401).json({
          error: 'Authentication required',
          message: 'Please log in to create conversations',
          code: 'AUTH_REQUIRED'
        });
      }
      const { characterId, title } = req.body;

      console.log(`[BRIDGE] POST /api/conversations - creating for user ${userId}, character ${characterId}`);

      if (!characterId) {
        return res.status(400).json({ error: 'characterId required' });
      }

      // Create new conversation
      const result = await db.query(
        `INSERT INTO conversations (user_id, model_type, title, message_count, created_at, updated_at)
         VALUES (?, ?, ?, 0, datetime('now'), datetime('now'))
         RETURNING *`,
        [userId, characterId, title || 'New Conversation']
      );

      const conversation = result.rows ? result.rows[0] : result[0];
      console.log(`[BRIDGE] Created conversation ${conversation.id} for user ${userId}`);

      return res.json(conversation);
    } catch (error) {
      console.error('[BRIDGE] Error creating conversation:', error);
      return res.status(500).json({ error: 'Failed to create conversation' });
    }
  });

  /**
   * GET /api/conversations/:id
   * Get a specific conversation
   */
  app.get('/api/conversations/:id', async (req, res) => {
    try {
      let userId;
      try {
        userId = getUserId(req);
      } catch (authError) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED'
        });
      }
      const { id: conversationId } = req.params;

      console.log(`[BRIDGE] GET /api/conversations/${conversationId} for user ${userId}`);

      const result = await db.query(
        `SELECT * FROM conversations WHERE id = ? AND user_id = ?`,
        [conversationId, userId]
      );

      const conversation = result.rows ? result.rows[0] : result[0];

      if (!conversation) {
        return res.status(404).json({ error: 'Conversation not found' });
      }

      return res.json(conversation);
    } catch (error) {
      console.error('[BRIDGE] Error fetching conversation:', error);
      return res.status(500).json({ error: 'Failed to fetch conversation' });
    }
  });

  /**
   * GET /api/conversations/:id/messages
   * Get messages in a specific conversation
   */
  app.get('/api/conversations/:id/messages', async (req, res) => {
    try {
      let userId;
      try {
        userId = getUserId(req);
      } catch (authError) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED'
        });
      }
      const { id: conversationId } = req.params;
      const { page = 0, limit = 50 } = req.query;

      console.log(`[BRIDGE] GET /api/conversations/${conversationId}/messages for user ${userId}`);

      // Verify conversation belongs to user
      const convResult = await db.query(
        'SELECT id FROM conversations WHERE id = ? AND user_id = ?',
        [conversationId, userId]
      );

      const conv = convResult.rows ? convResult.rows[0] : convResult[0];
      if (!conv) {
        return res.status(404).json({ error: 'Conversation not found' });
      }

      // Get messages in chronological order (oldest first)
      // FIXED: Query in ASC order directly instead of DESC then reversing
      const messagesResult = await db.query(
        `SELECT * FROM messages WHERE conversation_uuid = ? ORDER BY created_at ASC LIMIT ? OFFSET ?`,
        [conversationId, parseInt(limit), parseInt(page) * parseInt(limit)]
      );

      const messages = messagesResult.rows || messagesResult || [];

      // Get total count
      const countResult = await db.query(
        'SELECT COUNT(*) as total FROM messages WHERE conversation_uuid = ?',
        [conversationId]
      );

      const total = countResult.rows ? countResult.rows[0].total : countResult[0]?.total || 0;
      const hasMore = (parseInt(page) + 1) * parseInt(limit) < total;

      console.log(`[BRIDGE] Returning ${messages.length} messages for conversation ${conversationId}`);

      return res.json({
        messages: messages, // Already in chronological order from query
        total,
        hasMore,
        page: parseInt(page),
        limit: parseInt(limit)
      });
    } catch (error) {
      console.error('[BRIDGE] Error fetching messages:', error);
      return res.status(500).json({ error: 'Failed to fetch messages' });
    }
  });

  /**
   * POST /api/conversations/:id/messages
   * Send a message in a conversation
   * This delegates to the /api/chat endpoint with proper character mapping
   */
  app.post('/api/conversations/:id/messages', async (req, res) => {
    try {
      let userId;
      try {
        userId = getUserId(req);
      } catch (authError) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED'
        });
      }
      const { id: conversationId } = req.params;
      const { content, metadata = {} } = req.body;

      console.log(`[BRIDGE] POST /api/conversations/${conversationId}/messages - user ${userId}`);

      if (!content) {
        return res.status(400).json({ error: 'Message content required' });
      }

      // Verify conversation exists and belongs to user
      const convResult = await db.query(
        'SELECT model_type, title FROM conversations WHERE id = ? AND user_id = ?',
        [conversationId, userId]
      );

      const conv = convResult.rows ? convResult.rows[0] : convResult[0];
      if (!conv) {
        return res.status(404).json({ error: 'Conversation not found' });
      }

      // Get character ID from conversation (stored in model_type field)
      const characterId = conv.model_type;

      console.log(`[BRIDGE] Sending message to character ${characterId} in conversation ${conversationId}`);

      // Get conversation history for context
      // FIXED: Database uses 'sender_type' not 'role'
      const historyResult = await db.query(
        `SELECT sender_type as role, content, created_at
         FROM messages
         WHERE conversation_uuid = ?
         ORDER BY created_at ASC
         LIMIT 50`,
        [conversationId]
      );

      const history = (historyResult.rows || historyResult || []).map(msg => ({
        role: msg.role,
        content: msg.content
      }));

      // Check if this is a custom character
      const customCharResult = await db.query(
        'SELECT * FROM custom_characters WHERE id = ? AND user_id = ?',
        [characterId, userId]
      );

      const customChar = customCharResult.rows ? customCharResult.rows[0] : customCharResult[0];
      const isCustomCharacter = !!customChar;

      // Prepare custom character config if it's a custom character
      let customCharacterConfig = null;
      let characterName = characterId;

      if (isCustomCharacter) {
        customCharacterConfig = {
          name: customChar.name,
          personality: customChar.personality,
          systemPrompt: customChar.system_prompt,
          description: customChar.description,
          config: customChar.config ? JSON.parse(customChar.config) : {}
        };
        characterName = customChar.name;
      }

      // Create request body for /api/chat endpoint
      const chatRequestBody = {
        message: content,
        character: characterId,
        history: history,
        conversationId: conversationId,
        isCustomCharacter: isCustomCharacter,
        customCharacterConfig: customCharacterConfig,
        characterName: characterName,
        userId: userId
      };

      // Forward request to /api/chat endpoint internally
      // Create a new request object with the chat endpoint data
      const chatReq = {
        body: chatRequestBody,
        headers: req.headers,
        requestId: req.requestId || `req_${Date.now()}`
      };

      // Import or access the chat handler
      // For now, we'll make an internal HTTP call to maintain separation
      const axios = require('axios');
      const port = process.env.PORT || 3333;

      try {
        const chatResponse = await axios.post(
          `http://localhost:${port}/api/chat`,
          chatRequestBody,
          {
            headers: {
              'Content-Type': 'application/json',
              'Authorization': req.headers.authorization || ''
            },
            timeout: 60000 // 60 second timeout for AI response
          }
        );

        // Return response in expected format
        return res.json({
          message: {
            id: `msg_${Date.now()}`,
            conversationId: conversationId,
            role: 'user',
            content: content,
            timestamp: new Date().toISOString()
          },
          response: {
            id: `msg_${Date.now() + 1}`,
            conversationId: conversationId,
            role: 'assistant',
            content: chatResponse.data.response || chatResponse.data,
            timestamp: new Date().toISOString()
          }
        });
      } catch (chatError) {
        console.error('[BRIDGE] Error calling chat endpoint:', chatError.message);
        throw new Error('Failed to generate AI response');
      }

    } catch (error) {
      console.error('[BRIDGE] Error sending message:', error);
      return res.status(500).json({
        error: 'Failed to send message',
        message: error.message
      });
    }
  });

  console.log('[BRIDGE] Conversations API bridge initialized');
}

module.exports = { setupConversationsAPIBridge };
