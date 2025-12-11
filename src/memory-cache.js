// Advanced Memory Cache System for JustLayMe
// High-performance in-memory caching with TTL, LRU eviction, and compression

const crypto = require('crypto');
const zlib = require('zlib');
const util = require('util');
const resourceLifecycleManager = require('./resource-lifecycle-manager');

// Promisify compression functions
const gzip = util.promisify(zlib.gzip);
const gunzip = util.promisify(zlib.gunzip);

class MemoryCache {
    constructor(options = {}) {
        this.maxSize = options.maxSize || 100 * 1024 * 1024; // 100MB default
        this.maxEntries = options.maxEntries || 10000;
        this.defaultTTL = options.defaultTTL || 30 * 60 * 1000; // 30 minutes
        this.compressionThreshold = options.compressionThreshold || 1024; // 1KB
        this.enableCompression = options.enableCompression !== false;
        
        // Internal storage
        this.cache = new Map();
        this.accessTime = new Map(); // For LRU tracking
        this.sizeTracking = new Map(); // Track entry sizes
        this.currentSize = 0;
        
        // Statistics
        this.stats = {
            hits: 0,
            misses: 0,
            sets: 0,
            deletes: 0,
            evictions: 0,
            compressionSaves: 0,
            totalSavedBytes: 0
        };
        
        // ARCHITECTURAL FIX: Register interval with ResourceLifecycleManager
        // This ensures proper cleanup on shutdown and prevents memory leaks
        this.cleanupInterval = resourceLifecycleManager.registerInterval(
            'memory-cache-cleanup',
            () => {
                try {
                    this.cleanup();
                } catch (error) {
                    console.error('Cache cleanup error:', error);
                }
            },
            60 * 1000, // Run cleanup every minute
            { stopOnError: false }
        );
        
        console.log('OPTIMIZING Memory Cache initialized with', {
            maxSize: this.formatBytes(this.maxSize),
            maxEntries: this.maxEntries,
            defaultTTL: this.defaultTTL / 1000 + 's',
            compression: this.enableCompression
        });
    }

    // Generate cache key - MUST BE DETERMINISTIC for caching to work
    // PERFORMANCE FIX: Removed timestamp and randomSalt that were breaking cache functionality
    // Cache keys MUST be deterministic - same input = same key, or cache hit rate is 0%
    generateKey(prefix, ...parts) {
        // Input validation
        if (!prefix || typeof prefix !== 'string') {
            throw new Error('Cache key prefix must be a non-empty string');
        }

        // Sanitize and validate parts
        const sanitizedParts = parts.filter(part => part != null).map(part => {
            if (typeof part === 'object') {
                // Sort object keys for consistent hashing
                return JSON.stringify(part, Object.keys(part).sort());
            }
            return String(part).replace(/[:\n\r\t]/g, '_'); // Replace problematic characters
        });

        const combined = sanitizedParts.join(':');

        // Use SHA-256 for content-based hashing
        // No timestamp or randomSalt - those defeat caching by making every key unique!
        const contentHash = crypto.createHash('sha256').update(combined).digest('hex').substring(0, 32);

        // Format: prefix:hash (deterministic, cacheable)
        const finalKey = `${prefix}:${contentHash}`;

        return finalKey;
    }
    
    // Generate deterministic cache key for consistent lookups (without timestamp/salt)
    generateDeterministicKey(prefix, ...parts) {
        if (!prefix || typeof prefix !== 'string') {
            throw new Error('Cache key prefix must be a non-empty string');
        }
        
        const sanitizedParts = parts.filter(part => part != null).map(part => {
            if (typeof part === 'object') {
                return JSON.stringify(part, Object.keys(part).sort()); // Consistent object key ordering
            }
            return String(part).replace(/[:\n\r\t]/g, '_');
        });
        
        const combined = sanitizedParts.join(':');
        const contentHash = crypto.createHash('sha256').update(combined).digest('hex').substring(0, 32);
        
        return `${prefix}:det:${contentHash}`;
    }

