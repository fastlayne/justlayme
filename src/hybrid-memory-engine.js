/**
 * Hybrid Memory Engine - Supports Both Old and New Embeddings
 *
 * This engine transparently handles the migration period by:
 * - Using 768-dim neural embeddings when available
 * - Falling back to 100-dim TF-IDF embeddings during migration
 * - Providing seamless transition with zero downtime
 *
 * After migration completes, this can be simplified to use only neural embeddings.
 *
 * @author Database Architect
 * @date 2025-10-24
 */

const fetch = require('node-fetch');
const PersistentEmbeddingCache = require('./persistent-embedding-cache');

class HybridMemoryEngine {
    constructor(options = {}) {
        this.ollamaUrl = options.ollamaUrl || 'http://localhost:11434';
        this.embeddingModel = options.embeddingModel || 'nomic-embed-text';
        this.db = options.database; // Database instance

        // Feature flag: prefer neural embeddings when available
        this.preferNeuralEmbeddings = options.preferNeuralEmbeddings !== false;

        // Performance optimizations - PERSISTENT CACHE
        this.persistentCache = new PersistentEmbeddingCache(this.db, {
            maxCacheSize: options.maxCacheSize || 100000,
            ttlDays: options.cacheTtlDays || 30,
            embeddingDimension: 768
        });

        // In-memory cache as L1 cache (for ultra-fast lookups)
        this.embeddingCache = new Map();
        this.maxMemoryCacheSize = options.maxMemoryCacheSize || 1000;

        // Configuration
        this.similarityThreshold = options.similarityThreshold || 0.3;
        this.recencyWeight = options.recencyWeight || 0.1;

        // Circuit breaker for Ollama API failures
        this.circuitBreaker = {
            failures: 0,
            threshold: 5,
            resetTimeout: 60000, // 60 seconds
            state: 'closed', // 'closed', 'open', 'half-open'
            nextRetry: 0
        };

        // Stats
        this.stats = {
            neuralSearches: 0,
            tfidfSearches: 0,
            hybridSearches: 0,
            embeddingsGenerated: 0,
            memoryCacheHits: 0,
            persistentCacheHits: 0,
            cacheMisses: 0,
            circuitBreakerTrips: 0
        };

        // Performance tracking
        this.enableTiming = options.enableTiming !== false;
        this.timings = {
            embeddingGeneration: [],
            cacheOperations: [],
            searches: []
        };

        // Cache readiness tracking
        this.cacheReady = false;
        this.cacheInitPromise = null;

        console.log('[HybridMemory] Initialized with persistent cache', {
            preferNeural: this.preferNeuralEmbeddings,
            ollama: this.ollamaUrl,
            persistentCache: true
        });

        // Initialize persistent cache and track readiness
        this.cacheInitPromise = this.persistentCache.initialize()
            .then(() => {
                this.cacheReady = true;
                console.log('[HybridMemory] Persistent cache ready');
            })
            .catch(error => {
                console.error('[HybridMemory] Persistent cache init failed:', error.message);
                this.cacheReady = false;
            });
    }

    /**
     * Ensure cache is ready before operations
     */
    async ensureReady() {
        if (!this.cacheReady && this.cacheInitPromise) {
            await this.cacheInitPromise;
        }
    }

