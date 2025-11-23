/**
 * SECURITY LAYER for Memory Engine
 * Implements comprehensive security measures for the 12-Agent Audit findings
 * NO BAND-AIDS - Proper architectural security implementation
 */

const crypto = require('crypto');
const jwt = require('jsonwebtoken');

class MemorySecurityLayer {
    constructor(options = {}) {
        // Security configuration
        this.config = {
            encryptionAlgorithm: 'aes-256-gcm',
            jwtSecret: process.env.JWT_SECRET || options.jwtSecret || crypto.randomBytes(32).toString('hex'),
            jwtExpiry: options.jwtExpiry || '24h',
            dataRetentionDays: options.dataRetentionDays || 90,
            enableEncryption: options.enableEncryption !== false,
            enableAuthentication: options.enableAuthentication !== false,
            enableGDPR: options.enableGDPR !== false,
            encryptionKey: process.env.MEMORY_ENCRYPTION_KEY || options.encryptionKey || crypto.randomBytes(32)
        };

        // Initialize encryption key from environment or generate
        if (typeof this.config.encryptionKey === 'string') {
            this.config.encryptionKey = Buffer.from(this.config.encryptionKey, 'hex');
        }

        // User session tracking for authentication
        this.activeSessions = new Map();

        // Per-user encryption keys for additional security
        this.userEncryptionKeys = new Map();

        // Access control lists
        this.accessControlLists = new Map();

        // Audit log for GDPR compliance
        this.auditLog = [];

        // Data retention tracking
        this.retentionTracker = new Map();

        console.log('🔐 Memory Security Layer initialized with comprehensive protection');
    }

    // ===================================================================
    // SECURITY FIX #1: Authentication Middleware
    // ===================================================================

    /**
     * Authenticate a request for memory access
     * @param {string} token - JWT token or API key
     * @param {string} userId - User ID requesting access
     * @returns {Object} Authentication result with user details
     */
    async authenticateRequest(token, userId) {
        if (!this.config.enableAuthentication) {
            return { authenticated: true, userId };
        }

        try {
            if (!token) {
                throw new Error('No authentication token provided');
            }

            // Verify JWT token
            const decoded = jwt.verify(token, this.config.jwtSecret);

            // Verify user ID matches token
            if (decoded.userId !== userId) {
                throw new Error('User ID mismatch - potential cross-user access attempt');
            }

            // Check session validity
            const session = this.activeSessions.get(userId);
            if (!session || session.token !== token) {
                throw new Error('Invalid or expired session');
            }

            // Update last activity
            session.lastActivity = Date.now();

            return {
                authenticated: true,
                userId: decoded.userId,
                permissions: decoded.permissions || ['read', 'write'],
                sessionId: session.id
            };
        } catch (error) {
            console.error(`🔒 Authentication failed for user ${userId}:`, error.message);
            return {
                authenticated: false,
                error: error.message
            };
        }
    }

    /**
     * Generate authentication token for a user
     * @param {string} userId - User ID
     * @param {Array} permissions - User permissions
     * @returns {string} JWT token
     */
    generateAuthToken(userId, permissions = ['read', 'write']) {
        const token = jwt.sign(
            {
                userId,
                permissions,
                issuedAt: Date.now()
            },
            this.config.jwtSecret,
            { expiresIn: this.config.jwtExpiry }
        );

        // Store session
        this.activeSessions.set(userId, {
            id: crypto.randomUUID(),
            token,
            userId,
            permissions,
            createdAt: Date.now(),
            lastActivity: Date.now()
        });

        return token;
    }

    // ===================================================================
    // SECURITY FIX #2: User Isolation
    // ===================================================================

