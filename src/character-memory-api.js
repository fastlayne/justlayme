/**
 * Character Memory API
 *
 * Enables characters to remember important facts, preferences, and events about users
 * Characters become more personalized and contextually aware over time
 *
 * Features:
 * - Memory storage and retrieval
 * - Importance scoring
 * - Memory decay over time
 * - Automatic memory extraction from conversations
 */

const express = require('express');
const router = express.Router();
const { authenticateToken } = require('./middleware/auth');

/**
 * Extract memories from conversation using LLM
 * @param {string} userMessage - The user's message
 * @param {string} aiResponse - The AI's response
 * @param {string} conversationContext - Recent conversation history
 * @returns {Promise<Array>} Extracted memories
 */
async function extractMemoriesFromConversation(userMessage, aiResponse, conversationContext = '') {
    try {
        const extractionPrompt = `Analyze this conversation and extract any important information worth remembering about the user.

CONVERSATION:
${conversationContext}
User: ${userMessage}
Assistant: ${aiResponse}

Extract ONLY genuinely important, memorable facts in this exact format:
[TYPE:fact] The user's name is X
[TYPE:preference] The user prefers/likes/dislikes X
[TYPE:event] The user mentioned they did/will do X
[TYPE:emotion] The user feels/felt X about Y

Rules:
- Only extract truly important information
- Be specific and concrete
- Avoid vague or generic statements
- Skip small talk or temporary states
- Each line must start with [TYPE:X]

Extracted memories:`;

        // Call LLM to extract memories
        const response = await fetch('http://localhost:11434/api/generate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                model: process.env.LLM_MODEL || 'sushruth/solar-uncensored',
                prompt: extractionPrompt,
                stream: false,
                options: {
                    temperature: 0.3, // Low temperature for factual extraction
                    num_ctx: 2048,
                    top_p: 0.9
                }
            })
        });

        if (!response.ok) {
            console.warn('Memory extraction LLM call failed');
            return [];
        }

        const data = await response.json();
        const extractedText = data.response || '';

        // Parse extracted memories
        const memories = [];
        const lines = extractedText.split('\n');

        for (const line of lines) {
            const match = line.match(/\[TYPE:(fact|preference|event|emotion)\]\s*(.+)/i);
            if (match) {
                const [, type, content] = match;
                if (content.trim().length > 10) { // Minimum length filter
                    memories.push({
                        type: type.toLowerCase(),
                        content: content.trim(),
                        importance: calculateImportance(type, content)
                    });
                }
            }
        }

        console.log(`🧠 Extracted ${memories.length} memories from conversation`);
        return memories;

    } catch (error) {
        console.error('Memory extraction error:', error);
        return [];
    }
}

/**
 * Calculate importance score for a memory
 * @param {string} type - Memory type
 * @param {string} content - Memory content
 * @returns {number} Importance score (0-1)
 */
function calculateImportance(type, content) {
    let base = 0.5;

    // Type-based scoring
    const typeScores = {
        fact: 0.7,      // Names, jobs, locations - high importance
        preference: 0.6, // Likes/dislikes - medium-high
        event: 0.5,     // Things that happened - medium
        emotion: 0.4    // Emotional states - lower (can change)
    };

    base = typeScores[type] || 0.5;

    // Boost for specific keywords
    const importantKeywords = [
        'name is', 'work at', 'live in', 'married', 'birthday',
        'family', 'job', 'career', 'studying', 'love', 'hate'
    ];

    for (const keyword of importantKeywords) {
        if (content.toLowerCase().includes(keyword)) {
            base = Math.min(1.0, base + 0.1);
            break;
        }
    }

    return Math.round(base * 100) / 100; // Round to 2 decimals
}

/**
 * Store a memory for a character
 * @param {Object} db - Database instance
 * @param {Object} memory - Memory object
 * @returns {Promise<string>} Memory ID
 */