    // Get value from cache
    async get(key) {
        const entry = this.cache.get(key);
        
        if (!entry) {
            this.stats.misses++;
            return null;
        }
        
        // Check TTL
        if (entry.expires && Date.now() > entry.expires) {
            this.delete(key);
            this.stats.misses++;
            return null;
        }
        
        // Update access time for LRU
        this.accessTime.set(key, Date.now());
        this.stats.hits++;
        
        // Decompress if needed with proper memory cleanup and verification
        try {
            if (entry.compressed) {
                const compressedBuffer = entry.data;
                
                // Verify compression integrity before decompression
                if (!Buffer.isBuffer(compressedBuffer) || compressedBuffer.length === 0) {
                    console.error(`ERROR Invalid compressed buffer for key ${key.substring(0, 50)}...`);
                    this.delete(key);
                    return null;
                }
                
                // Verify compression headers (gzip magic number)
                if (compressedBuffer.length >= 3 && 
                    (compressedBuffer[0] !== 0x1f || compressedBuffer[1] !== 0x8b)) {
                    console.error(`ERROR Invalid gzip header for key ${key.substring(0, 50)}...`);
                    this.delete(key);
                    return null;
                }
                
                const decompressed = await gunzip(compressedBuffer);
                
                // Verify decompressed data is valid
                if (!decompressed || decompressed.length === 0) {
                    console.error(`ERROR Empty decompressed data for key ${key.substring(0, 50)}...`);
                    this.delete(key);
                    return null;
                }
                
                const result = JSON.parse(decompressed.toString('utf8'));
                
                // Verify JSON parsing resulted in valid data
                if (result === undefined || result === null) {
                    console.warn(`⚠️ Null result after decompression for key ${key.substring(0, 50)}...`);
                }
                
                // Explicitly clear buffer references to prevent memory leaks
                if (compressedBuffer && typeof compressedBuffer.fill === 'function') {
                    compressedBuffer.fill(0); // Zero out the buffer
                }
                if (decompressed && typeof decompressed.fill === 'function') {
                    decompressed.fill(0); // Zero out decompressed buffer
                }
                
                return result;
            } else {
                // Verify uncompressed data integrity
                if (entry.data === undefined || entry.data === null) {
                    console.warn(`⚠️ Null uncompressed data for key ${key.substring(0, 50)}...`);
                    this.delete(key);
                    return null;
                }
                return entry.data;
            }
        } catch (error) {
            console.error(`ERROR Cache decompression/verification error for key ${key.substring(0, 50)}...:`, error.message);
            this.delete(key); // Remove corrupted entry
            this.stats.misses++; // Count as cache miss
            return null;
        }
    }

    // Set value in cache
    async set(key, value, ttl = null) {
        try {
            const expirationTime = ttl || this.defaultTTL;
            const expires = expirationTime > 0 ? Date.now() + expirationTime : null;
            
            // Serialize value
            const serialized = JSON.stringify(value);
            const originalSize = Buffer.byteLength(serialized, 'utf8');
            
            let finalData = value;
            let compressed = false;
            let finalSize = originalSize;
            
            // Compress if over threshold and compression enabled with proper cleanup
            if (this.enableCompression && originalSize > this.compressionThreshold) {
                let originalBuffer = null;
                try {
                    originalBuffer = Buffer.from(serialized, 'utf8');
                    const compressedBuffer = await gzip(originalBuffer);
                    const compressionRatio = compressedBuffer.length / originalSize;
                    
                    // Only use compression if it saves at least 20%
                    if (compressionRatio < 0.8) {
                        finalData = compressedBuffer;
                        compressed = true;
                        finalSize = compressedBuffer.length;
                        
                        const saved = originalSize - finalSize;
                        this.stats.compressionSaves++;
                        this.stats.totalSavedBytes += saved;
                        
                        console.log(`🗜️ Compressed cache entry ${key.substring(0, 50)}...: ${this.formatBytes(originalSize)} → ${this.formatBytes(finalSize)} (${(compressionRatio * 100).toFixed(1)}%)`);
                    } else {
                        // Compression didn't save enough space, clean up compressed buffer
                        if (compressedBuffer && typeof compressedBuffer.fill === 'function') {
                            compressedBuffer.fill(0);
                        }
                    }
                    
                    // Clean up original buffer after compression
                    if (originalBuffer && typeof originalBuffer.fill === 'function') {
                        originalBuffer.fill(0);
                    }
                    
                } catch (compressionError) {
                    console.warn('Cache compression failed, storing uncompressed:', compressionError.message);
                    // Clean up any buffers created during failed compression
                    if (originalBuffer && typeof originalBuffer.fill === 'function') {
                        originalBuffer.fill(0);
                    }
                    // Fall back to uncompressed storage
                }
            }
            
            // Remove existing entry from size tracking
            if (this.cache.has(key)) {
                const oldSize = this.sizeTracking.get(key) || 0;
                this.currentSize -= oldSize;
            }
            
            // Check if we need to evict entries
            await this.ensureCapacity(finalSize);
            
            // Store the entry
            const entry = {
                data: finalData,
                compressed,
                expires,
                created: Date.now(),
                size: finalSize
            };
            
            this.cache.set(key, entry);
            this.accessTime.set(key, Date.now());
            this.sizeTracking.set(key, finalSize);
            this.currentSize += finalSize;
            this.stats.sets++;
            
            return true;
            
        } catch (error) {
            console.error('Cache set error:', error);
            return false;
        }
    }