    /**
     * Ensure queries are properly filtered by user ID
     * @param {string} query - SQL query
     * @param {string} userId - User ID for filtering
     * @returns {string} Query with user filtering enforced
     */
    enforceUserIsolation(query, userId) {
        // Check if query already has user_id filter
        const hasUserFilter = /WHERE.*user_id\s*=/.test(query);

        if (!hasUserFilter && /SELECT|UPDATE|DELETE/.test(query)) {
            // Add user_id filter
            if (query.includes('WHERE')) {
                query = query.replace(/WHERE/i, `WHERE user_id = '${this.sanitizeUserId(userId)}' AND`);
            } else {
                // Add WHERE clause
                const tableMatch = query.match(/FROM\s+(\w+)/i);
                if (tableMatch) {
                    query = query.replace(
                        new RegExp(`FROM\\s+${tableMatch[1]}`, 'i'),
                        `FROM ${tableMatch[1]} WHERE user_id = '${this.sanitizeUserId(userId)}'`
                    );
                }
            }
        }

        return query;
    }

    /**
     * Sanitize user ID to prevent injection
     * @param {string} userId - User ID to sanitize
     * @returns {string} Sanitized user ID
     */
    sanitizeUserId(userId) {
        // Remove any SQL injection attempts
        return userId.replace(/[^a-zA-Z0-9_-]/g, '');
    }

    // ===================================================================
    // SECURITY FIX #3: Encryption at Rest
    // ===================================================================

    /**
     * Encrypt sensitive memory content
     * @param {string} content - Content to encrypt
     * @param {string} userId - User ID for key derivation
     * @returns {Object} Encrypted content with metadata
     */
    encryptContent(content, userId) {
        if (!this.config.enableEncryption) {
            return { content, encrypted: false };
        }

        try {
            // Generate IV for this encryption
            const iv = crypto.randomBytes(16);

            // Get or create user-specific key
            let userKey = this.userEncryptionKeys.get(userId);
            if (!userKey) {
                // Derive user-specific key from master key
                userKey = crypto.pbkdf2Sync(
                    this.config.encryptionKey,
                    userId,
                    100000,
                    32,
                    'sha256'
                );
                this.userEncryptionKeys.set(userId, userKey);
            }

            // Create cipher
            const cipher = crypto.createCipheriv(this.config.encryptionAlgorithm, userKey, iv);

            // Encrypt content
            let encrypted = cipher.update(content, 'utf8', 'base64');
            encrypted += cipher.final('base64');

            // Get auth tag for GCM
            const authTag = cipher.getAuthTag();

            return {
                content: encrypted,
                encrypted: true,
                iv: iv.toString('base64'),
                authTag: authTag.toString('base64'),
                algorithm: this.config.encryptionAlgorithm
            };
        } catch (error) {
            console.error('Encryption failed:', error);
            throw new Error('Failed to encrypt sensitive content');
        }
    }

    /**
     * Decrypt memory content
     * @param {Object} encryptedData - Encrypted content object
     * @param {string} userId - User ID for key derivation
     * @returns {string} Decrypted content
     */
    decryptContent(encryptedData, userId) {
        if (!encryptedData.encrypted) {
            return encryptedData.content;
        }

        try {
            // Get user-specific key
            let userKey = this.userEncryptionKeys.get(userId);
            if (!userKey) {
                userKey = crypto.pbkdf2Sync(
                    this.config.encryptionKey,
                    userId,
                    100000,
                    32,
                    'sha256'
                );
                this.userEncryptionKeys.set(userId, userKey);
            }

            // Create decipher
            const decipher = crypto.createDecipheriv(
                encryptedData.algorithm || this.config.encryptionAlgorithm,
                userKey,
                Buffer.from(encryptedData.iv, 'base64')
            );

            // Set auth tag for GCM
            if (encryptedData.authTag) {
                decipher.setAuthTag(Buffer.from(encryptedData.authTag, 'base64'));
            }

            // Decrypt content
            let decrypted = decipher.update(encryptedData.content, 'base64', 'utf8');
            decrypted += decipher.final('utf8');

            return decrypted;
        } catch (error) {
            console.error('Decryption failed:', error);
            throw new Error('Failed to decrypt content - possible data corruption or wrong key');
        }
    }

    // ===================================================================
    // SECURITY FIX #4: GDPR Compliance
    // ===================================================================

