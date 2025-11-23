// Optimized SQLite fallback for chat history when Supabase is unavailable
const Database = require('./database');
const db = Database.getInstance();

// Connection pooling and prepared statements
let preparedStatements = {};
const initializePreparedStatements = () => {
    try {
        preparedStatements = {
            createConversation: db.db.prepare(`
                INSERT INTO conversations (user_id, model_type, title, message_count, created_at, updated_at) 
                VALUES (?, ?, ?, 0, datetime('now'), datetime('now'))
            `),
            saveMessage: db.db.prepare(`
                INSERT INTO messages (conversation_uuid, sender_type, content, metadata, created_at) 
                VALUES (?, ?, ?, ?, datetime('now'))
            `),
            updateConversation: db.db.prepare(`
                UPDATE conversations 
                SET updated_at = datetime('now'), message_count = message_count + 1 
                WHERE id = ?
            `),
            getConversations: db.db.prepare(`
                SELECT * FROM conversations 
                WHERE user_id = ? AND is_archived = 0 
                ORDER BY updated_at DESC
            `),
            getMessages: db.db.prepare(`
                SELECT * FROM messages 
                WHERE conversation_uuid = ? 
                ORDER BY created_at ASC
            `)
        };
    } catch (error) {
        console.error('Failed to initialize prepared statements:', error);
    }
};

// Initialize prepared statements on module load
initializePreparedStatements();

// Helper function to convert UUID to numeric ID for SQLite
function convertUserId(userId) {
    if (typeof userId === 'string' && userId.includes('-')) {
        // Convert UUID to a stable numeric hash
        return Math.abs(userId.split('-').join('').substring(0, 10).split('').reduce((a, b) => a + b.charCodeAt(0), 0));
    }
    return userId;
}

// Chat history functions using local SQLite
async function createConversation(userId, characterId, title, characterName = null) {
    try {
        const numericUserId = convertUserId(userId);
        
        // Use character name if provided, otherwise use characterId as fallback
        const modelType = characterName || characterId;
        
        const result = await db.query(
            `INSERT INTO conversations (user_id, model_type, title, message_count, created_at, updated_at) 
             VALUES (?, ?, ?, 0, datetime('now'), datetime('now'))
             RETURNING *`,
            [numericUserId, modelType, title || 'New Conversation']
        );
        // Format the response to match Supabase format
        const conversation = result.rows[0];
        return {
            ...conversation,
            updated_at: conversation.updated_at || conversation.created_at
        };
    } catch (error) {
        console.error('SQLite createConversation error:', error);
        throw error;
    }
}

async function saveMessage(conversationId, userId, role, content, characterId = null) {
    try {
        const result = await db.query(
            `INSERT INTO messages (conversation_uuid, sender_type, content, metadata, created_at) 
             VALUES (?, ?, ?, ?, datetime('now'))
             RETURNING *`,
            [conversationId, role, content, JSON.stringify({ character_id: characterId })]
        );
        
        // Update conversation's updated_at and message_count
        await db.query(
            `UPDATE conversations 
             SET updated_at = datetime('now'), 
                 message_count = message_count + 1 
             WHERE id = ?`,
            [conversationId]
        );
        
        return result.rows[0];
    } catch (error) {
        console.error('SQLite saveMessage error:', error);
        throw error;
    }
}

