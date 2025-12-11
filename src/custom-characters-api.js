const express = require('express');
const router = express.Router();
const { authenticateToken } = require('./middleware/auth');
const emailNotifications = require('./email-notifications');
const inputSanitizer = require('./utils/input-sanitizer');

// Custom characters database operations
async function setupCustomCharactersDB(db) {
    try {
        // Ensure custom_characters table exists with correct schema
        await db.query(`
            CREATE TABLE IF NOT EXISTS custom_characters (
                id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                description TEXT,
                personality TEXT NOT NULL,
                system_prompt TEXT,
                config TEXT DEFAULT '{}',
                image TEXT DEFAULT '/assets/default-avatar.png',
                is_public INTEGER DEFAULT 0,
                category TEXT DEFAULT 'custom',
                tags TEXT DEFAULT '[]',
                usage_count INTEGER DEFAULT 0,
                last_used TEXT,
                created_at TEXT DEFAULT (datetime('now')),
                updated_at TEXT DEFAULT (datetime('now'))
            )
        `);

        // Verify table schema and add missing columns for enhanced features
        try {
            const testQuery = await db.query(`
                SELECT id, user_id, name, personality, description, system_prompt, config, image, 
                       is_public, category, tags, usage_count, last_used, created_at, updated_at 
                FROM custom_characters 
                LIMIT 0
            `);
            console.log('SUCCESS Custom characters table schema verified');
        } catch (schemaError) {
            console.log('WARNING Schema verification failed, checking for missing columns:', schemaError.message);
            
            // Add enhanced feature columns if missing
            const columnsToAdd = [
                { name: 'is_public', type: 'INTEGER DEFAULT 0' },
                { name: 'category', type: 'TEXT DEFAULT \'custom\'' },
                { name: 'tags', type: 'TEXT DEFAULT \'[]\'' },
                { name: 'usage_count', type: 'INTEGER DEFAULT 0' },
                { name: 'last_used', type: 'TEXT' }
            ];
            
            for (const column of columnsToAdd) {
                try {
                    await db.query(`ALTER TABLE custom_characters ADD COLUMN ${column.name} ${column.type}`);
                    console.log(`SUCCESS Added missing ${column.name} column to custom_characters table`);
                } catch (alterError) {
                    if (!alterError.message.includes('duplicate column name')) {
                        console.warn(`WARNING Could not add ${column.name} column:`, alterError.message);
                    }
                }
            }
        }
        
        // Create indexes for faster lookups and enhanced features
        await db.query(`
            CREATE INDEX IF NOT EXISTS idx_custom_characters_user 
            ON custom_characters(user_id)
        `);
        await db.query(`
            CREATE INDEX IF NOT EXISTS idx_custom_characters_public 
            ON custom_characters(is_public, created_at DESC) WHERE is_public = 1
        `);
        await db.query(`
            CREATE INDEX IF NOT EXISTS idx_custom_characters_category 
            ON custom_characters(category)
        `);
        await db.query(`
            CREATE INDEX IF NOT EXISTS idx_custom_characters_usage 
            ON custom_characters(user_id, usage_count DESC)
        `);
        
        console.log('SUCCESS Custom characters table initialized');
    } catch (error) {
        console.error('Error setting up custom characters DB:', error);
    }
}

// Sanitization now handled by centralized inputSanitizer utility
// See /src/utils/input-sanitizer.js for the comprehensive implementation

// Validate character ID format
function validateCharacterId(id) {
    if (typeof id !== 'string' || !id) return false;
    // Allow only alphanumeric, underscore, hyphen (standard ID formats)
    return /^[a-zA-Z0-9_-]+$/.test(id) && id.length <= 50;
}

// Validate user ID
function validateUserId(userId) {
    const numId = parseInt(userId);
    return !isNaN(numId) && numId > 0 && numId <= Number.MAX_SAFE_INTEGER;
}

function validateSystemPrompt(prompt) {
    if (!prompt || typeof prompt !== 'string') return '';
    // Remove potentially harmful content but preserve legitimate instructions
    const sanitized = prompt.replace(/[<>]/g, '').trim();
    if (sanitized.length > 10000) {
        throw new Error('System prompt too long (max 10000 characters)');
    }
    return sanitized;
}

