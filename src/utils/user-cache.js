const logger = require('./logger');
const resourceLifecycleManager = require('../resource-lifecycle-manager');

/**
 * User Cache Manager
 * Reduces database queries by caching user data
 * Especially useful for subscription status checks
 */
class UserCache {
    constructor() {
        this.cache = new Map();
        this.CACHE_TTL = 60000; // 1 minute default TTL
        this.MAX_CACHE_SIZE = 1000; // Maximum number of cached users
        this.cleanupIntervalId = null; // ARCHITECTURAL FIX: Store interval ID for cleanup

        // Stats tracking
        this.stats = {
            hits: 0,
            misses: 0,
            evictions: 0
        };

        // Start cleanup interval
        this.startCleanupInterval();
    }
    
    /**
     * Get user from cache or database
     * @param {string} userId - User ID to fetch
     * @param {Function} fetchFunction - Database fetch function if cache miss
     * @returns {Promise<Object>} User object
     */
    async get(userId, fetchFunction) {
        const cacheKey = String(userId);
        
        // Check cache first
        if (this.cache.has(cacheKey)) {
            const cached = this.cache.get(cacheKey);
            
            // Check if cache is still valid
            if (Date.now() - cached.timestamp < this.CACHE_TTL) {
                this.stats.hits++;
                logger.debug(`Cache HIT for user ${userId}`, {
                    stats: this.getStats()
                });
                return cached.data;
            } else {
                // Cache expired, remove it
                this.cache.delete(cacheKey);
            }
        }
        
        // Cache miss - fetch from database
        this.stats.misses++;
        logger.debug(`Cache MISS for user ${userId}`, {
            stats: this.getStats()
        });
        
        try {
            const userData = await fetchFunction(userId);
            
            // Store in cache
            if (userData) {
                this.set(userId, userData);
            }
            
            return userData;
        } catch (error) {
            logger.error(`Failed to fetch user ${userId}:`, error);
            throw error;
        }
    }
    
    /**
     * Set user data in cache
     * @param {string} userId - User ID
     * @param {Object} userData - User data to cache
     * @param {number} ttl - Optional TTL in milliseconds
     */
    set(userId, userData, ttl = null) {
        const cacheKey = String(userId);
        
        // Check cache size limit
        if (this.cache.size >= this.MAX_CACHE_SIZE) {
            this.evictOldest();
        }
        
        this.cache.set(cacheKey, {
            data: userData,
            timestamp: Date.now(),
            ttl: ttl || this.CACHE_TTL
        });
        
        logger.debug(`Cached user ${userId}`, {
            cacheSize: this.cache.size
        });
    }
    
    /**
     * Invalidate cache for a specific user
     * @param {string} userId - User ID to invalidate
     */
    invalidate(userId) {
        const cacheKey = String(userId);
        if (this.cache.delete(cacheKey)) {
            logger.debug(`Invalidated cache for user ${userId}`);
        }
    }
    
    /**
     * Clear entire cache
     */
    clear() {
        const size = this.cache.size;
        this.cache.clear();
        logger.info(`Cleared user cache (${size} entries)`);
    }
    
    /**
     * Evict oldest cache entry
     */
    evictOldest() {
        let oldestKey = null;
        let oldestTime = Date.now();
        
        for (const [key, value] of this.cache) {
            if (value.timestamp < oldestTime) {
                oldestTime = value.timestamp;
                oldestKey = key;
            }
        }
        
        if (oldestKey) {
            this.cache.delete(oldestKey);
            this.stats.evictions++;
            logger.debug(`Evicted oldest cache entry: ${oldestKey}`);
        }
    }
    
    /**
     * Get cache statistics
     */
    getStats() {
        const total = this.stats.hits + this.stats.misses;
        const hitRate = total > 0 ? (this.stats.hits / total * 100).toFixed(2) : 0;
        
        return {
            hits: this.stats.hits,
            misses: this.stats.misses,
            evictions: this.stats.evictions,
            hitRate: `${hitRate}%`,
            size: this.cache.size,
            maxSize: this.MAX_CACHE_SIZE
        };
    }
    
    /**
     * Start cleanup interval to remove expired entries
     * ARCHITECTURAL FIX: Use ResourceLifecycleManager for automatic cleanup
     */
    startCleanupInterval() {
        this.cleanupIntervalId = resourceLifecycleManager.registerInterval(
            'user-cache-cleanup',
            () => {
                let cleaned = 0;
                const now = Date.now();

                for (const [key, value] of this.cache) {
                    if (now - value.timestamp > value.ttl) {
                        this.cache.delete(key);
                        cleaned++;
                    }
                }

                if (cleaned > 0) {
                    logger.debug(`Cleaned ${cleaned} expired cache entries`, {
                        stats: this.getStats()
                    });
                }
            },
            30000 // Run every 30 seconds
        );
    }

    /**
     * Shutdown and cleanup resources
     * ARCHITECTURAL FIX: Proper resource cleanup on server shutdown
     */
    shutdown() {
        if (this.cleanupIntervalId) {
            resourceLifecycleManager.clearInterval('user-cache-cleanup');
            this.cleanupIntervalId = null;
        }
        this.cache.clear();
        console.log('✅ UserCache shutdown complete');
    }
}

// Create singleton instance
const userCache = new UserCache();

// Helper function for common user queries
const getCachedUser = async (userId, db) => {
    return userCache.get(userId, async (id) => {
        const result = await db.query(
            'SELECT id, email, subscription_status, total_messages, custom_characters_created FROM users WHERE id = ?',
            [id]
        );
        const rows = result.rows || result;
        return rows && rows.length > 0 ? rows[0] : null;
    });
};

// Export both the class and the singleton instance
module.exports = {
    UserCache,
    userCache,
    getCachedUser
};