    // Delete entry from cache
    delete(key) {
        if (this.cache.has(key)) {
            const size = this.sizeTracking.get(key) || 0;
            this.currentSize -= size;
            
            this.cache.delete(key);
            this.accessTime.delete(key);
            this.sizeTracking.delete(key);
            this.stats.deletes++;
            
            return true;
        }
        return false;
    }

    // Clear all cache entries
    clear() {
        const count = this.cache.size;
        this.cache.clear();
        this.accessTime.clear();
        this.sizeTracking.clear();
        this.currentSize = 0;
        
        console.log(`🧹 Cleared ${count} cache entries`);
    }

    // Ensure cache has capacity for new entry
    async ensureCapacity(newEntrySize) {
        // Check entry count limit
        while (this.cache.size >= this.maxEntries) {
            this.evictLRUEntry();
        }
        
        // Check size limit
        while (this.currentSize + newEntrySize > this.maxSize && this.cache.size > 0) {
            this.evictLRUEntry();
        }
    }

    // Evict least recently used entry with improved logic
    evictLRUEntry() {
        if (this.cache.size === 0) {
            console.warn('⚠️ Attempted to evict from empty cache');
            return false;
        }
        
        // Find LRU entry with proper initialization
        let oldestKey = null;
        let oldestTime = Infinity; // Start with infinity, not current time
        
        // Ensure accessTime and cache are in sync
        for (const [key, time] of this.accessTime.entries()) {
            // Only consider keys that actually exist in cache
            if (this.cache.has(key) && time < oldestTime) {
                oldestTime = time;
                oldestKey = key;
            }
        }
        
        // If no oldest key found, try to find any key from cache
        if (!oldestKey && this.cache.size > 0) {
            const cacheKeys = Array.from(this.cache.keys());
            oldestKey = cacheKeys[0]; // Take first key as fallback
            console.warn(`⚠️ LRU fallback: using first cache key ${oldestKey.substring(0, 50)}...`);
        }
        
        if (oldestKey) {
            console.log(`🗑️ Evicting LRU cache entry: ${oldestKey.substring(0, 50)}... (age: ${Date.now() - oldestTime}ms)`);
            const success = this.delete(oldestKey);
            if (success) {
                this.stats.evictions++;
                return true;
            } else {
                console.error(`ERROR Failed to evict LRU entry: ${oldestKey}`);
                // Clean up orphaned accessTime entry
                this.accessTime.delete(oldestKey);
                return false;
            }
        } else {
            console.error('ERROR No LRU entry found to evict despite non-empty cache');
            // Emergency cache reset if we're in an inconsistent state
            if (this.cache.size > 0) {
                console.log('🚨 Emergency cache state cleanup');
                this.clear();
            }
            return false;
        }
    }

    // Cleanup expired entries
    cleanup() {
        const now = Date.now();
        const expiredKeys = [];
        
        for (const [key, entry] of this.cache.entries()) {
            if (entry.expires && now > entry.expires) {
                expiredKeys.push(key);
            }
        }
        
        if (expiredKeys.length > 0) {
            console.log(`🧹 Cleaning up ${expiredKeys.length} expired cache entries`);
            for (const key of expiredKeys) {
                this.delete(key);
            }
        }
    }

    // Get cache statistics
    getStats() {
        const hitRate = this.stats.hits + this.stats.misses > 0 
            ? (this.stats.hits / (this.stats.hits + this.stats.misses) * 100).toFixed(2)
            : '0.00';
            
        const compressionRate = this.stats.sets > 0
            ? (this.stats.compressionSaves / this.stats.sets * 100).toFixed(2)
            : '0.00';

        return {
            ...this.stats,
            hitRate: hitRate + '%',
            compressionRate: compressionRate + '%',
            totalSavedMB: (this.stats.totalSavedBytes / 1024 / 1024).toFixed(2),
            entries: this.cache.size,
            currentSize: this.formatBytes(this.currentSize),
            utilization: ((this.currentSize / this.maxSize) * 100).toFixed(2) + '%'
        };
    }