// Get all custom characters for a user
router.get('/api/custom-characters/:userId', authenticateToken, async (req, res) => {
    const { userId } = req.params;
    
    // Validate user ID format
    if (!validateUserId(userId)) {
        return res.status(400).json({ error: 'Invalid user ID format' });
    }
    
    // Validate user ownership - users can only access their own characters
    if (parseInt(req.user.id) !== parseInt(userId)) {
        return res.status(403).json({ error: 'Access denied: Cannot access other user\'s characters' });
    }
    const db = req.app.get('db');
    
    if (!db) {
        return res.status(500).json({ error: 'Database not initialized' });
    }
    
    try {
        // Update last access time for user activity tracking
        const result = await db.query(
            `SELECT id, user_id, name, description, personality, config, image, 
                    is_public, category, tags, usage_count, last_used, created_at, updated_at,
                    system_prompt
             FROM custom_characters 
             WHERE user_id = ? 
             ORDER BY usage_count DESC, created_at DESC`,
            [parseInt(userId)]
        );
        
        // Extract rows from the result (Database class returns { rows: [...] })
        const characters = result.rows || result || [];
        
        // Convert to object format for frontend compatibility
        const charactersObj = {};
        if (characters && characters.length > 0) {
            characters.forEach(char => {
                // Generate consistent icon based on character name
                const generateIcon = (name) => {
                    const icons = ['ROLEPLAY', '👤', '🤖', '👻', '🎪', '🦾', 'CREATIVE', '🌟', '🔮', '⚡', '🔥', '💎', '🎯', 'OPTIMIZING', '🎲'];
                    const hash = name.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
                    return icons[hash % icons.length];
                };
                
                charactersObj[char.id] = {
                    id: char.id,
                    name: inputSanitizer.sanitizeString(char.name, 'general'),
                    personality: inputSanitizer.sanitizeString(char.personality || char.description, 'general'),
                    description: inputSanitizer.sanitizeString(char.description, 'general'),
                    systemPrompt: inputSanitizer.sanitizeString(char.system_prompt || char.personality, 'general'),
                    config: (() => { try { return JSON.parse(char.config || '{}'); } catch (e) { return {}; } })(),
                    image: char.image,
                    icon: generateIcon(char.name),
                    userId: char.user_id,
                    // Enhanced features
                    category: char.category || 'custom',
                    tags: JSON.parse(char.tags || '[]'),
                    usageCount: char.usage_count || 0,
                    lastUsed: char.last_used,
                    isPublic: Boolean(char.is_public),
                    createdAt: char.created_at,
                    updatedAt: char.updated_at
                };
            });
        }
        
        res.json(charactersObj);
    } catch (error) {
        console.error('Error fetching custom characters:', error);
        res.status(500).json({ error: 'Failed to fetch custom characters' });
    }
});

