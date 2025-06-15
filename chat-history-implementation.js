// Chat History Implementation for JustLayMe Premium Users
// This file contains the implementation for managing conversation history

const { v4: uuidv4 } = require('uuid');

class ConversationManager {
    constructor(pg) {
        this.pg = pg;
    }

    // Create or get existing conversation
    async getOrCreateConversation(userId, modelType) {
        try {
            // First, try to get existing active conversation
            let result = await this.pg.query(`
                SELECT * FROM conversations 
                WHERE user_id = $1 AND model_type = $2 AND is_archived = FALSE
                ORDER BY updated_at DESC
                LIMIT 1
            `, [userId, modelType]);

            if (result.rows.length > 0) {
                return result.rows[0];
            }

            // Create new conversation
            const title = await this.generateConversationTitle(modelType);
            result = await this.pg.query(`
                INSERT INTO conversations (user_id, model_type, title)
                VALUES ($1, $2, $3)
                RETURNING *
            `, [userId, modelType, title]);

            return result.rows[0];
        } catch (error) {
            console.error('Error managing conversation:', error);
            throw error;
        }
    }

    // Generate smart conversation title based on first message
    async generateConversationTitle(modelType) {
        const modelNames = {
            'uncensored_gpt': 'Uncensored GPT',
            'roleplay': 'Roleplay AI',
            'creative_writer': 'Creative Writer',
            'assistant': 'Personal Assistant',
            'casual_chat': 'Casual Chat'
        };
        
        return `${modelNames[modelType] || 'AI Chat'} - ${new Date().toLocaleDateString()}`;
    }

    // Update conversation title based on content
    async updateConversationTitle(conversationId, messages) {
        if (messages.length < 2) return;

        const firstUserMessage = messages.find(m => m.sender_type === 'human');
        if (!firstUserMessage) return;

        // Create a smart title based on the first message (max 50 chars)
        let title = firstUserMessage.content.substring(0, 50);
        if (firstUserMessage.content.length > 50) {
            title += '...';
        }

        await this.pg.query(`
            UPDATE conversations 
            SET title = $1, updated_at = NOW()
            WHERE id = $2
        `, [title, conversationId]);
    }