    /**
     * Generate neural embedding using Ollama with two-level cache
     */
    async generateEmbedding(text) {
        // Ensure cache is ready
        await this.ensureReady();

        const startTime = this.enableTiming ? Date.now() : 0;

        // L1 Cache: Check in-memory cache first (fastest)
        const cacheKey = this._getCacheKey(text);
        if (this.embeddingCache.has(cacheKey)) {
            this.stats.memoryCacheHits++;
            if (this.enableTiming) {
                this.timings.cacheOperations.push(Date.now() - startTime);
            }
            return this.embeddingCache.get(cacheKey);
        }

        // L2 Cache: Check persistent SQLite cache
        const persistentStart = this.enableTiming ? Date.now() : 0;
        const cachedEmbedding = await this.persistentCache.get(text, this.embeddingModel);

        if (cachedEmbedding) {
            this.stats.persistentCacheHits++;

            // Promote to L1 cache for faster future access
            this._addToMemoryCache(cacheKey, cachedEmbedding);

            if (this.enableTiming) {
                const cacheTime = Date.now() - persistentStart;
                this.timings.cacheOperations.push(cacheTime);
                console.log(`[HybridMemory] Persistent cache hit in ${cacheTime}ms`);
            }
            return cachedEmbedding;
        }

        // Cache miss - generate from Ollama
        this.stats.cacheMisses++;

        // Check circuit breaker before making API call
        if (!this._checkCircuitBreaker()) {
            const error = new Error('Circuit breaker is open - Ollama API is unavailable');
            console.error('[HybridMemory]', error.message);
            throw error;
        }

        const ollamaStart = this.enableTiming ? Date.now() : 0;

        try {
            // Create AbortController for proper timeout handling (node-fetch doesn't support timeout option)
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 30000); // 30 second timeout

            try {
                const response = await fetch(`${this.ollamaUrl}/api/embeddings`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        model: this.embeddingModel,
                        prompt: text
                    }),
                    signal: controller.signal
                });

                clearTimeout(timeoutId);

                if (!response.ok) {
                    throw new Error(`Ollama API error: ${response.status}`);
                }

                const data = await response.json();
                const embedding = data.embedding;

                if (!Array.isArray(embedding) || embedding.length !== 768) {
                    throw new Error('Invalid embedding response');
                }

                // Normalize for cosine similarity
                const normalized = this._normalizeVector(embedding);

                const ollamaTime = this.enableTiming ? Date.now() - ollamaStart : 0;

                // Store in both caches
                this._addToMemoryCache(cacheKey, normalized);
                await this.persistentCache.set(text, normalized, this.embeddingModel);

                this.stats.embeddingsGenerated++;

                // Reset circuit breaker on success
                this._recordSuccess();

                if (this.enableTiming) {
                    this.timings.embeddingGeneration.push(ollamaTime);
                    const totalTime = Date.now() - startTime;
                    console.log(`[HybridMemory] Generated embedding in ${ollamaTime}ms (total: ${totalTime}ms)`);
                }

                return normalized;

            } catch (fetchError) {
                clearTimeout(timeoutId);
                if (fetchError.name === 'AbortError') {
                    throw new Error('Ollama API request timeout after 30 seconds');
                }
                throw fetchError;
            }

        } catch (error) {
            console.error('[HybridMemory] Embedding generation failed:', error.message);

            // Record failure in circuit breaker
            this._recordFailure();

            // NEVER return zero vector - throw error instead
            throw new Error(`Failed to generate embedding: ${error.message}`);
        }
    }

    /**
     * Save memory with embedding
     */
    async saveMemory(userId, content, characterId, metadata = {}) {
        // Generate embedding
        const embedding = await this.generateEmbedding(content);

        // Store in database with new column
        const query = `
            INSERT INTO neural_memory_embeddings
            (user_id, character_id, memory_content, embedding_vector_768, migration_status, created_at, emotional_context)
            VALUES (?, ?, ?, ?, 'completed', ?, ?)
        `;

        const result = await this.db.query(query, [
            userId,
            characterId,
            content,
            JSON.stringify(embedding),
            Math.floor(Date.now() / 1000),
            JSON.stringify(metadata)
        ]);

        console.log(`[HybridMemory] Saved memory ${result.lastID} with neural embedding`);
        return result.lastID;
    }

    /**
     * Search memories using hybrid approach
     *
     * Strategy:
     * 1. Check which embeddings are available for user
     * 2. Use neural embeddings (768-dim) if available
     * 3. Fall back to TF-IDF embeddings (100-dim) if needed
     * 4. Support mixed results during migration period
     */
    async searchMemories(userId, query, options = {}) {
        const startTime = Date.now();

        const {
            limit = 10,
            characterId = null,
            minSimilarity = this.similarityThreshold,
            includeMetadata = true
        } = options;

        try {
            // Generate query embedding with timing
            const embeddingStart = Date.now();
            const queryEmbedding = await this.generateEmbedding(query);
            const embeddingTime = Date.now() - embeddingStart;

            if (this.enableTiming && embeddingTime > 100) {
                console.log(`[HybridMemory] Query embedding took ${embeddingTime}ms`);
            }

            // Build SQL query to get memories with migration status
            let sql = `
                SELECT
                    id,
                    character_id,
                    memory_content,
                    embedding_vector_768,
                    embedding_vector as embedding_vector_old,
                    migration_status,
                    created_at,
                    ${includeMetadata ? 'emotional_context' : 'NULL as emotional_context'}
                FROM neural_memory_embeddings
                WHERE user_id = ?
            `;

            const params = [userId];

            if (characterId) {
                sql += ' AND character_id = ?';
                params.push(characterId);
            }

            // Get all matching memories
            const result = await this.db.query(sql, params);
            const memories = result.rows;

            if (memories.length === 0) {
                console.log(`[HybridMemory] No memories found for user ${userId}`);
                return [];
            }

            // Analyze migration status
            const neuralCount = memories.filter(m => m.embedding_vector_768).length;
            const oldCount = memories.filter(m => !m.embedding_vector_768 && m.embedding_vector_old).length;

            let searchType;
            if (neuralCount === memories.length) {
                searchType = 'neural_only';
                this.stats.neuralSearches++;
            } else if (oldCount === memories.length) {
                searchType = 'tfidf_only';
                this.stats.tfidfSearches++;
            } else {
                searchType = 'hybrid';
                this.stats.hybridSearches++;
            }

            console.log(`[HybridMemory] Search type: ${searchType}`, {
                neural: neuralCount,
                tfidf: oldCount,
                total: memories.length
            });

            // Calculate similarity for each memory
            const now = Date.now() / 1000;
            const scored = memories.map(memory => {
                let similarity;

                // Use neural embedding if available, otherwise fall back to old
                if (memory.embedding_vector_768) {
                    const memoryEmbedding = JSON.parse(memory.embedding_vector_768);
                    similarity = this.cosineSimilarity(queryEmbedding, memoryEmbedding);
                } else if (memory.embedding_vector_old) {
                    // For old embeddings, use different query embedding (would need to generate 100-dim TF-IDF)
                    // For now, use keyword fallback
                    similarity = this._keywordSimilarity(query, memory.memory_content);
                } else {
                    similarity = 0;
                }

                // Apply recency boost
                const ageInDays = (now - memory.created_at) / 86400;
                const recencyBoost = 1 + (this.recencyWeight / (1 + ageInDays));
                const score = similarity * recencyBoost;

                return {
                    id: memory.id,
                    characterId: memory.character_id,
                    content: memory.memory_content,
                    similarity: similarity,
                    score: score,
                    createdAt: memory.created_at,
                    metadata: memory.emotional_context ? JSON.parse(memory.emotional_context) : null,
                    embeddingType: memory.embedding_vector_768 ? 'neural' : 'tfidf'
                };
            });

            // Filter by threshold and sort
            const results = scored
                .filter(m => m.similarity >= minSimilarity)
                .sort((a, b) => b.score - a.score)
                .slice(0, limit);

            const searchTime = Date.now() - startTime;

            if (this.enableTiming) {
                this.timings.searches.push(searchTime);
            }

            const cacheStats = this.getCacheStats();
            console.log(`[HybridMemory] Search completed in ${searchTime}ms`, {
                found: `${results.length}/${memories.length}`,
                type: searchType,
                embeddingTime: `${embeddingTime}ms`,
                cacheHitRate: cacheStats.totalCacheHitRate
            });

            return results;

        } catch (error) {
            console.error('[HybridMemory] Search failed:', error.message);
            // Fall back to keyword search
            return this._keywordFallbackSearch(userId, query, limit);
        }
    }

    /**
     * Get migration progress for user
     */
    async getMigrationProgress(userId) {
        const result = await this.db.query(`
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN embedding_vector_768 IS NOT NULL THEN 1 ELSE 0 END) as neural,
                SUM(CASE WHEN embedding_vector_768 IS NULL THEN 1 ELSE 0 END) as pending,
                SUM(CASE WHEN migration_status = 'failed' THEN 1 ELSE 0 END) as failed
            FROM neural_memory_embeddings
            WHERE user_id = ?
        `, [userId]);
        const stats = result.rows[0];

        const progress = stats.total > 0
            ? ((stats.neural / stats.total) * 100).toFixed(2)
            : 0;

        return {
            ...stats,
            progress: `${progress}%`,
            complete: stats.neural === stats.total
        };
    }

    /**
     * Build user profile from interaction history (REQUIRED by ai-server)
     */
    async buildUserProfile(userId) {
        try {
            // Get all user memories to analyze patterns
            const result = await this.db.query(`
                SELECT memory_content, emotional_context, created_at
                FROM neural_memory_embeddings
                WHERE user_id = ?
                ORDER BY created_at DESC
                LIMIT 50
            `, [userId]);

            const memories = result.rows;

            if (memories.length === 0) {
                return this._getEmptyProfile();
            }

            // Analyze messaging style
            const avgLength = memories.reduce((sum, m) => sum + m.memory_content.length, 0) / memories.length;
            let messagingStyle = 'casual';
            if (avgLength > 500) messagingStyle = 'detailed';
            if (memories.some(m => m.memory_content.match(/\b(fuck|shit|damn)\b/i))) messagingStyle = 'explicit';

            // Detect NSFW preference
            const nsfwCount = memories.filter(m => m.memory_content.match(/\b(sex|sexual|nsfw|explicit)\b/i)).length;
            const nsfwPreference = nsfwCount > memories.length * 0.3 ? 'high' : 'low';

            return {
                messagingStyle,
                humorLevel: 'medium',
                nsfwPreference,
                topicInterests: [],
                preferenceLevel: messagingStyle === 'explicit' ? 'explicit' : 'standard',
                hasRealConversationHistory: true
            };

        } catch (error) {
            console.error('[HybridMemory] buildUserProfile failed:', error.message);
            return this._getEmptyProfile();
        }
    }

    /**
     * Helper: Return empty profile for users with no history
     */
    _getEmptyProfile() {
        return {
            messagingStyle: 'unknown',
            humorLevel: 'medium',
            nsfwPreference: 'low',
            topicInterests: [],
            preferenceLevel: 'standard',
            hasRealConversationHistory: false
        };
    }

    /**
     * Get enhanced context for conversation (REQUIRED by ai-server)
     */
    async getEnhancedContext(userId, conversationId, currentMessage, recentHistory = [], characterId = null) {
        const startTime = Date.now();

        try {
            // Search for relevant memories
            const memories = await this.searchMemories(userId, currentMessage, {
                limit: 10,
                characterId: characterId,
                minSimilarity: this.similarityThreshold
            });

            // Build user profile
            const profile = await this.buildUserProfile(userId);

            // Build context window from top memories
            const contextWindow = {
                responseGuidelines: [],
                relevantContext: ''
            };

            if (memories.length > 0) {
                contextWindow.relevantContext = memories
                    .slice(0, 3)
                    .map((m, i) => `${i+1}. ${m.content}`)
                    .join('\n');
            }

            // Generate prompt adjustments based on profile
            let promptAdjustments = '';
            if (profile.messagingStyle !== 'unknown') {
                promptAdjustments = `Adapt to user's ${profile.messagingStyle} communication style.`;
            }

            const retrievalTime = Date.now() - startTime;

            return {
                profile,
                contextWindow,
                promptAdjustments,
                relevantMemories: {
                    memories: memories,
                    noMemories: memories.length === 0
                },
                maxHistoryLength: memories.length > 5 ? 8 : 6,
                performanceMetrics: { retrievalTime }
            };

        } catch (error) {
            console.error('[HybridMemory] getEnhancedContext failed:', error.message);
            return this._getEmptyContext();
        }
    }

    /**
     * Helper: Return empty context for error fallback
     */
    _getEmptyContext() {
        return {
            profile: this._getEmptyProfile(),
            contextWindow: {},
            promptAdjustments: '',
            relevantMemories: { memories: [], noMemories: true },
            maxHistoryLength: 6,
            performanceMetrics: { retrievalTime: 0 }
        };
    }

    /**
     * Save interaction to memory (REQUIRED by ai-server)
     */
    async saveInteraction(userId, message, response, metadata = {}) {
        try {
            const combinedMessage = `User: ${message}\nAI: ${response}`;
            const characterId = metadata.character || metadata.characterId || null;

            return await this.saveMemory(userId, combinedMessage, characterId, {
                ...metadata,
                messageType: 'interaction',
                originalMessage: message,
                originalResponse: response
            });

        } catch (error) {
            console.error('[HybridMemory] saveInteraction failed:', error.message);
            throw error;
        }
    }

    /**
     * Calculate cosine similarity between two vectors
     */
    cosineSimilarity(vecA, vecB) {
        if (vecA.length !== vecB.length) {
            console.error('[HybridMemory] Vector length mismatch:', vecA.length, 'vs', vecB.length);
            return 0;
        }

        let dotProduct = 0;
        let normA = 0;
        let normB = 0;

        for (let i = 0; i < vecA.length; i++) {
            dotProduct += vecA[i] * vecB[i];
            normA += vecA[i] * vecA[i];
            normB += vecB[i] * vecB[i];
        }

        const denominator = Math.sqrt(normA) * Math.sqrt(normB);

        if (denominator === 0) {
            return 0;
        }

        return dotProduct / denominator;
    }

    /**
     * Get performance statistics
     */
    getStats() {
        const totalSearches = this.stats.neuralSearches + this.stats.tfidfSearches + this.stats.hybridSearches;
        const totalCacheHits = this.stats.memoryCacheHits + this.stats.persistentCacheHits;
        const totalRequests = totalCacheHits + this.stats.cacheMisses;

        const stats = {
            ...this.stats,
            totalSearches,
            neuralPercentage: totalSearches > 0 ? ((this.stats.neuralSearches / totalSearches) * 100).toFixed(2) + '%' : '0%',
            memoryCacheSize: this.embeddingCache.size,
            totalCacheHits,
            totalRequests,
            memoryCacheHitRate: totalRequests > 0 ? (this.stats.memoryCacheHits / totalRequests) : 0,
            persistentCacheHitRate: totalRequests > 0 ? (this.stats.persistentCacheHits / totalRequests) : 0,
            totalCacheHitRate: totalRequests > 0 ? (totalCacheHits / totalRequests) : 0
        };

        // Add persistent cache stats
        if (this.persistentCache) {
            const persistentStats = this.persistentCache.getStats();
            stats.persistentCacheStats = persistentStats;
        }

        return stats;
    }

    /**
     * Get detailed cache statistics (async for persistent cache size)
     */
    async getCacheStats() {
        const stats = this.getStats();

        // Add persistent cache size
        if (this.persistentCache) {
            stats.persistentCacheSize = await this.persistentCache.getSize();
        }

        return stats;
    }

    // ==================== PRIVATE METHODS ====================

    /**
     * Check if circuit breaker allows API call
     */
    _checkCircuitBreaker() {
        const now = Date.now();

        if (this.circuitBreaker.state === 'open') {
            if (now >= this.circuitBreaker.nextRetry) {
                // Try to recover - switch to half-open
                this.circuitBreaker.state = 'half-open';
                console.log('[HybridMemory] Circuit breaker half-open, attempting recovery');
                return true;
            }
            return false;
        }

        return true;
    }

    /**
     * Record successful API call
     */
    _recordSuccess() {
        if (this.circuitBreaker.state === 'half-open') {
            // Recovery successful
            this.circuitBreaker.state = 'closed';
            this.circuitBreaker.failures = 0;
            console.log('[HybridMemory] Circuit breaker closed - API recovered');
        } else {
            // Reset failure count on success
            this.circuitBreaker.failures = 0;
        }
    }

    /**
     * Record failed API call
     */
    _recordFailure() {
        this.circuitBreaker.failures++;

        if (this.circuitBreaker.failures >= this.circuitBreaker.threshold) {
            this.circuitBreaker.state = 'open';
            this.circuitBreaker.nextRetry = Date.now() + this.circuitBreaker.resetTimeout;
            this.stats.circuitBreakerTrips++;
            console.error(
                `[HybridMemory] Circuit breaker OPEN after ${this.circuitBreaker.failures} failures. ` +
                `Will retry in ${this.circuitBreaker.resetTimeout / 1000}s`
            );
        }
    }

    _normalizeVector(vector) {
        const norm = Math.sqrt(vector.reduce((sum, val) => sum + val * val, 0));
        return norm === 0 ? vector : vector.map(val => val / norm);
    }

    _getCacheKey(text) {
        // Use longer key for better differentiation
        return text.substring(0, 200).toLowerCase().trim();
    }

    _addToMemoryCache(key, embedding) {
        // LRU eviction for in-memory cache
        if (this.embeddingCache.size >= this.maxMemoryCacheSize) {
            const firstKey = this.embeddingCache.keys().next().value;
            this.embeddingCache.delete(firstKey);
        }
        this.embeddingCache.set(key, embedding);
    }

    _keywordSimilarity(query, content) {
        const queryWords = query.toLowerCase().split(/\s+/).filter(w => w.length > 2);
        const contentLower = content.toLowerCase();

        let matchCount = 0;
        for (const word of queryWords) {
            if (contentLower.includes(word)) {
                matchCount++;
            }
        }

        return queryWords.length > 0 ? matchCount / queryWords.length : 0;
    }

    async _keywordFallbackSearch(userId, query, limit) {
        const keywords = query.toLowerCase().split(/\s+/).filter(w => w.length > 2);

        if (keywords.length === 0) {
            return [];
        }

        const conditions = keywords.map(() => 'LOWER(memory_content) LIKE ?').join(' OR ');
        const params = [userId, ...keywords.map(k => `%${k}%`)];

        const sql = `
            SELECT id, character_id, memory_content, created_at
            FROM neural_memory_embeddings
            WHERE user_id = ? AND (${conditions})
            ORDER BY created_at DESC
            LIMIT ?
        `;

        params.push(limit);

        const result = await this.db.query(sql, params);
        const results = result.rows;

        return results.map(r => ({
            id: r.id,
            characterId: r.character_id,
            content: r.memory_content,
            similarity: 0.5,
            score: 0.5,
            createdAt: r.created_at,
            metadata: null,
            embeddingType: 'keyword_fallback'
        }));
    }
}

// ==================== USAGE EXAMPLE ====================

/**
 * Example: Using hybrid memory engine during migration
 */
async function exampleUsage(db) {
    const memoryEngine = new HybridMemoryEngine({
        database: db,
        preferNeuralEmbeddings: true // Use neural when available, fall back to TF-IDF
    });

    // Check migration progress for user
    const progress = await memoryEngine.getMigrationProgress(userId);
    console.log('Migration progress:', progress);
    // Output: { total: 100, neural: 75, pending: 25, failed: 0, progress: '75%', complete: false }

    // Search works seamlessly during migration
    const results = await memoryEngine.searchMemories(userId, "chocolate ice cream");
    console.log('Search results:', results);
    // Automatically uses neural embeddings for migrated memories,
    // falls back to keyword matching for pending memories

    // Save new memory (always uses neural embeddings)
    await memoryEngine.saveMemory(userId, "I love vanilla cake", characterId);

    // Get stats
    console.log('Engine stats:', memoryEngine.getStats());
}

module.exports = HybridMemoryEngine;