// Save or update a custom character
router.post('/api/custom-characters', authenticateToken, async (req, res) => {
    const { userId, characterId, name, personality, config, image, description, category, tags, isPublic } = req.body;
    
    // Validate user ID format
    if (!validateUserId(userId)) {
        return res.status(400).json({ error: 'Invalid user ID format' });
    }
    
    // Validate character ID format if provided
    if (characterId && !validateCharacterId(characterId)) {
        return res.status(400).json({ error: 'Invalid character ID format' });
    }
    
    // Validate user ownership - users can only create/update their own characters
    if (parseInt(req.user.id) !== parseInt(userId)) {
        console.log(`Access denied: User ${req.user.id} attempted to create character for user ${userId}`);
        return res.status(403).json({ error: 'Access denied: Cannot create characters for other users' });
    }
    
    console.log(`SUCCESS Character creation authorized for user ${req.user.id}`);
    const db = req.app.get('db');
    
    // PAYWALL CHECK: Limit free users to 1 custom character
    if (!characterId) { // Only check for new character creation, not updates
        try {
            // Get user's subscription status and character count
            const userResult = await db.query(
                'SELECT subscription_status, custom_characters_created FROM users WHERE id = ?',
                [userId]
            );
            
            const users = userResult.rows || userResult;
            if (users && users.length > 0) {
                const user = users[0];
                const isPremium = user.subscription_status === 'premium' || user.subscription_status === 'active';
                const charactersCreated = user.custom_characters_created || 0;
                
                console.log(`💰 Character Creation Check - User ${userId}: ${charactersCreated} characters created, Premium: ${isPremium}`);
                
                // Check if free user has already created 1 character
                if (!isPremium && charactersCreated >= 1) {
                    console.log(`🚫 Character Creation Paywall - Free user ${userId} already created ${charactersCreated} character(s)`);
                    
                    // Count existing characters to be sure
                    const charCount = await db.query(
                        'SELECT COUNT(*) as count FROM custom_characters WHERE user_id = ?',
                        [userId]
                    );
                    const charRows = charCount.rows || charCount;
                    const actualCount = charRows[0]?.count || 0;
                    
                    if (actualCount >= 1) {
                        return res.status(402).json({
                            error: 'Free tier limit reached',
                            paywall: true,
                            limit: 1,
                            used: actualCount,
                            message: 'Free users can only create 1 custom character. Upgrade to premium for unlimited character creation!',
                            upgradeUrl: '/api/stripe-checkout'
                        });
                    }
                }
            }
        } catch (paywallError) {
            console.error('Character creation paywall check error:', paywallError);
            // Continue without paywall on error to avoid blocking
        }
    }
    
    // Enhanced validation
    if (!userId || !name || !personality) {
        return res.status(400).json({ error: 'Missing required fields: userId, name, and personality are required' });
    }
    
    // Enhanced validation and sanitization
    const sanitizedName = inputSanitizer.sanitizeString(name, 'general').substring(0, 100);
    const sanitizedPersonality = inputSanitizer.sanitizeString(personality, 'general').substring(0, 2000);
    const sanitizedDescription = inputSanitizer.sanitizeString(description || '', 'general').substring(0, 500);
    const sanitizedCategory = inputSanitizer.sanitizeString(category || 'custom', 'general').substring(0, 50);
    
    if (!sanitizedName || sanitizedName.length < 1) {
        return res.status(400).json({ error: 'Character name is required and must be 1-100 characters' });
    }
    
    if (!sanitizedPersonality || sanitizedPersonality.length < 10) {
        return res.status(400).json({ error: 'Character personality is required and must be 10-2000 characters' });
    }
    
    // Validate tags array
    if (tags && (!Array.isArray(tags) || tags.some(tag => typeof tag !== 'string' || tag.length > 30))) {
        return res.status(400).json({ error: 'Invalid tags format - must be array of strings (max 30 chars each)' });
    }
    
    const sanitizedTags = tags ? tags.map(tag => inputSanitizer.sanitizeString(tag, 'general').substring(0, 30)).filter(tag => tag.length > 0) : [];
    
    if (!db) {
        return res.status(500).json({ error: 'Database not initialized' });
    }
    
    try {
        // Extract system prompt from config if provided
        const systemPrompt = config?.systemPrompt || personality;
        
        // Use UPSERT (INSERT OR REPLACE) to prevent race conditions
        const characterIdToUse = characterId || `char_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        
        // Use atomic UPSERT to prevent race conditions
        // ON CONFLICT ensures the entire operation is atomic
        await db.query(
            `INSERT INTO custom_characters
             (id, user_id, name, description, personality, system_prompt, config, image,
              is_public, category, tags, usage_count, last_used, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, NULL, datetime('now'), datetime('now'))
             ON CONFLICT(id) DO UPDATE SET
             name = excluded.name,
             description = excluded.description,
             personality = excluded.personality,
             system_prompt = excluded.system_prompt,
             config = excluded.config,
             image = excluded.image,
             is_public = excluded.is_public,
             category = excluded.category,
             tags = excluded.tags,
             updated_at = datetime('now')`,
            [
                characterIdToUse,
                parseInt(userId),
                sanitizedName,
                sanitizedDescription,
                sanitizedPersonality,
                validateSystemPrompt(systemPrompt),
                JSON.stringify(config || {}),
                inputSanitizer.sanitizeString(image || '/assets/default-avatar.png', 'general').substring(0, 255),
                Boolean(isPublic) ? 1 : 0,
                sanitizedCategory,
                JSON.stringify(sanitizedTags)
            ]
        );
        
        // Update custom_characters_created counter for new characters
        if (!characterId) { // Only for new characters (no existing characterId)
            try {
                // Increment the custom_characters_created counter
                await db.query(
                    'UPDATE users SET custom_characters_created = COALESCE(custom_characters_created, 0) + 1 WHERE id = ?',
                    [userId]
                );
                console.log(`ANALYZING Incremented custom_characters_created for user ${userId}`);
            } catch (counterError) {
                console.error('Failed to update character creation counter:', counterError);
            }
            
            try {
                // Get user email for notification
                const userInfo = await db.query('SELECT email FROM users WHERE id = ?', [userId]);
                const userEmail = userInfo?.length > 0 ? userInfo[0].email : 'Unknown';
                
                await emailNotifications.notifyNewCharacter({
                    id: characterIdToUse,
                    name: sanitizedName,
                    userId: userId,
                    userEmail: userEmail,
                    description: sanitizedDescription,
                    category: sanitizedCategory
                });
                console.log('EMAIL New character notification email sent to admin');
            } catch (emailError) {
                console.error('ERROR Failed to send new character notification email:', emailError);
            }
        }
        
        res.json({ 
            success: true, 
            characterId: characterIdToUse,
            message: 'Character saved successfully with enhanced features'
        });
    } catch (error) {
        console.error('Error saving custom character:', error);
        res.status(500).json({ error: 'Failed to save custom character' });
    }
});

// Delete a custom character
router.delete('/api/custom-characters/:userId/:characterId', authenticateToken, async (req, res) => {
    const { userId, characterId } = req.params;
    
    // Validate user ownership - users can only delete their own characters
    if (String(req.user.id) !== String(userId)) {
        return res.status(403).json({ error: 'Access denied: Cannot delete other user\'s characters' });
    }
    
    const db = req.app.get('db');
    
    if (!db) {
        return res.status(500).json({ error: 'Database not initialized' });
    }
    
    try {
        // Debug logging to see what's being passed
        console.log('Delete request - userId:', userId, 'characterId:', characterId);
        
        const result = await db.query(
            `DELETE FROM custom_characters WHERE user_id = ? AND id = ?`,
            [parseInt(userId), characterId]
        );
        
        console.log('Delete result:', result);
        
        // For SQLite, check changes property, for PostgreSQL check rowCount
        const changes = result.changes || result.rowCount || 0;
        console.log('Rows affected:', changes);
        
        if (changes === 0) {
            // Let's check if the character exists at all
            const checkResult = await db.query(
                `SELECT * FROM custom_characters WHERE id = ?`,
                [characterId]
            );
            console.log('Character check result:', checkResult);
            
            return res.status(404).json({ error: 'Character not found' });
        }
        
        res.json({ success: true });
    } catch (error) {
        console.error('Error deleting custom character:', error);
        res.status(500).json({ error: 'Failed to delete custom character' });
    }
});

// ============================================================================
// GROUP CHARACTER CHAT FEATURES
// ============================================================================

// Create a new group conversation with multiple characters
router.post('/api/group-conversations', authenticateToken, async (req, res) => {
    const { userId, title, description, characterIds } = req.body;
    
    // Validate user ownership
    if (String(req.user.id) !== String(userId)) {
        return res.status(403).json({ error: 'Access denied' });
    }
    
    if (!userId || !title || !Array.isArray(characterIds) || characterIds.length < 2) {
        return res.status(400).json({ 
            error: 'Missing required fields: userId, title, and at least 2 characterIds required' 
        });
    }
    
    const db = req.app.get('db');
    if (!db) {
        return res.status(500).json({ error: 'Database not initialized' });
    }
    
    try {
        // Verify all characters belong to the user - secure approach
        const characterCheck = await db.query(
            `SELECT id FROM custom_characters WHERE user_id = ? AND id IN (${characterIds.map(() => '?').join(',')})`,
            [parseInt(userId), ...characterIds.map(id => String(id).replace(/[^a-zA-Z0-9_-]/g, ''))]
        );
        
        if (characterCheck.rows.length !== characterIds.length) {
            return res.status(403).json({ error: 'One or more characters do not belong to you' });
        }
        
        const conversationId = `group_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        
        await db.query(
            `INSERT INTO group_conversations 
             (id, user_id, title, description, character_ids, created_at, updated_at) 
             VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))`,
            [
                conversationId,
                parseInt(userId),
                inputSanitizer.sanitizeString(title, 'general'),
                inputSanitizer.sanitizeString(description || '', 'general'),
                JSON.stringify(characterIds)
            ]
        );
        
        res.json({ 
            success: true, 
            conversationId,
            message: 'Group conversation created successfully'
        });
    } catch (error) {
        console.error('Error creating group conversation:', error);
        res.status(500).json({ error: 'Failed to create group conversation' });
    }
});