    /**
     * Export all user data for GDPR compliance
     * @param {string} userId - User ID
     * @param {Object} db - Database connection
     * @returns {Object} All user data in exportable format
     */
    async exportUserData(userId, db) {
        if (!this.config.enableGDPR) {
            throw new Error('GDPR features not enabled');
        }

        try {
            const exportData = {
                userId,
                exportDate: new Date().toISOString(),
                memories: [],
                profile: null,
                relationships: [],
                emotionalData: []
            };

            // Get all memories
            const memories = await db.query(
                'SELECT * FROM neural_memory_embeddings WHERE user_id = ?',
                [userId]
            );
            exportData.memories = memories.rows || [];

            // Get character relationships
            const relationships = await db.query(
                'SELECT * FROM character_relationships WHERE user_id = ?',
                [userId]
            );
            exportData.relationships = relationships.rows || [];

            // Get emotional evolution
            const emotional = await db.query(
                'SELECT * FROM emotional_evolution WHERE user_id = ?',
                [userId]
            );
            exportData.emotionalData = emotional.rows || [];

            // Log export for audit
            this.auditLog.push({
                action: 'DATA_EXPORT',
                userId,
                timestamp: Date.now(),
                details: `Exported ${exportData.memories.length} memories`
            });

            return exportData;
        } catch (error) {
            console.error('GDPR export failed:', error);
            throw new Error('Failed to export user data');
        }
    }

    /**
     * Delete all user data for GDPR compliance
     * @param {string} userId - User ID
     * @param {Object} db - Database connection
     * @returns {Object} Deletion confirmation
     */
    async deleteUserData(userId, db) {
        if (!this.config.enableGDPR) {
            throw new Error('GDPR features not enabled');
        }

        try {
            // Delete from all tables
            const tables = [
                'neural_memory_embeddings',
                'character_relationships',
                'emotional_evolution',
                'memory_decay_log',
                'predictive_cache'
            ];

            let totalDeleted = 0;
            for (const table of tables) {
                const result = await db.query(
                    `DELETE FROM ${table} WHERE user_id = ?`,
                    [userId]
                );
                totalDeleted += result.changes || 0;
            }

            // Clear user from in-memory caches
            this.userEncryptionKeys.delete(userId);
            this.activeSessions.delete(userId);
            this.accessControlLists.delete(userId);

            // Log deletion for audit
            this.auditLog.push({
                action: 'DATA_DELETION',
                userId,
                timestamp: Date.now(),
                details: `Deleted ${totalDeleted} records across ${tables.length} tables`
            });

            return {
                success: true,
                userId,
                recordsDeleted: totalDeleted,
                timestamp: new Date().toISOString()
            };
        } catch (error) {
            console.error('GDPR deletion failed:', error);
            throw new Error('Failed to delete user data');
        }
    }

    /**
     * Anonymize user data for GDPR compliance
     * @param {string} userId - User ID
     * @param {Object} db - Database connection
     * @returns {Object} Anonymization confirmation
     */
    async anonymizeUserData(userId, db) {
        if (!this.config.enableGDPR) {
            throw new Error('GDPR features not enabled');
        }

        try {
            const anonymousId = 'anon_' + crypto.randomBytes(16).toString('hex');

            // Anonymize memories
            await db.query(
                `UPDATE neural_memory_embeddings
                 SET user_id = ?, memory_content = '<<ANONYMIZED>>'
                 WHERE user_id = ?`,
                [anonymousId, userId]
            );

            // Anonymize relationships
            await db.query(
                `UPDATE character_relationships
                 SET user_id = ?, relationship_notes = '<<ANONYMIZED>>'
                 WHERE user_id = ?`,
                [anonymousId, userId]
            );

            // Log anonymization
            this.auditLog.push({
                action: 'DATA_ANONYMIZATION',
                originalUserId: userId,
                anonymousId,
                timestamp: Date.now()
            });

            return {
                success: true,
                originalUserId: userId,
                anonymousId,
                timestamp: new Date().toISOString()
            };
        } catch (error) {
            console.error('GDPR anonymization failed:', error);
            throw new Error('Failed to anonymize user data');
        }
    }