async function storeMemory(db, { characterId, userId, conversationId, type, content, importance }) {
    const memoryId = `mem_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    await db.query(
        `INSERT INTO character_interaction_memories
         (id, character_id, user_id, conversation_id, memory_type, memory_content, importance_score)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [memoryId, characterId, userId, conversationId, type, content, importance]
    );

    console.log(`💾 Stored memory ${memoryId} for character ${characterId}`);
    return memoryId;
}

/**
 * Retrieve relevant memories for a character-user pair
 * @param {Object} db - Database instance
 * @param {string} characterId - Character ID
 * @param {string} userId - User ID
 * @param {number} limit - Maximum memories to retrieve
 * @returns {Promise<Array>} Relevant memories
 */
async function getRelevantMemories(db, characterId, userId, limit = 5) {
    try {
        const result = await db.query(
            `SELECT id, memory_type, memory_content, importance_score, mentioned_count, created_at
             FROM character_interaction_memories
             WHERE character_id = ? AND user_id = ?
             ORDER BY importance_score DESC, last_accessed DESC
             LIMIT ?`,
            [characterId, userId, limit]
        );

        const memories = result.rows || result || [];

        // Update last_accessed for retrieved memories
        if (memories.length > 0) {
            const memoryIds = memories.map(m => m.id);
            await db.query(
                `UPDATE character_interaction_memories
                 SET last_accessed = datetime('now')
                 WHERE id IN (${memoryIds.map(() => '?').join(',')})`,
                memoryIds
            );
        }

        return memories;
    } catch (error) {
        console.error('Error retrieving memories:', error);
        return [];
    }
}

/**
 * Format memories for injection into character prompt
 * @param {Array} memories - Array of memory objects
 * @returns {string} Formatted memory context
 */
function formatMemoriesForPrompt(memories) {
    if (!memories || memories.length === 0) {
        return '';
    }

    const formatted = memories.map(m => {
        const typeEmoji = {
            fact: '📌',
            preference: '❤️',
            event: '📅',
            emotion: '😊'
        };
        return `${typeEmoji[m.memory_type] || '•'} ${m.memory_content}`;
    }).join('\n');

    return `\n\n[IMPORTANT MEMORIES ABOUT THIS USER]\nYou remember the following about this user from past conversations:\n${formatted}\n\nUse these memories naturally in conversation when relevant. Don't explicitly say "I remember..." unless it feels natural.\n`;
}

// ============================================================================
// API ROUTES
// ============================================================================

/**
 * GET /api/characters/:characterId/memories/:userId
 * Get all memories for a character-user pair
 */
router.get('/api/characters/:characterId/memories/:userId',
    authenticateToken,
    async (req, res) => {
        const { characterId, userId } = req.params;
        const { limit = 20 } = req.query;

        // Verify user ownership
        if (String(req.user.id) !== String(userId)) {
            return res.status(403).json({ error: 'Access denied' });
        }

        const db = req.app.get('db');
        if (!db) {
            return res.status(500).json({ error: 'Database not initialized' });
        }

        try {
            const memories = await getRelevantMemories(db, characterId, userId, parseInt(limit));

            res.json({
                characterId,
                userId,
                memories: memories.map(m => ({
                    id: m.id,
                    type: m.memory_type,
                    content: m.memory_content,
                    importance: m.importance_score,
                    mentionedCount: m.mentioned_count,
                    createdAt: m.created_at
                })),
                total: memories.length
            });
        } catch (error) {
            console.error('Error fetching memories:', error);
            res.status(500).json({ error: 'Failed to fetch memories' });
        }
    }
);

/**
 * POST /api/characters/:characterId/memories
 * Manually add a memory for a character
 */