    // Format bytes for display
    formatBytes(bytes) {
        const sizes = ['B', 'KB', 'MB', 'GB'];
        if (bytes === 0) return '0B';
        const i = Math.floor(Math.log(bytes) / Math.log(1024));
        return `${(bytes / Math.pow(1024, i)).toFixed(2)}${sizes[i]}`;
    }

    // Cache patterns for specific use cases
    
    // User profile caching with deterministic keys
    async getUserProfile(userId) {
        const key = this.generateDeterministicKey('user_profile', userId);
        return await this.get(key);
    }

    async setUserProfile(userId, profile) {
        const key = this.generateDeterministicKey('user_profile', userId);
        return await this.set(key, profile, 15 * 60 * 1000); // 15 minutes TTL
    }

    // Memory patterns caching with deterministic keys
    async getMemoryPatterns(userId) {
        const key = this.generateDeterministicKey('memory_patterns', userId);
        return await this.get(key);
    }

    async setMemoryPatterns(userId, patterns) {
        const key = this.generateDeterministicKey('memory_patterns', userId);
        return await this.set(key, patterns, 10 * 60 * 1000); // 10 minutes TTL
    }

    // Conversation context caching with deterministic keys
    async getConversationContext(conversationId) {
        const key = this.generateDeterministicKey('conversation_context', conversationId);
        return await this.get(key);
    }

    async setConversationContext(conversationId, context) {
        const key = this.generateDeterministicKey('conversation_context', conversationId);
        return await this.set(key, context, 5 * 60 * 1000); // 5 minutes TTL
    }

    // Enhanced memory retrieval caching with deterministic keys
    async getRelevantMemories(userId, messageHash) {
        const key = this.generateDeterministicKey('relevant_memories', userId, messageHash);
        return await this.get(key);
    }

    async setRelevantMemories(userId, messageHash, memories) {
        const key = this.generateDeterministicKey('relevant_memories', userId, messageHash);
        return await this.set(key, memories, 20 * 60 * 1000); // 20 minutes TTL
    }

    // Query result caching with deterministic keys
    async getQueryResult(queryHash) {
        const key = this.generateDeterministicKey('query_result', queryHash);
        return await this.get(key);
    }

    async setQueryResult(queryHash, result, ttl = 5 * 60 * 1000) {
        const key = this.generateDeterministicKey('query_result', queryHash);
        return await this.set(key, result, ttl);
    }

    // Batch operations
    async getMany(keys) {
        const results = {};
        await Promise.all(keys.map(async (key) => {
            results[key] = await this.get(key);
        }));
        return results;
    }

    async setMany(entries, defaultTTL = null) {
        const results = {};
        await Promise.all(Object.entries(entries).map(async ([key, value]) => {
            results[key] = await this.set(key, value, defaultTTL);
        }));
        return results;
    }

    // Health check
    isHealthy() {
        return {
            healthy: true,
            cacheSize: this.cache.size,
            memoryUsage: this.currentSize,
            hitRate: this.getStats().hitRate,
            errors: this.currentSize > this.maxSize ? ['Memory usage exceeded'] : []
        };
    }

    // Graceful shutdown with comprehensive cleanup
    destroy() {
        // ARCHITECTURAL FIX: Clear interval via ResourceLifecycleManager
        // This ensures consistent cleanup across the application
        resourceLifecycleManager.clearInterval('memory-cache-cleanup');
        
        // Clear all cache data and references
        this.clear();
        
        // Clear tracking maps to prevent memory leaks
        if (this.accessTime) this.accessTime.clear();
        if (this.sizeTracking) this.sizeTracking.clear();
        
        // Reset stats to release any circular references
        this.stats = null;
        
        console.log('🛑 Memory Cache destroyed with comprehensive cleanup');
    }
}

// Export singleton instance
let cacheInstance = null;

function getCache(options = {}) {
    if (!cacheInstance) {
        cacheInstance = new MemoryCache(options);
    }
    return cacheInstance;
}

module.exports = {
    MemoryCache,
    getCache
};