    // Get user's conversation list with pagination
    async getUserConversations(userId, options = {}) {
        const {
            page = 1,
            limit = 20,
            modelType = null,
            isArchived = false,
            searchQuery = null,
            orderBy = 'updated_at',
            orderDirection = 'DESC'
        } = options;

        const offset = (page - 1) * limit;
        let query = `
            SELECT 
                c.*,
                COUNT(m.id) as total_messages,
                MAX(m.created_at) as last_message_time,
                (
                    SELECT content FROM messages 
                    WHERE conversation_uuid = c.id 
                    ORDER BY created_at DESC 
                    LIMIT 1
                ) as last_message_preview
            FROM conversations c
            LEFT JOIN messages m ON m.conversation_uuid = c.id
            WHERE c.user_id = $1 AND c.is_archived = $2
        `;
        
        const params = [userId, isArchived];
        let paramIndex = 3;

        if (modelType) {
            query += ` AND c.model_type = $${paramIndex}`;
            params.push(modelType);
            paramIndex++;
        }

        if (searchQuery) {
            query += ` AND (c.title ILIKE $${paramIndex} OR EXISTS (
                SELECT 1 FROM messages 
                WHERE conversation_uuid = c.id 
                AND content ILIKE $${paramIndex}
            ))`;
            params.push(`%${searchQuery}%`);
            paramIndex++;
        }

        query += ` GROUP BY c.id ORDER BY ${orderBy} ${orderDirection} LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
        params.push(limit, offset);

        const result = await this.pg.query(query, params);

        // Get total count for pagination
        const countQuery = `
            SELECT COUNT(DISTINCT c.id) as total
            FROM conversations c
            WHERE c.user_id = $1 AND c.is_archived = $2
            ${modelType ? `AND c.model_type = $3` : ''}
        `;
        const countParams = modelType ? [userId, isArchived, modelType] : [userId, isArchived];
        const countResult = await this.pg.query(countQuery, countParams);

        return {
            conversations: result.rows,
            pagination: {
                page,
                limit,
                total: parseInt(countResult.rows[0].total),
                totalPages: Math.ceil(parseInt(countResult.rows[0].total) / limit)
            }
        };
    }

    // Get conversation messages with pagination
    async getConversationMessages(conversationId, userId, options = {}) {
        const {
            page = 1,
            limit = 50,
            orderDirection = 'ASC'
        } = options;

        const offset = (page - 1) * limit;

        // Verify user owns the conversation
        const ownerCheck = await this.pg.query(`
            SELECT id FROM conversations WHERE id = $1 AND user_id = $2
        `, [conversationId, userId]);

        if (ownerCheck.rows.length === 0) {
            throw new Error('Conversation not found or access denied');
        }

        const result = await this.pg.query(`
            SELECT 
                m.*,
                CASE 
                    WHEN m.sender_type = 'ai' THEN c.metadata->>'character_name'
                    ELSE 'You'
                END as sender_name
            FROM messages m
            LEFT JOIN conversations c ON c.id = m.conversation_uuid
            WHERE m.conversation_uuid = $1 
            AND m.is_deleted = FALSE
            ORDER BY m.created_at ${orderDirection}
            LIMIT $2 OFFSET $3
        `, [conversationId, limit, offset]);

        return result.rows;
    }

    // Search across all conversations
    async searchConversations(userId, searchQuery, options = {}) {
        const { limit = 20 } = options;

        const result = await this.pg.query(`
            SELECT DISTINCT
                c.*,
                m.content as matching_message,
                m.created_at as message_time,
                ts_rank(to_tsvector('english', m.content), plainto_tsquery('english', $2)) as relevance
            FROM conversations c
            JOIN messages m ON m.conversation_uuid = c.id
            WHERE c.user_id = $1 
            AND m.content ILIKE $3
            ORDER BY relevance DESC, m.created_at DESC
            LIMIT $4
        `, [userId, searchQuery, `%${searchQuery}%`, limit]);

        return result.rows;
    }

    // Archive/unarchive conversation
    async archiveConversation(conversationId, userId, archive = true) {
        const result = await this.pg.query(`
            UPDATE conversations 
            SET is_archived = $1, updated_at = NOW()
            WHERE id = $2 AND user_id = $3
            RETURNING *
        `, [archive, conversationId, userId]);

        return result.rows[0];
    }

    // Delete conversation (soft delete)
    async deleteConversation(conversationId, userId) {
        // Soft delete messages first
        await this.pg.query(`
            UPDATE messages 
            SET is_deleted = TRUE, deleted_at = NOW()
            WHERE conversation_uuid = $1
        `, [conversationId]);

        // Archive the conversation
        return this.archiveConversation(conversationId, userId, true);
    }

    // Export conversation
    async exportConversation(conversationId, userId, format = 'json') {
        const conversation = await this.pg.query(`
            SELECT * FROM conversations 
            WHERE id = $1 AND user_id = $2
        `, [conversationId, userId]);

        if (conversation.rows.length === 0) {
            throw new Error('Conversation not found');
        }

        const messages = await this.getConversationMessages(conversationId, userId, {
            limit: 10000, // Get all messages
            orderDirection: 'ASC'
        });

        const exportData = {
            conversation: conversation.rows[0],
            messages: messages,
            exportedAt: new Date().toISOString()
        };

        switch (format) {
            case 'json':
                return JSON.stringify(exportData, null, 2);
            
            case 'txt':
                return this.formatAsText(exportData);
            
            case 'markdown':
                return this.formatAsMarkdown(exportData);
            
            default:
                throw new Error('Unsupported export format');
        }
    }

    formatAsText(data) {
        let text = `Conversation: ${data.conversation.title}\n`;
        text += `Date: ${data.conversation.created_at}\n`;
        text += `Model: ${data.conversation.model_type}\n`;
        text += `${'='.repeat(50)}\n\n`;

        data.messages.forEach(msg => {
            const sender = msg.sender_type === 'human' ? 'You' : msg.sender_name;
            const time = new Date(msg.created_at).toLocaleString();
            text += `[${time}] ${sender}:\n${msg.content}\n\n`;
        });

        return text;
    }

    formatAsMarkdown(data) {
        let md = `# ${data.conversation.title}\n\n`;
        md += `**Date:** ${new Date(data.conversation.created_at).toLocaleDateString()}\n`;
        md += `**Model:** ${data.conversation.model_type}\n\n`;
        md += `---\n\n`;

        data.messages.forEach(msg => {
            const sender = msg.sender_type === 'human' ? '**You**' : `**${msg.sender_name}**`;
            const time = new Date(msg.created_at).toLocaleTimeString();
            md += `${sender} _[${time}]_\n\n${msg.content}\n\n---\n\n`;
        });

        return md;
    }
}