async function getUserConversations(userId, limit = 20) {
    try {
        const numericUserId = convertUserId(userId);
        
        // Enhanced query to get conversation info with last user message timestamp
        const result = await db.query(
            `SELECT 
                c.*,
                c.model_type as character_id,
                CASE 
                    WHEN c.model_type = 'layme_v1' THEN 'Layme v1'
                    WHEN c.model_type = 'roleplay' THEN 'Roleplay'
                    WHEN c.model_type LIKE 'char_%' THEN (
                        SELECT name FROM custom_characters cc WHERE cc.id = c.model_type LIMIT 1
                    )
                    ELSE UPPER(SUBSTR(c.model_type, 1, 1)) || SUBSTR(c.model_type, 2, LENGTH(c.model_type))
                END as character_name,
                (SELECT created_at 
                 FROM messages m 
                 WHERE m.conversation_uuid = c.id 
                   AND m.sender_type = 'user' 
                 ORDER BY m.created_at DESC 
                 LIMIT 1) as last_user_message_time,
                (SELECT content 
                 FROM messages m 
                 WHERE m.conversation_uuid = c.id 
                   AND m.sender_type = 'user' 
                 ORDER BY m.created_at DESC 
                 LIMIT 1) as last_user_message
             FROM conversations c
             WHERE c.user_id = ? AND c.is_archived = 0
             ORDER BY c.updated_at DESC 
             LIMIT ?`,
            [numericUserId, limit]
        );
        return result.rows;
    } catch (error) {
        console.error('SQLite getUserConversations error:', error);
        throw error;
    }
}

async function getConversationMessages(conversationId, userId) {
    try {
        const numericUserId = convertUserId(userId);
        
        // First verify the conversation belongs to the user
        const convCheck = await db.query(
            `SELECT id FROM conversations WHERE id = ? AND user_id = ?`,
            [conversationId, numericUserId]
        );
        
        if (convCheck.rows.length === 0) {
            throw new Error('Conversation not found or access denied');
        }
        
        const result = await db.query(
            `SELECT * FROM messages 
             WHERE conversation_uuid = ? AND is_deleted = 0
             ORDER BY created_at ASC`,
            [conversationId]
        );
        
        // Transform to match expected format
        return result.rows.map(msg => {
            let characterId = null;
            try {
                // Handle double-escaped JSON from database sanitization
                let metadata = msg.metadata || '{}';
                
                // Fix double-escaped quotes if present
                if (metadata.includes('""')) {
                    metadata = metadata.replace(/""/g, '"');
                }
                
                const parsed = JSON.parse(metadata);
                characterId = parsed.character_id || null;
            } catch (jsonError) {
                console.warn('Failed to parse message metadata:', msg.metadata, jsonError.message);
                characterId = null;
            }
            
            return {
                id: msg.id,
                conversation_id: conversationId,
                user_id: userId,
                role: msg.sender_type,
                content: msg.content,
                character_id: characterId,
                created_at: msg.created_at
            };
        });
    } catch (error) {
        console.error('SQLite getConversationMessages error:', error);
        throw error;
    }
}

async function updateConversationTitle(conversationId, userId, newTitle) {
    try {
        const numericUserId = convertUserId(userId);
        
        const result = await db.query(
            `UPDATE conversations 
             SET title = ?, updated_at = datetime('now')
             WHERE id = ? AND user_id = ?
             RETURNING *`,
            [newTitle, conversationId, numericUserId]
        );
        return result.rows[0];
    } catch (error) {
        console.error('SQLite updateConversationTitle error:', error);
        throw error;
    }
}

async function deleteConversation(conversationId, userId) {
    try {
        const numericUserId = convertUserId(userId);
        
        // Soft delete by marking as archived
        await db.query(
            `UPDATE conversations 
             SET is_archived = 1, updated_at = datetime('now')
             WHERE id = ? AND user_id = ?`,
            [conversationId, numericUserId]
        );
        return true;
    } catch (error) {
        console.error('SQLite deleteConversation error:', error);
        throw error;
    }
}

// Function to auto-generate title from first message
function generateTitle(firstMessage) {
    const maxLength = 50;
    let title = firstMessage.trim();
    
    if (title.length > maxLength) {
        title = title.substring(0, maxLength) + '...';
    }
    
    return title || 'New Conversation';
}

module.exports = {
    createConversation,
    saveMessage,
    getUserConversations,
    getConversationMessages,
    updateConversationTitle,
    deleteConversation,
    generateTitle,
    convertUserId
};