// Get user's group conversations
router.get('/api/group-conversations/:userId', authenticateToken, async (req, res) => {
    const { userId } = req.params;
    
    if (String(req.user.id) !== String(userId)) {
        return res.status(403).json({ error: 'Access denied' });
    }
    
    const db = req.app.get('db');
    if (!db) {
        return res.status(500).json({ error: 'Database not initialized' });
    }
    
    try {
        const result = await db.query(
            `SELECT * FROM group_conversations WHERE user_id = ? AND is_active = 1 ORDER BY updated_at DESC`,
            [parseInt(userId)]
        );
        
        const conversations = result.rows || result || [];

        // PERFORMANCE FIX: Batch character details fetch to prevent N+1 query problem
        // Instead of querying for each conversation, collect all character IDs first
        const allCharacterIds = new Set();
        for (const conv of conversations) {
            const characterIds = JSON.parse(conv.character_ids || '[]');
            characterIds.forEach(id => allCharacterIds.add(id));
        }

        // Single query to fetch all characters at once (1 query instead of N queries)
        let characterMap = new Map();
        if (allCharacterIds.size > 0) {
            const sanitizedIds = Array.from(allCharacterIds).map(id =>
                String(id).replace(/[^a-zA-Z0-9_-]/g, '')
            );
            const characterDetails = await db.query(
                `SELECT id, name, image FROM custom_characters WHERE id IN (${sanitizedIds.map(() => '?').join(',')})`,
                sanitizedIds
            );
            // Build Map for O(1) character lookup
            (characterDetails.rows || characterDetails || []).forEach(char => {
                characterMap.set(char.id, char);
            });
        }

        // Enrich conversations with characters from Map (no additional queries)
        const enrichedConversations = conversations.map(conv => {
            const characterIds = JSON.parse(conv.character_ids || '[]');
            conv.characters = characterIds
                .map(id => characterMap.get(id))
                .filter(Boolean); // Remove undefined entries
            return conv;
        });

        res.json(enrichedConversations);
    } catch (error) {
        console.error('Error fetching group conversations:', error);
        res.status(500).json({ error: 'Failed to fetch group conversations' });
    }
});