// API Endpoints for chat history
const chatHistoryEndpoints = {
    // Get user's conversations
    '/api/conversations': async (req, res, pg, conversationManager) => {
        try {
            const userId = req.user.id;
            const options = {
                page: parseInt(req.query.page) || 1,
                limit: parseInt(req.query.limit) || 20,
                modelType: req.query.model_type,
                isArchived: req.query.archived === 'true',
                searchQuery: req.query.search,
                orderBy: req.query.order_by || 'updated_at',
                orderDirection: req.query.order_dir || 'DESC'
            };

            const result = await conversationManager.getUserConversations(userId, options);
            res.json(result);
        } catch (error) {
            console.error('Error fetching conversations:', error);
            res.status(500).json({ error: 'Failed to fetch conversations' });
        }
    },

    // Get specific conversation messages
    '/api/conversations/:id/messages': async (req, res, pg, conversationManager) => {
        try {
            const userId = req.user.id;
            const conversationId = req.params.id;
            const options = {
                page: parseInt(req.query.page) || 1,
                limit: parseInt(req.query.limit) || 50,
                orderDirection: req.query.order_dir || 'ASC'
            };

            const messages = await conversationManager.getConversationMessages(
                conversationId, 
                userId, 
                options
            );
            res.json({ messages });
        } catch (error) {
            console.error('Error fetching messages:', error);
            res.status(500).json({ error: error.message || 'Failed to fetch messages' });
        }
    },

    // Search conversations
    '/api/conversations/search': async (req, res, pg, conversationManager) => {
        try {
            const userId = req.user.id;
            const { q: searchQuery } = req.query;

            if (!searchQuery) {
                return res.status(400).json({ error: 'Search query required' });
            }

            const results = await conversationManager.searchConversations(
                userId, 
                searchQuery
            );
            res.json({ results });
        } catch (error) {
            console.error('Search error:', error);
            res.status(500).json({ error: 'Search failed' });
        }
    },

    // Archive conversation
    '/api/conversations/:id/archive': async (req, res, pg, conversationManager) => {
        try {
            const userId = req.user.id;
            const conversationId = req.params.id;
            const { archive = true } = req.body;

            const result = await conversationManager.archiveConversation(
                conversationId, 
                userId, 
                archive
            );
            res.json({ success: true, conversation: result });
        } catch (error) {
            console.error('Archive error:', error);
            res.status(500).json({ error: 'Failed to archive conversation' });
        }
    },

    // Delete conversation
    '/api/conversations/:id': async (req, res, pg, conversationManager) => {
        if (req.method !== 'DELETE') {
            return res.status(405).json({ error: 'Method not allowed' });
        }

        try {
            const userId = req.user.id;
            const conversationId = req.params.id;

            await conversationManager.deleteConversation(conversationId, userId);
            res.json({ success: true });
        } catch (error) {
            console.error('Delete error:', error);
            res.status(500).json({ error: 'Failed to delete conversation' });
        }
    },

    // Export conversation
    '/api/conversations/:id/export': async (req, res, pg, conversationManager) => {
        try {
            const userId = req.user.id;
            const conversationId = req.params.id;
            const { format = 'json' } = req.query;

            // Check if user is premium
            const userResult = await pg.query(`
                SELECT subscription_status FROM users WHERE id = $1
            `, [userId]);

            if (userResult.rows[0].subscription_status === 'free') {
                return res.status(403).json({ 
                    error: 'Export feature is only available for premium users' 
                });
            }

            const exportData = await conversationManager.exportConversation(
                conversationId, 
                userId, 
                format
            );

            // Set appropriate headers based on format
            const contentTypes = {
                'json': 'application/json',
                'txt': 'text/plain',
                'markdown': 'text/markdown'
            };

            res.setHeader('Content-Type', contentTypes[format] || 'text/plain');
            res.setHeader('Content-Disposition', 
                `attachment; filename="conversation-${conversationId}.${format}"`
            );
            
            res.send(exportData);
        } catch (error) {
            console.error('Export error:', error);
            res.status(500).json({ error: error.message || 'Export failed' });
        }
    },

    // Tag management
    '/api/tags': async (req, res, pg) => {
        if (req.method === 'GET') {
            try {
                const userId = req.user.id;
                const result = await pg.query(`
                    SELECT * FROM conversation_tags 
                    WHERE user_id = $1 
                    ORDER BY tag_name
                `, [userId]);
                res.json({ tags: result.rows });
            } catch (error) {
                res.status(500).json({ error: 'Failed to fetch tags' });
            }
        } else if (req.method === 'POST') {
            try {
                const userId = req.user.id;
                const { tag_name, color } = req.body;

                const result = await pg.query(`
                    INSERT INTO conversation_tags (user_id, tag_name, color)
                    VALUES ($1, $2, $3)
                    RETURNING *
                `, [userId, tag_name, color || '#6B46FF']);

                res.json({ tag: result.rows[0] });
            } catch (error) {
                if (error.code === '23505') {
                    res.status(400).json({ error: 'Tag already exists' });
                } else {
                    res.status(500).json({ error: 'Failed to create tag' });
                }
            }
        }
    },

    // Add tag to conversation
    '/api/conversations/:id/tags': async (req, res, pg) => {
        try {
            const userId = req.user.id;
            const conversationId = req.params.id;
            const { tag_id } = req.body;

            // Verify ownership
            const ownerCheck = await pg.query(`
                SELECT id FROM conversations WHERE id = $1 AND user_id = $2
            `, [conversationId, userId]);

            if (ownerCheck.rows.length === 0) {
                return res.status(404).json({ error: 'Conversation not found' });
            }

            await pg.query(`
                INSERT INTO conversation_tag_mappings (conversation_id, tag_id)
                VALUES ($1, $2)
                ON CONFLICT DO NOTHING
            `, [conversationId, tag_id]);

            res.json({ success: true });
        } catch (error) {
            res.status(500).json({ error: 'Failed to add tag' });
        }
    }
};

// Middleware to check premium status for chat history
function requirePremiumForHistory(req, res, next) {
    pg.query(`
        SELECT subscription_status FROM users WHERE id = $1
    `, [req.user.id]).then(result => {
        if (result.rows.length > 0 && result.rows[0].subscription_status === 'free') {
            // Allow limited access for free users (last 3 conversations)
            req.limitedAccess = true;
        }
        next();
    }).catch(err => {
        res.status(500).json({ error: 'Subscription check failed' });
    });
}

module.exports = {
    ConversationManager,
    chatHistoryEndpoints,
    requirePremiumForHistory
};