    // ===================================================================
    // SECURITY FIX #5: User-Partitioned Clustering
    // ===================================================================

    /**
     * Ensure semantic clustering respects user boundaries
     * @param {Array} memories - Memories to cluster
     * @param {string} userId - User ID for partitioning
     * @returns {Array} User-specific clusters
     */
    partitionClustersForUser(memories, userId) {
        // Filter memories to only this user's data
        const userMemories = memories.filter(m => m.user_id === userId);

        // Create user-specific cluster namespace
        const userClusterPrefix = `user_${userId}_cluster_`;

        // Process clusters with user isolation
        const clusters = [];
        userMemories.forEach((memory, index) => {
            // Ensure cluster IDs are user-specific
            if (memory.cluster_id && !memory.cluster_id.startsWith(userClusterPrefix)) {
                memory.cluster_id = userClusterPrefix + memory.cluster_id;
            }
            clusters.push(memory);
        });

        return clusters;
    }

    // ===================================================================
    // SECURITY FIX #6: SQL Injection Prevention
    // ===================================================================

    /**
     * Validate and sanitize SQL parameters
     * @param {Array} params - SQL parameters
     * @returns {Array} Sanitized parameters
     */
    sanitizeParameters(params) {
        return params.map(param => {
            if (typeof param === 'string') {
                // Escape SQL special characters
                return param
                    .replace(/'/g, "''")
                    .replace(/;/g, '')
                    .replace(/--/g, '')
                    .replace(/\/\*/g, '')
                    .replace(/\*\//g, '');
            }
            return param;
        });
    }

    /**
     * Build parameterized query safely
     * @param {string} baseQuery - Base SQL query
     * @param {Object} conditions - Query conditions
     * @returns {Object} Query and parameters
     */
    buildSecureQuery(baseQuery, conditions) {
        const params = [];
        let query = baseQuery;
        let paramIndex = 1;

        Object.keys(conditions).forEach(key => {
            // Validate column name (alphanumeric and underscore only)
            const safeKey = key.replace(/[^a-zA-Z0-9_]/g, '');

            if (query.includes('WHERE')) {
                query += ` AND ${safeKey} = ?`;
            } else {
                query += ` WHERE ${safeKey} = ?`;
            }

            params.push(conditions[key]);
        });

        return {
            query,
            params: this.sanitizeParameters(params)
        };
    }

    // ===================================================================
    // SECURITY FIX #7: Cross-Character Authorization
    // ===================================================================

    /**
     * Check if user has access to a specific character
     * @param {string} userId - User ID
     * @param {string} characterId - Character ID
     * @param {Object} db - Database connection
     * @returns {boolean} Access permission
     */
    async authorizeCharacterAccess(userId, characterId, db) {
        try {
            // Check character ownership
            const result = await db.query(
                'SELECT user_id FROM characters WHERE id = ?',
                [characterId]
            );

            if (!result || !result.rows || result.rows.length === 0) {
                return false; // Character doesn't exist
            }

            const characterOwner = result.rows[0].user_id;

            // Check if user owns the character
            if (characterOwner === userId) {
                return true;
            }

            // Check if user has been granted access
            const acl = this.accessControlLists.get(userId) || [];
            return acl.includes(characterId);
        } catch (error) {
            console.error('Authorization check failed:', error);
            return false; // Fail closed
        }
    }

    /**
     * Grant character access to another user
     * @param {string} ownerId - Character owner
     * @param {string} userId - User to grant access
     * @param {string} characterId - Character ID
     */
    grantCharacterAccess(ownerId, userId, characterId) {
        const acl = this.accessControlLists.get(userId) || [];
        if (!acl.includes(characterId)) {
            acl.push(characterId);
            this.accessControlLists.set(userId, acl);
        }

        // Log access grant
        this.auditLog.push({
            action: 'ACCESS_GRANTED',
            ownerId,
            userId,
            characterId,
            timestamp: Date.now()
        });
    }

    // ===================================================================
    // SECURITY FIX #8: Data Retention Policy
    // ===================================================================

    /**
     * Enforce data retention policy
     * @param {Object} db - Database connection
     * @returns {Object} Retention enforcement results
     */
    async enforceDataRetention(db) {
        try {
            const retentionDate = new Date();
            retentionDate.setDate(retentionDate.getDate() - this.config.dataRetentionDays);
            const retentionTimestamp = Math.floor(retentionDate.getTime() / 1000);

            // Delete old memories
            const memoryResult = await db.query(
                `DELETE FROM neural_memory_embeddings
                 WHERE created_at < ? AND importance_score < 0.8`,
                [retentionTimestamp]
            );

            // Delete old logs
            const logResult = await db.query(
                `DELETE FROM memory_decay_log WHERE created_at < ?`,
                [retentionTimestamp]
            );

            // Delete old cache entries
            const cacheResult = await db.query(
                `DELETE FROM predictive_cache WHERE created_at < ?`,
                [retentionTimestamp]
            );

            const totalDeleted =
                (memoryResult.changes || 0) +
                (logResult.changes || 0) +
                (cacheResult.changes || 0);

            // Log retention enforcement
            this.auditLog.push({
                action: 'RETENTION_ENFORCEMENT',
                timestamp: Date.now(),
                details: `Deleted ${totalDeleted} expired records older than ${this.config.dataRetentionDays} days`
            });

            return {
                success: true,
                recordsDeleted: totalDeleted,
                retentionDays: this.config.dataRetentionDays,
                cutoffDate: retentionDate.toISOString()
            };
        } catch (error) {
            console.error('Data retention enforcement failed:', error);
            throw new Error('Failed to enforce data retention policy');
        }
    }

    /**
     * Schedule automatic retention enforcement
     */
    scheduleRetentionEnforcement(db) {
        // Run daily at 3 AM
        setInterval(async () => {
            const hour = new Date().getHours();
            if (hour === 3) {
                console.log('🗑️ Running scheduled data retention enforcement...');
                await this.enforceDataRetention(db);
            }
        }, 60 * 60 * 1000); // Check every hour
    }

    // ===================================================================
    // Security Middleware for Express Routes
    // ===================================================================

    /**
     * Express middleware for authentication
     * @returns {Function} Express middleware function
     */
    authenticationMiddleware() {
        return async (req, res, next) => {
            const token = req.headers.authorization?.replace('Bearer ', '') || req.query.token;
            const userId = req.params.userId || req.body.userId;

            const authResult = await this.authenticateRequest(token, userId);

            if (!authResult.authenticated) {
                return res.status(401).json({
                    error: 'Authentication failed',
                    message: authResult.error
                });
            }

            // Attach auth info to request
            req.auth = authResult;
            next();
        };
    }

    /**
     * Express middleware for user isolation
     * @returns {Function} Express middleware function
     */
    userIsolationMiddleware() {
        return (req, res, next) => {
            // Override query methods to enforce user isolation
            if (req.db) {
                const originalQuery = req.db.query.bind(req.db);
                req.db.query = (sql, params) => {
                    const isolatedSql = this.enforceUserIsolation(sql, req.auth.userId);
                    return originalQuery(isolatedSql, params);
                };
            }
            next();
        };
    }

    /**
     * Get security metrics
     * @returns {Object} Security metrics and statistics
     */
    getSecurityMetrics() {
        return {
            activeSessions: this.activeSessions.size,
            encryptedUsers: this.userEncryptionKeys.size,
            auditLogSize: this.auditLog.length,
            accessControlEntries: this.accessControlLists.size,
            retentionDays: this.config.dataRetentionDays,
            encryptionEnabled: this.config.enableEncryption,
            authenticationEnabled: this.config.enableAuthentication,
            gdprEnabled: this.config.enableGDPR
        };
    }
}

module.exports = MemorySecurityLayer;