// Add message to group conversation
router.post('/api/group-conversations/:conversationId/messages', authenticateToken, async (req, res) => {
    const { conversationId } = req.params;
    const { content, senderType, senderId } = req.body;
    
    const db = req.app.get('db');
    if (!db) {
        return res.status(500).json({ error: 'Database not initialized' });
    }
    
    try {
        // Verify user owns this conversation
        const convCheck = await db.query(
            `SELECT user_id FROM group_conversations WHERE id = ?`,
            [conversationId]
        );
        
        if (!convCheck.rows || convCheck.rows.length === 0) {
            return res.status(404).json({ error: 'Conversation not found' });
        }
        
        if (String(req.user.id) !== String(convCheck.rows[0].user_id)) {
            return res.status(403).json({ error: 'Access denied' });
        }
        
        await db.query(
            `INSERT INTO group_messages (group_conversation_id, sender_type, sender_id, content, created_at) 
             VALUES (?, ?, ?, ?, datetime('now'))`,
            [conversationId, senderType, senderId || null, inputSanitizer.sanitizeString(content, 'general')]
        );
        
        // Update conversation timestamp and message count
        await db.query(
            `UPDATE group_conversations 
             SET message_count = message_count + 1, updated_at = datetime('now') 
             WHERE id = ?`,
            [conversationId]
        );
        
        res.json({ success: true, message: 'Message added successfully' });
    } catch (error) {
        console.error('Error adding group message:', error);
        res.status(500).json({ error: 'Failed to add message' });
    }
});