router.post('/api/characters/:characterId/memories',
    authenticateToken,
    async (req, res) => {
        const { characterId } = req.params;
        const { userId, conversationId, type, content, importance } = req.body;

        // Verify user ownership
        if (String(req.user.id) !== String(userId)) {
            return res.status(403).json({ error: 'Access denied' });
        }

        // Validate inputs
        if (!userId || !conversationId || !type || !content) {
            return res.status(400).json({ error: 'Missing required fields' });
        }

        const validTypes = ['fact', 'preference', 'event', 'emotion'];
        if (!validTypes.includes(type)) {
            return res.status(400).json({ error: 'Invalid memory type' });
        }

        const db = req.app.get('db');
        if (!db) {
            return res.status(500).json({ error: 'Database not initialized' });
        }

        try {
            const memoryId = await storeMemory(db, {
                characterId,
                userId,
                conversationId,
                type,
                content,
                importance: importance || calculateImportance(type, content)
            });

            res.json({
                success: true,
                memoryId,
                message: 'Memory stored successfully'
            });
        } catch (error) {
            console.error('Error storing memory:', error);
            res.status(500).json({ error: 'Failed to store memory' });
        }
    }
);

/**
 * DELETE /api/characters/:characterId/memories/:memoryId
 * Delete a specific memory
 */
router.delete('/api/characters/:characterId/memories/:memoryId',
    authenticateToken,
    async (req, res) => {
        const { characterId, memoryId } = req.params;
        const userId = req.user.id;

        const db = req.app.get('db');
        if (!db) {
            return res.status(500).json({ error: 'Database not initialized' });
        }

        try {
            // Verify ownership before deleting
            const result = await db.query(
                `DELETE FROM character_interaction_memories
                 WHERE id = ? AND character_id = ? AND user_id = ?`,
                [memoryId, characterId, userId]
            );

            const deleted = result.changes || result.rowCount || 0;

            if (deleted === 0) {
                return res.status(404).json({ error: 'Memory not found or access denied' });
            }

            res.json({ success: true, message: 'Memory deleted' });
        } catch (error) {
            console.error('Error deleting memory:', error);
            res.status(500).json({ error: 'Failed to delete memory' });
        }
    }
);

/**
 * GET /api/characters/:characterId/memories/:userId/stats
 * Get memory statistics for a character
 */
router.get('/api/characters/:characterId/memories/:userId/stats',
    authenticateToken,
    async (req, res) => {
        const { characterId, userId } = req.params;

        // Verify user ownership
        if (String(req.user.id) !== String(userId)) {
            return res.status(403).json({ error: 'Access denied' });
        }

        const db = req.app.get('db');
        if (!db) {
            return res.status(500).json({ error: 'Database not initialized' });
        }

        try {
            const stats = await db.query(
                `SELECT
                    COUNT(*) as total_memories,
                    COUNT(CASE WHEN memory_type = 'fact' THEN 1 END) as facts,
                    COUNT(CASE WHEN memory_type = 'preference' THEN 1 END) as preferences,
                    COUNT(CASE WHEN memory_type = 'event' THEN 1 END) as events,
                    COUNT(CASE WHEN memory_type = 'emotion' THEN 1 END) as emotions,
                    AVG(importance_score) as avg_importance,
                    MAX(importance_score) as max_importance
                 FROM character_interaction_memories
                 WHERE character_id = ? AND user_id = ?`,
                [characterId, userId]
            );

            const row = stats.rows ? stats.rows[0] : stats[0];

            res.json({
                characterId,
                userId,
                stats: {
                    totalMemories: row.total_memories || 0,
                    byType: {
                        facts: row.facts || 0,
                        preferences: row.preferences || 0,
                        events: row.events || 0,
                        emotions: row.emotions || 0
                    },
                    avgImportance: Math.round((row.avg_importance || 0) * 100) / 100,
                    maxImportance: row.max_importance || 0
                }
            });
        } catch (error) {
            console.error('Error fetching memory stats:', error);
            res.status(500).json({ error: 'Failed to fetch stats' });
        }
    }
);

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
    router,
    extractMemoriesFromConversation,
    getRelevantMemories,
    formatMemoriesForPrompt,
    storeMemory,
    calculateImportance
};