// Get messages from group conversation
router.get('/api/group-conversations/:conversationId/messages', authenticateToken, async (req, res) => {
    const { conversationId } = req.params;
    const { limit = 50, offset = 0 } = req.query;
    
    const db = req.app.get('db');
    if (!db) {
        return res.status(500).json({ error: 'Database not initialized' });
    }
    
    try {
        // Verify user owns this conversation
        const convCheck = await db.query(
            `SELECT user_id FROM group_conversations WHERE id = ?`,
            [conversationId]
        );
        
        if (!convCheck.rows || convCheck.rows.length === 0) {
            return res.status(404).json({ error: 'Conversation not found' });
        }
        
        if (String(req.user.id) !== String(convCheck.rows[0].user_id)) {
            return res.status(403).json({ error: 'Access denied' });
        }
        
        const messages = await db.query(
            `SELECT gm.*, cc.name as sender_name, cc.image as sender_image
             FROM group_messages gm
             LEFT JOIN custom_characters cc ON gm.sender_id = cc.id AND gm.sender_type = 'character'
             WHERE gm.group_conversation_id = ? AND gm.is_deleted = 0
             ORDER BY gm.created_at DESC
             LIMIT ? OFFSET ?`,
            [conversationId, parseInt(limit), parseInt(offset)]
        );
        
        res.json(messages.rows || messages || []);
    } catch (error) {
        console.error('Error fetching group messages:', error);
        res.status(500).json({ error: 'Failed to fetch messages' });
    }
});

// ============================================================================
// ENHANCED CHARACTER FEATURES  
// ============================================================================

// Update character usage count when used in conversation
router.post('/api/custom-characters/:characterId/use', authenticateToken, async (req, res) => {
    const { characterId } = req.params;
    const db = req.app.get('db');
    
    if (!db) {
        return res.status(500).json({ error: 'Database not initialized' });
    }
    
    try {
        // Verify character belongs to user
        const charCheck = await db.query(
            `SELECT user_id FROM custom_characters WHERE id = ?`,
            [characterId]
        );
        
        if (!charCheck.rows || charCheck.rows.length === 0) {
            return res.status(404).json({ error: 'Character not found' });
        }
        
        if (String(req.user.id) !== String(charCheck.rows[0].user_id)) {
            return res.status(403).json({ error: 'Access denied' });
        }
        
        await db.query(
            `UPDATE custom_characters 
             SET usage_count = usage_count + 1, last_used = datetime('now') 
             WHERE id = ?`,
            [characterId]
        );
        
        res.json({ success: true });
    } catch (error) {
        console.error('Error updating character usage:', error);
        res.status(500).json({ error: 'Failed to update usage' });
    }
});

// Get public characters (for sharing/discovery)
router.get('/api/public-characters', async (req, res) => {
    const { category, limit = 20, offset = 0 } = req.query;
    const db = req.app.get('db');
    
    if (!db) {
        return res.status(500).json({ error: 'Database not initialized' });
    }
    
    try {
        let query = `SELECT id, name, description, personality, image, category, tags, usage_count, created_at 
                     FROM custom_characters WHERE is_public = 1`;
        let params = [];
        
        if (category && category !== 'all') {
            query += ' AND category = ?';
            params.push(category);
        }
        
        query += ' ORDER BY usage_count DESC, created_at DESC LIMIT ? OFFSET ?';
        params.push(parseInt(limit), parseInt(offset));
        
        const result = await db.query(query, params);
        const characters = result.rows || result || [];
        
        // Sanitize data for public viewing
        const publicCharacters = characters.map(char => ({
            id: char.id,
            name: char.name,
            description: char.description,
            personality: char.personality,
            image: char.image,
            category: char.category,
            tags: JSON.parse(char.tags || '[]'),
            usageCount: char.usage_count,
            createdAt: char.created_at
        }));
        
        res.json(publicCharacters);
    } catch (error) {
        console.error('Error fetching public characters:', error);
        res.status(500).json({ error: 'Failed to fetch public characters' });
    }
});

module.exports = { router, setupCustomCharactersDB };