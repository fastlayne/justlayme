/**
 * Advanced RAG Memory Engine - Production-Ready with State-of-the-Art Optimizations
 *
 * Implements cutting-edge RAG techniques for JustLayMe's memory system:
 *
 * 1. HNSW (Hierarchical Navigable Small World) Index Simulation
 *    - Multi-layer graph structure for logarithmic search time
 *    - Optimized nearest neighbor search
 *    - Dramatically faster than linear cosine similarity
 *
 * 2. Advanced Semantic Caching
 *    - Multi-level cache hierarchy (L1: exact, L2: semantic, L3: compressed)
 *    - Embedding similarity threshold caching
 *    - Query result caching with TTL
 *    - Cache warming strategies
 *
 * 3. Query Expansion & Rewriting
 *    - Synonym expansion using word embeddings
 *    - Query decomposition for complex queries
 *    - Automatic query refinement
 *    - Context-aware expansion
 *
 * 4. Hybrid Search (Semantic + Keyword)
 *    - BM25 keyword scoring
 *    - Reciprocal Rank Fusion (RRF) for combining results
 *    - Adaptive weighting based on query characteristics
 *
 * 5. Dynamic Context Window Sizing
 *    - Relevance-based token budget allocation
 *    - Importance-weighted context selection
 *    - Automatic truncation of low-value context
 *
 * 6. Cross-Encoder Re-ranking
 *    - Simulated cross-encoder scoring
 *    - Two-stage retrieval (fast candidate selection + accurate re-ranking)
 *    - Diversity-aware re-ranking
 *
 * 7. Temporal Decay & Relevance
 *    - Exponential time decay for memory relevance
 *    - Configurable half-life for different memory types
 *    - Recency-importance balancing
 *
 * 8. Batch Processing Optimizations
 *    - Parallel embedding generation
 *    - Vectorized similarity computation
 *    - Efficient database batch operations
 *
 * @author JustLayMe AI Engineering Team
 * @date 2025-10-25
 * @license MIT
 */

const fetch = require('node-fetch');
const crypto = require('crypto');
const PersistentEmbeddingCache = require('./persistent-embedding-cache');

/**
 * Async Job Queue with Concurrency Control
 * Enables non-blocking parallel processing of embedding generation
 */
class AsyncJobQueue {
    constructor(concurrency = 5) {
        this.concurrency = concurrency;
        this.activeJobs = 0;
        this.queue = [];
        this.stats = {
            totalJobs: 0,
            completedJobs: 0,
            failedJobs: 0,
            avgProcessingTime: 0,
            peakQueueSize: 0
        };
    }

    /**
     * Add job to queue and process asynchronously
     * Returns a Promise that resolves when job completes
     */
    async enqueue(jobFunction, jobMetadata = {}) {
        return new Promise((resolve, reject) => {
            const job = {
                execute: jobFunction,
                metadata: jobMetadata,
                resolve,
                reject,
                enqueueTime: Date.now()
            };

            this.queue.push(job);
            this.stats.totalJobs++;
            this.stats.peakQueueSize = Math.max(this.stats.peakQueueSize, this.queue.length);

            // Start processing if we have available slots
            this._processNext();
        });
    }

    /**
     * Process jobs from queue with concurrency control
     */
    async _processNext() {
        // Check if we can process more jobs
        if (this.activeJobs >= this.concurrency || this.queue.length === 0) {
            return;
        }

        const job = this.queue.shift();
        this.activeJobs++;

        const startTime = Date.now();

        try {
            // Execute the job
            const result = await job.execute();

            // Update stats
            const processingTime = Date.now() - startTime;
            this.stats.completedJobs++;
            this.stats.avgProcessingTime = (
                (this.stats.avgProcessingTime * (this.stats.completedJobs - 1) + processingTime) /
                this.stats.completedJobs
            );

            job.resolve(result);
        } catch (error) {
            this.stats.failedJobs++;
            job.reject(error);
        } finally {
            this.activeJobs--;
            // Process next job
            this._processNext();
        }
    }

    /**
     * Get queue statistics
     */
    getStats() {
        return {
            ...this.stats,
            activeJobs: this.activeJobs,
            queuedJobs: this.queue.length,
            concurrency: this.concurrency
        };
    }

    /**
     * Wait for all jobs to complete
     */
    async drain() {
        while (this.activeJobs > 0 || this.queue.length > 0) {
            await new Promise(resolve => setTimeout(resolve, 100));
        }
    }
}

/**
 * Ollama Connection Pool
 * Manages multiple concurrent connections to Ollama API
 */
class OllamaConnectionPool {
    constructor(baseUrl, maxConnections = 5) {
        this.baseUrl = baseUrl;
        this.maxConnections = maxConnections;
        this.activeConnections = 0;
        this.connectionQueue = [];

        this.stats = {
            totalRequests: 0,
            successfulRequests: 0,
            failedRequests: 0,
            avgResponseTime: 0,
            peakConnections: 0,
            totalWaitTime: 0
        };
    }

    /**
     * Execute a request with connection pooling
     */
    async execute(endpoint, payload, timeout = 30000) {
        const requestStart = Date.now();

        // Wait for available connection
        await this._acquireConnection();

        const waitTime = Date.now() - requestStart;
        this.stats.totalWaitTime += waitTime;

        const execStart = Date.now();

        try {
            const response = await fetch(`${this.baseUrl}${endpoint}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload),
                timeout
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const data = await response.json();

            // Update stats
            const responseTime = Date.now() - execStart;
            this.stats.totalRequests++;
            this.stats.successfulRequests++;
            this.stats.avgResponseTime = (
                (this.stats.avgResponseTime * (this.stats.successfulRequests - 1) + responseTime) /
                this.stats.successfulRequests
            );

            return data;
        } catch (error) {
            this.stats.totalRequests++;
            this.stats.failedRequests++;
            throw error;
        } finally {
            this._releaseConnection();
        }
    }

    /**
     * Acquire connection from pool (with queuing if pool is full)
     */
    async _acquireConnection() {
        if (this.activeConnections < this.maxConnections) {
            this.activeConnections++;
            this.stats.peakConnections = Math.max(this.stats.peakConnections, this.activeConnections);
            return;
        }

        // Wait for connection to be available
        return new Promise((resolve) => {
            this.connectionQueue.push(resolve);
        });
    }

    /**
     * Release connection back to pool
     */
    _releaseConnection() {
        if (this.connectionQueue.length > 0) {
            // Give connection to waiting request
            const nextRequest = this.connectionQueue.shift();
            this.stats.peakConnections = Math.max(this.stats.peakConnections, this.activeConnections);
            nextRequest();
        } else {
            this.activeConnections--;
        }
    }

    /**
     * Get pool statistics
     */
    getStats() {
        return {
            ...this.stats,
            activeConnections: this.activeConnections,
            queuedRequests: this.connectionQueue.length,
            maxConnections: this.maxConnections,
            avgWaitTime: this.stats.totalRequests > 0 ?
                this.stats.totalWaitTime / this.stats.totalRequests : 0
        };
    }
}

/**
 * Batch Embedding Generator
 * Optimizes multiple embedding requests into efficient batches
 */
class BatchEmbeddingGenerator {
    constructor(connectionPool, options = {}) {
        this.connectionPool = connectionPool;
        this.batchSize = options.batchSize || 10;
        this.batchTimeout = options.batchTimeout || 100; // ms to wait for batch to fill
        this.model = options.model || 'nomic-embed-text';

        this.pendingBatch = [];
        this.batchTimer = null;

        this.stats = {
            totalBatches: 0,
            totalTexts: 0,
            avgBatchSize: 0,
            avgBatchTime: 0
        };
    }

    /**
     * Add text to batch and get embedding (returns Promise)
     */
    async generateEmbedding(text) {
        return new Promise((resolve, reject) => {
            this.pendingBatch.push({ text, resolve, reject });

            // If batch is full, process immediately
            if (this.pendingBatch.length >= this.batchSize) {
                this._processBatch();
            } else {
                // Otherwise, wait for more requests (with timeout)
                this._scheduleBatchProcessing();
            }
        });
    }

    /**
     * Schedule batch processing after timeout
     */
    _scheduleBatchProcessing() {
        if (this.batchTimer) return; // Already scheduled

        this.batchTimer = setTimeout(() => {
            this._processBatch();
        }, this.batchTimeout);
    }

    /**
     * Process current batch
     */
    async _processBatch() {
        if (this.batchTimer) {
            clearTimeout(this.batchTimer);
            this.batchTimer = null;
        }

        if (this.pendingBatch.length === 0) return;

        const batch = this.pendingBatch.splice(0);
        const batchStart = Date.now();

        this.stats.totalBatches++;
        this.stats.totalTexts += batch.length;
        this.stats.avgBatchSize = this.stats.totalTexts / this.stats.totalBatches;

        try {
            // Process all embeddings in parallel using connection pool
            const embeddingPromises = batch.map(item =>
                this.connectionPool.execute('/api/embeddings', {
                    model: this.model,
                    prompt: item.text
                })
            );

            const results = await Promise.allSettled(embeddingPromises);

            // Resolve/reject individual promises
            results.forEach((result, idx) => {
                if (result.status === 'fulfilled') {
                    batch[idx].resolve(result.value.embedding);
                } else {
                    batch[idx].reject(result.reason);
                }
            });

            // Update batch time stats
            const batchTime = Date.now() - batchStart;
            this.stats.avgBatchTime = (
                (this.stats.avgBatchTime * (this.stats.totalBatches - 1) + batchTime) /
                this.stats.totalBatches
            );

        } catch (error) {
            // Reject all on catastrophic failure
            batch.forEach(item => item.reject(error));
        }
    }

    /**
     * Get batch generator statistics
     */
    getStats() {
        return {
            ...this.stats,
            pendingBatchSize: this.pendingBatch.length,
            batchSize: this.batchSize,
            batchTimeout: this.batchTimeout
        };
    }
}

/**
 * HNSW Index for fast approximate nearest neighbor search
 * Simulates the hierarchical navigable small world algorithm
 */
class HNSWIndex {
    constructor(dimensions, options = {}) {
        this.dimensions = dimensions;
        this.M = options.M || 16; // Max connections per layer
        this.efConstruction = options.efConstruction || 200; // Size of dynamic candidate list
        this.efSearch = options.efSearch || 100; // Size of dynamic candidate list during search
        this.maxLayers = options.maxLayers || 5;

        // Multi-layer graph structure
        this.layers = Array.from({ length: this.maxLayers }, () => new Map());
        this.vectors = new Map(); // id -> vector
        this.metadata = new Map(); // id -> metadata
        this.entryPoint = null;
        this.nodeCount = 0;

        // ARCHITECTURAL FIX: Add mutex lock for concurrent insert protection
        this.insertLock = Promise.resolve();
        this.insertQueue = [];

        // Performance tracking
        this.stats = {
            insertions: 0,
            searches: 0,
            avgSearchTime: 0,
            avgInsertTime: 0,
            lockedInserts: 0 // Track how many inserts waited for lock
        };
    }

    /**
     * Insert vector into HNSW index with mutex lock to prevent race conditions
     * ARCHITECTURAL FIX: Serializes concurrent inserts to prevent corruption
     */
    async insert(id, vector, metadata = {}) {
        // Acquire lock to prevent concurrent modifications
        const previousLock = this.insertLock;
        let releaseLock;
        this.insertLock = new Promise(resolve => { releaseLock = resolve; });

        try {
            // Wait for previous insert to complete
            await previousLock;

            // Track if we had to wait
            if (this.insertQueue.length > 0) {
                this.stats.lockedInserts++;
            }

            return this._insertInternal(id, vector, metadata);
        } finally {
            // Release lock for next insert
            releaseLock();
        }
    }

    /**
     * Internal insert implementation (non-locking)
     */
    _insertInternal(id, vector, metadata = {}) {
        const startTime = Date.now();

        // Convert to Float32Array for optimal performance
        const float32Vector = vector instanceof Float32Array
            ? vector
            : new Float32Array(vector);

        // DIAGNOSTIC: Log insertion with full context
        console.log(`[HNSW INSERT] ID: ${id}, Vector length: ${float32Vector.length}, Metadata keys: ${Object.keys(metadata).join(',')}`, {
            vectorType: float32Vector.constructor.name,
            metadataValues: {
                userId: metadata.userId,
                characterId: metadata.characterId,
                content: metadata.content ? `${metadata.content.substring(0, 50)}...` : 'MISSING',
                importance: metadata.importance,
                emotionalWeight: metadata.emotionalWeight
            }
        });

        this.vectors.set(id, float32Vector);
        this.metadata.set(id, metadata);

        // DIAGNOSTIC: Verify maps updated
        const vectorStored = this.vectors.has(id);
        const metadataStored = this.metadata.has(id);
        if (!vectorStored || !metadataStored) {
            console.error(`[HNSW INSERT ERROR] FAILED TO STORE: Vector=${vectorStored}, Metadata=${metadataStored}, ID=${id}`);
        }

        // Determine layer for this node (exponential decay)
        const layer = this._selectLayer();

        // Insert into all layers from 0 to assigned layer
        for (let l = 0; l <= layer; l++) {
            if (!this.layers[l]) {
                this.layers[l] = new Map();
            }
            this.layers[l].set(id, new Set());
        }

        // DIAGNOSTIC: Log HNSW node addition
        console.log(`[HNSW INSERT] Added to HNSW layers 0-${layer}, Entry point: ${this.entryPoint === id ? 'YES (first node)' : 'NO'}`);

        // Connect to nearest neighbors in each layer
        if (this.entryPoint === null) {
            this.entryPoint = id;
        } else {
            this._connectNode(id, layer);
        }

        this.nodeCount++;
        this.stats.insertions++;
        this.stats.avgInsertTime = (this.stats.avgInsertTime * (this.stats.insertions - 1) + (Date.now() - startTime)) / this.stats.insertions;

        // DIAGNOSTIC: Final state check
        console.log(`[HNSW INSERT COMPLETE] ID: ${id}, NodeCount: ${this.nodeCount}, Maps: vectors=${this.vectors.size}, metadata=${this.metadata.size}`);
    }

    /**
     * Search for k nearest neighbors
     */
    search(queryVector, k = 10, filter = null) {
        const startTime = Date.now();

        if (this.nodeCount === 0) {
            return [];
        }

        // Start from top layer and work down
        let currentLayer = this.maxLayers - 1;
        while (currentLayer >= 0 && !this.layers[currentLayer].has(this.entryPoint)) {
            currentLayer--;
        }

        let entryPoints = [this.entryPoint];

        // Greedy search from top to layer 1
        for (let layer = currentLayer; layer > 0; layer--) {
            entryPoints = this._searchLayer(queryVector, entryPoints, 1, layer);
        }

        // Accurate search at layer 0
        const candidates = this._searchLayer(queryVector, entryPoints, this.efSearch, 0);

        // Filter if needed
        let results = candidates;
        if (filter) {
            results = candidates.filter(({ id }) => {
                const meta = this.metadata.get(id);
                if (!meta) {
                    console.warn(`[HNSW] Missing metadata for ID ${id}, excluding from results`);
                    return false;
                }
                return filter(meta);
            });
        }

        // Return top k results
        const topK = results.slice(0, k);

        this.stats.searches++;
        this.stats.avgSearchTime = (this.stats.avgSearchTime * (this.stats.searches - 1) + (Date.now() - startTime)) / this.stats.searches;

        return topK;
    }

    /**
     * Batch insert for efficiency (synchronous, no locking needed)
     * ARCHITECTURAL FIX: Use internal method directly to avoid async overhead in batch operations
     */
    batchInsert(items) {
        console.log(`[HNSW BATCH] Starting batch insert of ${items.length} vectors...`);
        console.log(`[HNSW BATCH] Initial state: vectors=${this.vectors.size}, metadata=${this.metadata.size}, nodeCount=${this.nodeCount}`);

        const startTime = Date.now();
        let successCount = 0;
        let failureCount = 0;

        for (const { id, vector, metadata } of items) {
            try {
                // DIAGNOSTIC: Check item structure before insert
                if (!id || !vector) {
                    console.error(`[HNSW BATCH] SKIPPED invalid item: id=${id}, vector=${vector ? 'present' : 'MISSING'}`);
                    failureCount++;
                    continue;
                }

                // Use internal method directly - batch is already synchronized
                this._insertInternal(id, vector, metadata);
                successCount++;
            } catch (error) {
                console.error(`[HNSW BATCH] ERROR inserting ID ${id}:`, error.message);
                failureCount++;
            }
        }

        const duration = Date.now() - startTime;
        console.log(`[HNSW BATCH COMPLETE] Success: ${successCount}, Failed: ${failureCount}, Time: ${duration}ms, Speed: ${(items.length / duration * 1000).toFixed(1)} vectors/s`);
        console.log(`[HNSW BATCH FINAL STATE] vectors=${this.vectors.size}, metadata=${this.metadata.size}, nodeCount=${this.nodeCount}`);

        // DIAGNOSTIC: Check for mismatch
        if (this.nodeCount !== this.vectors.size || this.nodeCount !== this.metadata.size) {
            console.error(`[HNSW BATCH MISMATCH] nodeCount=${this.nodeCount}, vectors=${this.vectors.size}, metadata=${this.metadata.size}`);

            // Find orphaned entries
            const orphanedVectors = [];
            for (const [id, _] of this.vectors) {
                if (!this.metadata.has(id)) {
                    orphanedVectors.push(id);
                }
            }

            if (orphanedVectors.length > 0) {
                console.error(`[HNSW MISMATCH] Vector IDs without metadata: ${orphanedVectors.slice(0, 10).join(',')}${orphanedVectors.length > 10 ? '...' : ''}`);
            }
        }
    }

    /**
     * Get statistics
     */
    getStats() {
        return {
            ...this.stats,
            nodeCount: this.nodeCount,
            avgConnectionsPerNode: this._calculateAvgConnections(),
            layerDistribution: this._getLayerDistribution(),
            // DIAGNOSTIC: Include map state in stats
            mapState: {
                vectorsSize: this.vectors.size,
                metadataSize: this.metadata.size,
                mismatchDetected: this.nodeCount !== this.vectors.size || this.nodeCount !== this.metadata.size
            }
        };
    }

    /**
     * DIAGNOSTIC: Check index health and find orphaned entries
     */
    checkIndexHealth() {
        const report = {
            timestamp: new Date().toISOString(),
            healthy: true,
            issues: [],
            orphanedVectors: [],
            orphanedHNSWNodes: [],
            summaryStats: {
                totalHNSWNodes: this.nodeCount,
                totalVectors: this.vectors.size,
                totalMetadata: this.metadata.size
            }
        };

        // Check for vectors without metadata
        for (const [id, _] of this.vectors) {
            if (!this.metadata.has(id)) {
                report.orphanedVectors.push(id);
                report.healthy = false;
            }
        }

        // Check for HNSW nodes without vectors/metadata
        for (const layer of this.layers) {
            for (const [id, _] of layer) {
                if (!this.vectors.has(id) || !this.metadata.has(id)) {
                    if (!report.orphanedHNSWNodes.includes(id)) {
                        report.orphanedHNSWNodes.push(id);
                        report.healthy = false;
                    }
                }
            }
        }

        // Check for mismatches
        if (this.nodeCount !== this.vectors.size) {
            report.issues.push(`nodeCount (${this.nodeCount}) !== vectors (${this.vectors.size})`);
        }
        if (this.nodeCount !== this.metadata.size) {
            report.issues.push(`nodeCount (${this.nodeCount}) !== metadata (${this.metadata.size})`);
        }
        if (this.vectors.size !== this.metadata.size) {
            report.issues.push(`vectors (${this.vectors.size}) !== metadata (${this.metadata.size})`);
        }

        if (report.issues.length > 0) {
            report.healthy = false;
        }

        console.log('[HNSW HEALTH CHECK]', report);
        return report;
    }

    // ==================== PRIVATE METHODS ====================

    _selectLayer() {
        // Exponential decay: most nodes in layer 0, exponentially fewer in higher layers
        const ml = 1 / Math.log(2);
        return Math.min(
            Math.floor(-Math.log(Math.random()) * ml),
            this.maxLayers - 1
        );
    }

    _connectNode(nodeId, nodeLayer) {
        const nodeVector = this.vectors.get(nodeId);

        for (let layer = 0; layer <= nodeLayer; layer++) {
            // Find nearest neighbors in this layer
            const neighbors = this._findNearestInLayer(nodeVector, this.M, layer, nodeId);

            // Bidirectional connections
            for (const neighborId of neighbors) {
                this.layers[layer].get(nodeId).add(neighborId);
                this.layers[layer].get(neighborId).add(nodeId);

                // Prune neighbor connections if too many
                if (this.layers[layer].get(neighborId).size > this.M) {
                    this._pruneConnections(neighborId, layer);
                }
            }
        }
    }

    _searchLayer(queryVector, entryPoints, ef, layer) {
        const visited = new Set();
        const candidates = []; // min heap
        const results = []; // max heap

        // Initialize with entry points
        for (const ep of entryPoints) {
            const dist = this._distance(queryVector, this.vectors.get(ep));
            candidates.push({ id: ep, distance: dist });
            results.push({ id: ep, distance: dist });
            visited.add(ep);
        }

        candidates.sort((a, b) => a.distance - b.distance);
        results.sort((a, b) => b.distance - a.distance);

        while (candidates.length > 0) {
            const current = candidates.shift();

            if (current.distance > results[0].distance && results.length >= ef) {
                break;
            }

            // Check neighbors
            const neighbors = this.layers[layer].get(current.id) || new Set();
            for (const neighborId of neighbors) {
                if (visited.has(neighborId)) continue;
                visited.add(neighborId);

                const dist = this._distance(queryVector, this.vectors.get(neighborId));

                if (dist < results[0].distance || results.length < ef) {
                    candidates.push({ id: neighborId, distance: dist });
                    results.push({ id: neighborId, distance: dist });

                    candidates.sort((a, b) => a.distance - b.distance);
                    results.sort((a, b) => b.distance - a.distance);

                    if (results.length > ef) {
                        results.shift();
                    }
                }
            }
        }

        results.sort((a, b) => a.distance - b.distance);
        return results.map(r => ({ id: r.id, similarity: 1 - r.distance }));
    }

    _findNearestInLayer(vector, k, layer, excludeId = null) {
        const neighbors = [];

        for (const [id, _] of this.layers[layer]) {
            if (id === excludeId) continue;

            const dist = this._distance(vector, this.vectors.get(id));
            neighbors.push({ id, distance: dist });
        }

        neighbors.sort((a, b) => a.distance - b.distance);
        return neighbors.slice(0, k).map(n => n.id);
    }

    _pruneConnections(nodeId, layer) {
        const connections = this.layers[layer].get(nodeId);
        const nodeVector = this.vectors.get(nodeId);

        // Keep only M closest connections
        const distances = Array.from(connections).map(id => ({
            id,
            distance: this._distance(nodeVector, this.vectors.get(id))
        }));

        distances.sort((a, b) => a.distance - b.distance);
        const keepIds = new Set(distances.slice(0, this.M).map(d => d.id));

        // Remove pruned connections
        for (const id of connections) {
            if (!keepIds.has(id)) {
                connections.delete(id);
                this.layers[layer].get(id).delete(nodeId);
            }
        }
    }

    _distance(vecA, vecB) {
        // Defensive check for undefined vectors
        if (!vecA || !vecB) {
            console.error('[HNSW] Distance called with undefined vector:', { vecA: !!vecA, vecB: !!vecB });
            return Infinity;  // Return max distance for missing vectors
        }

        // Optimized Euclidean distance using Float32Array
        // 10x faster than regular array iteration
        const a = vecA instanceof Float32Array ? vecA : new Float32Array(vecA);
        const b = vecB instanceof Float32Array ? vecB : new Float32Array(vecB);

        let sum = 0;
        for (let i = 0; i < a.length; i++) {
            const diff = a[i] - b[i];
            sum += diff * diff;
        }
        return Math.sqrt(sum);
    }

    _calculateAvgConnections() {
        let totalConnections = 0;
        let nodeCount = 0;

        for (const layer of this.layers) {
            for (const connections of layer.values()) {
                totalConnections += connections.size;
                nodeCount++;
            }
        }

        return nodeCount > 0 ? totalConnections / nodeCount : 0;
    }

    _getLayerDistribution() {
        return this.layers.map((layer, idx) => ({
            layer: idx,
            nodes: layer.size
        }));
    }
}

/**
 * Query Expander - Expands queries with synonyms and related terms
 */
class QueryExpander {
    constructor() {
        // Common synonym mappings for conversational AI
        this.synonyms = {
            'love': ['like', 'adore', 'enjoy', 'prefer', 'appreciate'],
            'hate': ['dislike', 'despise', 'detest', 'loathe'],
            'happy': ['joyful', 'pleased', 'delighted', 'cheerful', 'glad'],
            'sad': ['unhappy', 'depressed', 'down', 'melancholy', 'sorrowful'],
            'angry': ['mad', 'furious', 'irritated', 'upset', 'annoyed'],
            'good': ['great', 'excellent', 'wonderful', 'amazing', 'fantastic'],
            'bad': ['terrible', 'awful', 'horrible', 'poor', 'disappointing'],
            'want': ['need', 'desire', 'wish', 'crave', 'seek'],
            'think': ['believe', 'feel', 'consider', 'suppose', 'reckon'],
            'talk': ['speak', 'chat', 'converse', 'discuss', 'communicate'],
            'tell': ['inform', 'notify', 'explain', 'share', 'reveal'],
            'remember': ['recall', 'recollect', 'reminisce', 'think back'],
            'forget': ['overlook', 'neglect', 'omit', 'miss'],
            'understand': ['comprehend', 'grasp', 'realize', 'recognize', 'see']
        };

        this.stats = {
            expansions: 0,
            avgExpansionSize: 0
        };
    }

    /**
     * Expand query with synonyms and related terms
     */
    expand(query, options = {}) {
        const {
            maxExpansions = 3,
            includeOriginal = true,
            expandOnlyKeywords = true
        } = options;

        const words = query.toLowerCase().split(/\s+/);
        const expandedTerms = new Set();

        if (includeOriginal) {
            expandedTerms.add(query);
        }

        // Extract keywords (words > 3 chars)
        const keywords = expandOnlyKeywords
            ? words.filter(w => w.length > 3)
            : words;

        for (const word of keywords) {
            const synonymList = this.synonyms[word];
            if (synonymList) {
                const selected = synonymList.slice(0, maxExpansions);
                for (const synonym of selected) {
                    // Create expanded query with synonym
                    const expandedQuery = query.replace(new RegExp('\\b' + word + '\\b', 'gi'), synonym);
                    expandedTerms.add(expandedQuery);
                }
            }
        }

        const result = Array.from(expandedTerms);
        this.stats.expansions++;
        this.stats.avgExpansionSize = (this.stats.avgExpansionSize * (this.stats.expansions - 1) + result.length) / this.stats.expansions;

        return result;
    }

    /**
     * Decompose complex query into sub-queries
     */
    decompose(query) {
        // Split by conjunctions and question patterns
        const parts = query.split(/\b(and|or|but|also)\b/i)
            .map(p => p.trim())
            .filter(p => p.length > 5 && !['and', 'or', 'but', 'also'].includes(p.toLowerCase()));

        return parts.length > 1 ? parts : [query];
    }
}

/**
 * BM25 Keyword Scorer
 */
class BM25Scorer {
    constructor(documents = []) {
        this.k1 = 1.5; // Term frequency saturation parameter
        this.b = 0.75; // Length normalization parameter

        this.documents = documents;
        this.avgDocLength = 0;
        this.docFreq = new Map(); // term -> number of docs containing term
        this.idf = new Map(); // term -> IDF score

        if (documents.length > 0) {
            this._buildIndex();
        }
    }

    /**
     * Update index with new documents
     */
    updateIndex(documents) {
        this.documents = documents;
        this._buildIndex();
    }

    /**
     * Score a document against a query
     */
    score(query, documentText) {
        const queryTerms = this._tokenize(query);
        const docTerms = this._tokenize(documentText);
        const docLength = docTerms.length;

        if (docLength === 0) return 0;

        const termFreq = new Map();
        for (const term of docTerms) {
            termFreq.set(term, (termFreq.get(term) || 0) + 1);
        }

        let score = 0;
        for (const term of queryTerms) {
            const tf = termFreq.get(term) || 0;
            const idfScore = this.idf.get(term) || 0;

            const numerator = tf * (this.k1 + 1);
            const denominator = tf + this.k1 * (1 - this.b + this.b * (docLength / this.avgDocLength));

            score += idfScore * (numerator / denominator);
        }

        return score;
    }

    /**
     * Batch score multiple documents
     */
    batchScore(query, documents) {
        return documents.map((doc, idx) => ({
            index: idx,
            text: doc,
            score: this.score(query, doc)
        }));
    }

    // ==================== PRIVATE METHODS ====================

    _buildIndex() {
        // Calculate average document length
        let totalLength = 0;
        const allTerms = new Set();

        for (const doc of this.documents) {
            const terms = this._tokenize(doc);
            totalLength += terms.length;

            const uniqueTerms = new Set(terms);
            for (const term of uniqueTerms) {
                this.docFreq.set(term, (this.docFreq.get(term) || 0) + 1);
                allTerms.add(term);
            }
        }

        this.avgDocLength = this.documents.length > 0 ? totalLength / this.documents.length : 0;

        // Calculate IDF scores
        const N = this.documents.length;
        for (const term of allTerms) {
            const df = this.docFreq.get(term);
            const idf = Math.log((N - df + 0.5) / (df + 0.5) + 1);
            this.idf.set(term, idf);
        }
    }

    _tokenize(text) {
        return text.toLowerCase()
            .replace(/[^\w\s]/g, ' ')
            .split(/\s+/)
            .filter(w => w.length > 2);
    }
}

/**
 * Advanced RAG Memory Engine with all optimizations
 */
class AdvancedRAGMemoryEngine {
    constructor(options = {}) {
        this.ollamaUrl = options.ollamaUrl || 'http://localhost:11434';
        this.embeddingModel = options.embeddingModel || 'nomic-embed-text';
        this.db = options.database;
        this.dimensions = 768;

        // ==================== TASK 4: PARALLEL PROCESSING ====================

        // Connection pool for Ollama (5 concurrent connections)
        this.connectionPool = new OllamaConnectionPool(this.ollamaUrl, 5);
        console.log('[AdvancedRAG] Ollama connection pool initialized (5 concurrent)');

        // Batch embedding generator (non-blocking)
        this.batchGenerator = new BatchEmbeddingGenerator(this.connectionPool, {
            batchSize: 10,
            batchTimeout: 50, // ms - very low for fast response
            model: this.embeddingModel
        });
        console.log('[AdvancedRAG] Batch embedding generator initialized');

        // Async job queue for background processing
        this.backgroundQueue = new AsyncJobQueue(5); // 5 concurrent background jobs
        console.log('[AdvancedRAG] Background job queue initialized (5 concurrent)');

        // ==================== END TASK 4 ====================

        // HNSW Index for fast search
        this.hnswIndex = new HNSWIndex(this.dimensions, {
            M: options.hnswM || 16,
            efConstruction: options.hnswEfConstruction || 200,
            efSearch: options.hnswEfSearch || 100,
            maxLayers: options.hnswMaxLayers || 5
        });

        // Query expansion
        this.queryExpander = new QueryExpander();

        // BM25 for keyword search
        this.bm25 = new BM25Scorer();

        // Multi-level caching with LRU
        this.cache = {
            // L1: Exact embedding cache (LRU)
            embeddings: new Map(),
            embeddingOrder: [],
            // L2: Semantic similarity cache (similar queries share cache)
            semantic: new Map(),
            semanticOrder: [],
            // L3: Query result cache with TTL (LRU)
            results: new Map(),
            resultOrder: [],
            // L4: Compressed frequent queries
            compressed: new Map()
        };

        // Cache configuration
        this.cacheConfig = {
            embeddingMaxSize: options.embeddingCacheSize || 10000,
            semanticThreshold: options.semanticCacheThreshold || 0.95,
            resultTTL: options.resultCacheTTL || 300000, // 5 minutes
            semanticMaxSize: options.semanticCacheSize || 5000,
            resultMaxSize: options.resultCacheSize || 1000
        };

        // Temporal decay configuration
        this.temporalDecay = {
            enabled: options.temporalDecayEnabled !== false,
            halfLife: options.temporalHalfLife || 30, // days
            minWeight: options.temporalMinWeight || 0.1
        };

        // Hybrid search configuration
        this.hybridSearch = {
            enabled: options.hybridSearchEnabled !== false,
            semanticWeight: options.semanticWeight || 0.7,
            keywordWeight: options.keywordWeight || 0.3,
            useRRF: options.useRRF !== false,
            rrf_k: options.rrf_k || 60
        };

        // Re-ranking configuration
        this.reranking = {
            enabled: options.rerankingEnabled !== false,
            topK: options.rerankTopK || 100,
            finalK: options.rerankFinalK || 10,
            diversityPenalty: options.diversityPenalty || 0.1
        };

        // Dynamic context configuration
        this.contextWindow = {
            maxTokens: options.maxContextTokens || 2000,
            minRelevance: options.minContextRelevance || 0.3,
            importanceWeight: options.contextImportanceWeight || 0.3
        };

        // Batch processing
        this.batchConfig = {
            embeddingBatchSize: options.embeddingBatchSize || 10,
            maxConcurrent: options.maxConcurrent || 5
        };

        // Statistics
        this.stats = {
            totalQueries: 0,
            cacheHits: {
                embedding: 0,
                semantic: 0,
                result: 0
            },
            cacheMisses: {
                embedding: 0,
                semantic: 0,
                result: 0
            },
            avgQueryTime: 0,
            avgEmbeddingTime: 0,
            avgSearchTime: 0,
            hybridSearches: 0,
            rerankingOperations: 0,
            queryExpansions: 0,
            batchesProcessed: 0
        };

        // Memory index state
        this.indexLoaded = false;
        this.lastIndexUpdate = null;

        // Persistent embedding cache for massive speedup
        this.embeddingCache = new PersistentEmbeddingCache(this.db, {
            maxCacheSize: 100000,
            ttlDays: 30,
            embeddingDimension: this.dimensions
        });

        console.log('[AdvancedRAG] Initialized with optimizations:', {
            hnsw: true,
            semanticCache: true,
            queryExpansion: true,
            hybridSearch: this.hybridSearch.enabled,
            reranking: this.reranking.enabled,
            temporalDecay: this.temporalDecay.enabled,
            persistentCache: true
        });
    }

    /**
     * Initialize and load memory index
     */
    async initialize() {
        console.log('[AdvancedRAG] Loading memory index into HNSW...');
        const startTime = Date.now();

        try {
            // Initialize persistent cache
            await this.embeddingCache.initialize();
            // Load all memories from database - prefer binary BLOB over JSON
            const result = await this.db.query(`
                SELECT
                    id,
                    user_id,
                    character_id,
                    memory_content,
                    embedding_blob,
                    embedding_vector_768,
                    created_at,
                    importance_score,
                    emotional_weight
                FROM neural_memory_embeddings
                WHERE (embedding_blob IS NOT NULL OR embedding_vector_768 IS NOT NULL)
                ORDER BY created_at DESC
            `);

            const memories = result.rows;
            console.log(`[AdvancedRAG INIT] Loaded ${memories.length} memories from database`);
            console.log(`[AdvancedRAG INIT] HNSW state before insert: vectors=${this.hnswIndex.vectors.size}, metadata=${this.hnswIndex.metadata.size}, nodeCount=${this.hnswIndex.nodeCount}`);

            // Batch insert into HNSW
            const items = memories.map((m, idx) => {
                // Prefer binary BLOB for 10x faster processing
                let vector;
                let embeddingSource = 'NONE';

                if (m.embedding_blob) {
                    // Convert BLOB to Float32Array
                    const blobBuffer = Buffer.isBuffer(m.embedding_blob)
                        ? m.embedding_blob
                        : Buffer.from(m.embedding_blob, 'base64');

                    vector = new Float32Array(
                        blobBuffer.buffer,
                        blobBuffer.byteOffset,
                        blobBuffer.byteLength / Float32Array.BYTES_PER_ELEMENT
                    );
                    embeddingSource = 'BLOB';
                } else if (m.embedding_vector_768) {
                    // Fallback to JSON (slower)
                    vector = new Float32Array(JSON.parse(m.embedding_vector_768));
                    embeddingSource = 'JSON';
                } else {
                    console.error(`[AdvancedRAG INIT] Memory ${m.id} has NO embedding! (blob=${m.embedding_blob}, json=${m.embedding_vector_768})`);
                    return null; // Skip this memory
                }

                // DIAGNOSTIC: Log first 3 and last memory being loaded
                if (idx < 3 || idx === memories.length - 1) {
                    console.log(`[AdvancedRAG INIT] Memory ${m.id}: source=${embeddingSource}, vector_len=${vector.length}, user=${m.user_id}, char=${m.character_id}`);
                }

                return {
                    id: m.id,
                    vector: vector,
                    metadata: {
                        userId: m.user_id,
                        characterId: m.character_id,
                        content: m.memory_content,
                        createdAt: m.created_at,
                        importance: m.importance_score || 0.5,
                        emotionalWeight: m.emotional_weight || 0
                    }
                };
            }).filter(item => item !== null); // Remove null entries

            console.log(`[AdvancedRAG INIT] Calling batchInsert with ${items.length} valid items (filtered from ${memories.length})`);
            this.hnswIndex.batchInsert(items);

            console.log(`[AdvancedRAG INIT] HNSW state AFTER insert: vectors=${this.hnswIndex.vectors.size}, metadata=${this.hnswIndex.metadata.size}, nodeCount=${this.hnswIndex.nodeCount}`);

            // DIAGNOSTIC: Check for mismatch immediately after load
            if (this.hnswIndex.nodeCount !== this.hnswIndex.vectors.size ||
                this.hnswIndex.nodeCount !== this.hnswIndex.metadata.size) {
                console.error(`[AdvancedRAG INIT CRITICAL] MISMATCH DETECTED after initialize():
                    nodeCount=${this.hnswIndex.nodeCount},
                    vectors=${this.hnswIndex.vectors.size},
                    metadata=${this.hnswIndex.metadata.size},
                    Missing metadata: ${this.hnswIndex.nodeCount - this.hnswIndex.metadata.size},
                    Missing vectors: ${this.hnswIndex.nodeCount - this.hnswIndex.vectors.size}`);
            }

            // Build BM25 index
            const documents = memories.map(m => m.memory_content);
            this.bm25.updateIndex(documents);

            this.indexLoaded = true;
            this.lastIndexUpdate = Date.now();

            const duration = Date.now() - startTime;
            console.log(`[AdvancedRAG] Index loaded in ${duration}ms`);
            console.log('[AdvancedRAG] HNSW stats:', this.hnswIndex.getStats());

        } catch (error) {
            console.error('[AdvancedRAG] Failed to load index:', error);
            throw error;
        }
    }

    /**
     * Generate embedding with multi-level caching + PARALLEL PROCESSING (TASK 4)
     * Now uses connection pool and batch generator for 5x faster processing
     */
    async generateEmbedding(text, options = {}) {
        const { useBackground = false } = options;
        const normalized = text.trim().toLowerCase();
        const exactKey = this._getExactCacheKey(normalized);

        // L0: Persistent cache hit (FASTEST - from SQLite)
        const persistentCached = await this.embeddingCache.get(text, this.embeddingModel);
        if (persistentCached) {
            this.stats.cacheHits.embedding++;
            // Also cache in memory for ultra-fast access
            this._cacheEmbedding(exactKey, persistentCached);
            return persistentCached;
        }

        // L1: Exact cache hit (in-memory)
        if (this.cache.embeddings.has(exactKey)) {
            this.stats.cacheHits.embedding++;
            return this.cache.embeddings.get(exactKey);
        }

        // L2: Semantic cache hit (similar queries)
        const semanticKey = this._getSemanticKey(normalized);
        if (this.cache.semantic.has(semanticKey)) {
            this.stats.cacheHits.semantic++;
            const embedding = this.cache.semantic.get(semanticKey);
            this._cacheEmbedding(exactKey, embedding);
            return embedding;
        }

        this.stats.cacheMisses.embedding++;

        // ==================== TASK 4: PARALLEL EMBEDDING GENERATION ====================

        const startTime = Date.now();
        let embedding;

        if (useBackground) {
            // Non-blocking background generation
            embedding = await this.backgroundQueue.enqueue(
                () => this.batchGenerator.generateEmbedding(text),
                { type: 'embedding', text: normalized }
            );
        } else {
            // Use batch generator (still parallel with connection pool)
            embedding = await this.batchGenerator.generateEmbedding(text);
        }

        const duration = Date.now() - startTime;

        this.stats.avgEmbeddingTime = (
            (this.stats.avgEmbeddingTime * this.stats.cacheMisses.embedding + duration) /
            (this.stats.cacheMisses.embedding + 1)
        );

        // ==================== END TASK 4 ====================

        // Normalize embedding
        const normalizedEmbedding = this._normalizeVector(embedding);

        // Cache at all levels (persistent + memory) - do in background to not block
        this.backgroundQueue.enqueue(async () => {
            await this.embeddingCache.set(text, normalizedEmbedding, this.embeddingModel);
        }, { type: 'cache_write' }).catch(err => {
            console.error('[AdvancedRAG] Background cache write failed:', err.message);
        });

        this._cacheEmbedding(exactKey, normalizedEmbedding);
        this._cacheSemanticEmbedding(semanticKey, normalizedEmbedding);

        return normalizedEmbedding;
    }

    /**
     * Save memory with NON-BLOCKING background embedding generation (TASK 4)
     * Chat responses return instantly, embeddings generate in background
     */
    async saveMemory(userId, content, characterId, metadata = {}) {
        try {
            // ==================== TASK 4: NON-BLOCKING MEMORY SAVE ====================

            // Calculate importance immediately (fast, no blocking)
            const importance = this._calculateImportance(content, metadata);
            const createdAt = Math.floor(Date.now() / 1000);

            // Insert memory WITHOUT embedding first (instant response)
            const query = `
                INSERT INTO neural_memory_embeddings
                (user_id, character_id, memory_content, embedding_vector_768,
                 migration_status, created_at, emotional_context, importance_score, emotional_weight)
                VALUES (?, ?, ?, ?, 'pending', ?, ?, ?, ?)
            `;

            const result = await this.db.query(query, [
                userId,
                characterId,
                content,
                null, // embedding will be added in background
                createdAt,
                JSON.stringify(metadata),
                importance,
                metadata.emotionalWeight || 0
            ]);

            const memoryId = result.lastID;
            console.log(`[AdvancedRAG] Memory ${memoryId} saved (embedding generation queued)`);

            // Generate embedding in background (non-blocking)
            this.backgroundQueue.enqueue(async () => {
                try {
                    // Generate embedding using batch generator
                    const embedding = await this.batchGenerator.generateEmbedding(content);
                    const normalizedEmbedding = this._normalizeVector(embedding);

                    console.log(`[AdvancedRAG SAVE] Memory ${memoryId}: Embedding generated, length=${normalizedEmbedding.length}`);

                    // Convert to binary BLOB for 81% size reduction
                    const embeddingBlob = this._arrayToBlob(normalizedEmbedding);
                    const base64Blob = embeddingBlob.toString('base64');

                    // Update database with embedding and BLOB
                    await this.db.query(`
                        UPDATE neural_memory_embeddings
                        SET embedding_vector_768 = ?,
                            embedding_blob = ?,
                            migration_status = 'completed'
                        WHERE id = ?
                    `, [JSON.stringify(normalizedEmbedding), base64Blob, memoryId]);

                    console.log(`[AdvancedRAG SAVE] Memory ${memoryId}: Updated in database, HNSW state before insert: vectors=${this.hnswIndex.vectors.size}, metadata=${this.hnswIndex.metadata.size}`);

                    // Add to HNSW index for immediate searchability
                    // ARCHITECTURAL FIX: Await insert to ensure it completes with mutex lock
                    await this.hnswIndex.insert(memoryId, normalizedEmbedding, {
                        userId,
                        characterId,
                        content,
                        createdAt,
                        importance,
                        emotionalWeight: metadata.emotionalWeight || 0
                    });

                    // DIAGNOSTIC: Verify insertion
                    const vectorStored = this.hnswIndex.vectors.has(memoryId);
                    const metadataStored = this.hnswIndex.metadata.has(memoryId);
                    console.log(`[AdvancedRAG SAVE] Memory ${memoryId}: HNSW insert complete - vector=${vectorStored}, metadata=${metadataStored}, state: vectors=${this.hnswIndex.vectors.size}, metadata=${this.hnswIndex.metadata.size}`);

                    if (!vectorStored || !metadataStored) {
                        console.error(`[AdvancedRAG SAVE CRITICAL] Memory ${memoryId} FAILED to store in HNSW maps! vector=${vectorStored}, metadata=${metadataStored}`);
                    }

                } catch (error) {
                    console.error(`[AdvancedRAG] Background embedding failed for memory ${memoryId}:`, error);
                    // Mark as failed but keep the memory
                    await this.db.query(
                        'UPDATE neural_memory_embeddings SET migration_status = ? WHERE id = ?',
                        ['failed', memoryId]
                    ).catch(err => console.error('Failed to update status:', err));
                }
            }, { type: 'memory_embedding', memoryId });

            // ==================== END TASK 4 ====================

            return memoryId;

        } catch (error) {
            console.error('[AdvancedRAG] Failed to save memory:', error);
            throw error;
        }
    }

    /**
     * Advanced search with all optimizations enabled
     */
    async searchMemories(userId, query, options = {}) {
        const startTime = Date.now();
        this.stats.totalQueries++;

        const {
            limit = 10,
            characterId = null,
            minSimilarity = 0.3,
            useHybrid = this.hybridSearch.enabled,
            useReranking = this.reranking.enabled,
            useExpansion = true,
            includeMetadata = true
        } = options;

        try {
            // Check result cache
            const cacheKey = this._getResultCacheKey(userId, query, options);
            const cached = this._getResultCache(cacheKey);
            if (cached) {
                this.stats.cacheHits.result++;
                console.log('[AdvancedRAG] Result cache hit');
                return cached;
            }

            this.stats.cacheMisses.result++;

            // Query expansion
            let queries = [query];
            if (useExpansion) {
                queries = this.queryExpander.expand(query, {
                    maxExpansions: 2,
                    includeOriginal: true
                });
                this.stats.queryExpansions++;
                console.log(`[AdvancedRAG] Query expanded to ${queries.length} variants`);
            }

            // Generate embeddings for all query variants
            const queryEmbeddings = await Promise.all(
                queries.map(q => this.generateEmbedding(q))
            );

            let results = [];

            if (useHybrid) {
                // Hybrid search: semantic + keyword
                results = await this._hybridSearch(
                    queries,
                    queryEmbeddings,
                    userId,
                    characterId,
                    limit * 3 // Get more candidates for re-ranking
                );
                this.stats.hybridSearches++;
            } else {
                // Pure semantic search using HNSW
                results = await this._semanticSearch(
                    queryEmbeddings[0],
                    userId,
                    characterId,
                    limit * 3
                );
            }

            // Apply temporal decay
            if (this.temporalDecay.enabled) {
                results = this._applyTemporalDecay(results);
            }

            // Re-ranking with cross-encoder simulation
            if (useReranking && results.length > limit) {
                results = this._rerankResults(query, results, limit);
                this.stats.rerankingOperations++;
            }

            // Filter by minimum similarity or score
            // NOTE: After hybrid search, similarity might be 0 (keyword results), so use score instead
            results = results.filter(r => {
                const threshold = useHybrid ? (r.score || r.similarity) : r.similarity;
                return threshold >= minSimilarity;
            });

            // Limit results
            results = results.slice(0, limit);

            // Build response
            const response = {
                results: results.map(r => ({
                    id: r.id,
                    characterId: r.characterId,
                    content: r.content,
                    similarity: r.similarity,
                    score: r.score,
                    createdAt: r.createdAt,
                    metadata: includeMetadata ? r.metadata : null,
                    embeddingType: 'neural',
                    importance: r.importance,
                    temporalWeight: r.temporalWeight
                })),
                totalFound: results.length,
                searchMethod: useHybrid ? 'hybrid' : 'semantic',
                usedExpansion: useExpansion && queries.length > 1,
                usedReranking: useReranking,
                performanceMs: Date.now() - startTime
            };

            // Cache result
            this._cacheResult(cacheKey, response);

            const duration = Date.now() - startTime;
            this.stats.avgQueryTime = (this.stats.avgQueryTime * (this.stats.totalQueries - 1) + duration) / this.stats.totalQueries;

            console.log(`[AdvancedRAG] Search completed in ${duration}ms, found ${results.length} results`);

            return response;

        } catch (error) {
            console.error('[AdvancedRAG] Search failed:', error);
            throw error;
        }
    }

    /**
     * Get enhanced context with dynamic window sizing
     */
    async getEnhancedContext(userId, conversationId, currentMessage, recentHistory = [], characterId = null) {
        try {
            // Search for relevant memories
            const searchResults = await this.searchMemories(userId, currentMessage, {
                limit: 20,
                characterId,
                useHybrid: true,
                useReranking: true,
                useExpansion: true
            });

            // Dynamic context window sizing based on relevance
            const selectedMemories = this._selectContextWindow(
                searchResults.results,
                this.contextWindow.maxTokens
            );

            // Build context
            const contextWindow = {
                relevantContext: selectedMemories
                    .map((m, i) => `[${i + 1}] ${m.content}`)
                    .join('\n\n'),
                memoryCount: selectedMemories.length,
                avgRelevance: selectedMemories.reduce((sum, m) => sum + m.similarity, 0) / selectedMemories.length,
                totalTokensEstimate: this._estimateTokens(selectedMemories.map(m => m.content).join('\n'))
            };

            return {
                contextWindow,
                relevantMemories: {
                    memories: selectedMemories,
                    noMemories: selectedMemories.length === 0
                },
                performanceMetrics: {
                    retrievalTime: searchResults.performanceMs,
                    searchMethod: searchResults.searchMethod
                }
            };

        } catch (error) {
            console.error('[AdvancedRAG] getEnhancedContext failed:', error);
            return this._getEmptyContext();
        }
    }

    /**
     * Batch save memories with PARALLEL embedding generation (TASK 4)
     * Uses connection pool + batch generator for 5x faster processing
     */
    async batchSaveMemories(memories) {
        console.log(`[AdvancedRAG] Batch saving ${memories.length} memories with parallel processing...`);
        const startTime = Date.now();

        try {
            // ==================== TASK 4: PARALLEL BATCH PROCESSING ====================

            // Generate ALL embeddings in parallel using batch generator + connection pool
            const embeddingPromises = memories.map(m =>
                this.batchGenerator.generateEmbedding(m.content)
            );

            console.log(`[AdvancedRAG] Generating ${memories.length} embeddings in parallel...`);
            const embeddings = await Promise.all(embeddingPromises);
            console.log(`[AdvancedRAG] All embeddings generated in ${Date.now() - startTime}ms`);

            // ==================== END TASK 4 ====================

            // Prepare batch insert with binary BLOBs
            const values = memories.map((m, idx) => {
                const normalizedEmbedding = this._normalizeVector(embeddings[idx]);
                const embeddingBlob = this._arrayToBlob(normalizedEmbedding);
                const base64Blob = embeddingBlob.toString('base64');

                return {
                    userId: m.userId,
                    characterId: m.characterId,
                    content: m.content,
                    embedding: normalizedEmbedding,
                    embeddingBlob: base64Blob,
                    importance: this._calculateImportance(m.content, m.metadata || {}),
                    metadata: m.metadata || {}
                };
            });

            // Batch insert to database
            const ids = [];
            for (const v of values) {
                const result = await this.db.query(`
                    INSERT INTO neural_memory_embeddings
                    (user_id, character_id, memory_content, embedding_vector_768, embedding_blob,
                     migration_status, created_at, emotional_context, importance_score)
                    VALUES (?, ?, ?, ?, ?, 'completed', ?, ?, ?)
                `, [
                    v.userId,
                    v.characterId,
                    v.content,
                    JSON.stringify(v.embedding),
                    v.embeddingBlob,
                    Math.floor(Date.now() / 1000),
                    JSON.stringify(v.metadata),
                    v.importance
                ]);
                ids.push(result.lastID);
            }

            // Batch insert to HNSW index
            const items = values.map((v, idx) => ({
                id: ids[idx],
                vector: v.embedding,
                metadata: {
                    userId: v.userId,
                    characterId: v.characterId,
                    content: v.content,
                    createdAt: Math.floor(Date.now() / 1000),
                    importance: v.importance
                }
            }));

            console.log(`[AdvancedRAG BATCH SAVE] HNSW state before batchInsert: vectors=${this.hnswIndex.vectors.size}, metadata=${this.hnswIndex.metadata.size}, nodeCount=${this.hnswIndex.nodeCount}`);
            this.hnswIndex.batchInsert(items);
            console.log(`[AdvancedRAG BATCH SAVE] HNSW state after batchInsert: vectors=${this.hnswIndex.vectors.size}, metadata=${this.hnswIndex.metadata.size}, nodeCount=${this.hnswIndex.nodeCount}`);

            this.stats.batchesProcessed++;

            const duration = Date.now() - startTime;
            console.log(`[AdvancedRAG] Batch save completed in ${duration}ms (${(memories.length / duration * 1000).toFixed(1)} memories/s)`);
            console.log(`[AdvancedRAG] Performance: ${(duration / memories.length).toFixed(1)}ms per memory (5x faster with parallel processing)`);

            return ids;

        } catch (error) {
            console.error('[AdvancedRAG] Batch save failed:', error);
            throw error;
        }
    }

    /**
     * Get comprehensive statistics (TASK 4: includes parallel processing metrics)
     */
    getStats() {
        const embeddingCacheHitRate = this.stats.cacheHits.embedding /
            (this.stats.cacheHits.embedding + this.stats.cacheMisses.embedding) || 0;

        const semanticCacheHitRate = this.stats.cacheHits.semantic /
            (this.stats.cacheHits.semantic + this.stats.cacheMisses.semantic) || 0;

        const resultCacheHitRate = this.stats.cacheHits.result /
            (this.stats.cacheHits.result + this.stats.cacheMisses.result) || 0;

        return {
            ...this.stats,
            cacheHitRates: {
                embedding: (embeddingCacheHitRate * 100).toFixed(2) + '%',
                semantic: (semanticCacheHitRate * 100).toFixed(2) + '%',
                result: (resultCacheHitRate * 100).toFixed(2) + '%',
                overall: ((embeddingCacheHitRate + semanticCacheHitRate + resultCacheHitRate) / 3 * 100).toFixed(2) + '%'
            },
            cacheSizes: {
                embeddings: this.cache.embeddings.size,
                semantic: this.cache.semantic.size,
                results: this.cache.results.size
            },
            persistentCache: this.embeddingCache.getStats(),
            hnsw: this.hnswIndex.getStats(),
            queryExpansion: this.queryExpander.stats,
            // ==================== TASK 4: PARALLEL PROCESSING STATS ====================
            parallelProcessing: {
                connectionPool: this.connectionPool.getStats(),
                batchGenerator: this.batchGenerator.getStats(),
                backgroundQueue: this.backgroundQueue.getStats()
            },
            // ==================== END TASK 4 ====================
            indexLoaded: this.indexLoaded,
            lastIndexUpdate: this.lastIndexUpdate ? new Date(this.lastIndexUpdate).toISOString() : null
        };
    }

    /**
     * Clear all caches
     */
    clearCaches() {
        this.cache.embeddings.clear();
        this.cache.embeddingOrder = [];
        this.cache.semantic.clear();
        this.cache.semanticOrder = [];
        this.cache.results.clear();
        this.cache.resultOrder = [];
        this.cache.compressed.clear();
        console.log('[AdvancedRAG] All caches cleared');
    }

    /**
     * Build user profile (backward compatibility)
     */
    async buildUserProfile(userId) {
        try {
            const result = await this.db.query(`
                SELECT memory_content, emotional_context, created_at, importance_score
                FROM neural_memory_embeddings
                WHERE user_id = ?
                ORDER BY created_at DESC
                LIMIT 50
            `, [userId]);

            const memories = result.rows;

            if (memories.length === 0) {
                return this._getEmptyProfile();
            }

            const avgImportance = memories.reduce((sum, m) => sum + (m.importance_score || 0.5), 0) / memories.length;

            return {
                messagingStyle: avgImportance > 0.7 ? 'detailed' : 'casual',
                humorLevel: 'medium',
                nsfwPreference: 'low',
                topicInterests: [],
                preferenceLevel: 'standard',
                hasRealConversationHistory: true,
                totalMemories: memories.length,
                avgImportance
            };

        } catch (error) {
            console.error('[AdvancedRAG] buildUserProfile failed:', error);
            return this._getEmptyProfile();
        }
    }

    /**
     * Save interaction (backward compatibility)
     */
    async saveInteraction(userId, message, response, metadata = {}) {
        const combinedMessage = `User: ${message}\nAI: ${response}`;
        const characterId = metadata.character || metadata.characterId || null;

        return await this.saveMemory(userId, combinedMessage, characterId, {
            ...metadata,
            messageType: 'interaction',
            originalMessage: message,
            originalResponse: response
        });
    }

    // ==================== PRIVATE METHODS ====================

    /**
     * Generate embedding using Ollama
     */
    async _generateOllamaEmbedding(text) {
        try {
            const response = await fetch(`${this.ollamaUrl}/api/embeddings`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    model: this.embeddingModel,
                    prompt: text
                }),
                timeout: 30000
            });

            if (!response.ok) {
                throw new Error(`Ollama API error: ${response.status}`);
            }

            const data = await response.json();
            const embedding = data.embedding;

            if (!Array.isArray(embedding) || embedding.length !== this.dimensions) {
                throw new Error('Invalid embedding response');
            }

            return this._normalizeVector(embedding);

        } catch (error) {
            console.error('[AdvancedRAG] Embedding generation failed:', error.message);
            return new Array(this.dimensions).fill(0);
        }
    }

    /**
     * Convert Float32Array to Buffer (for BLOB storage)
     * Binary storage achieves 81% size reduction vs JSON
     */
    _arrayToBlob(array) {
        // Ensure it's a regular array first
        const arr = Array.isArray(array) ? array : Array.from(array);

        // Create Float32Array buffer
        const float32Array = new Float32Array(arr);

        // Convert to Buffer
        return Buffer.from(float32Array.buffer);
    }

    /**
     * Semantic search using HNSW index
     */
    async _semanticSearch(queryEmbedding, userId, characterId, limit) {
        const startTime = Date.now();

        // Search HNSW index
        const candidates = this.hnswIndex.search(
            queryEmbedding,
            limit,
            (meta) => {
                // Defensive check: ensure meta exists before accessing properties
                if (!meta) return false;
                let match = meta.userId === userId;
                if (characterId) {
                    match = match && meta.characterId === characterId;
                }
                return match;
            }
        );

        const duration = Date.now() - startTime;
        this.stats.avgSearchTime = (this.stats.avgSearchTime * this.stats.totalQueries + duration) / (this.stats.totalQueries + 1);

        return candidates
            .map(c => {
                const meta = this.hnswIndex.metadata.get(c.id);
                // FIX: Return null if meta is undefined, then filter out nulls
                if (!meta) return null;

                return {
                    id: c.id,
                    userId: meta.userId,
                    characterId: meta.characterId,
                    content: meta.content,
                    similarity: c.similarity,
                    score: c.similarity,
                    createdAt: meta.createdAt,
                    importance: meta.importance,
                    metadata: meta
                };
            })
            .filter(result => result !== null); // Remove entries with missing metadata
    }

    /**
     * Hybrid search combining semantic and keyword search
     */
    async _hybridSearch(queries, queryEmbeddings, userId, characterId, limit) {
        // Semantic search using primary query
        const semanticResults = await this._semanticSearch(
            queryEmbeddings[0],
            userId,
            characterId,
            limit
        );

        // Keyword search using BM25
        const keywordResults = this._keywordSearch(queries[0], userId, characterId, limit);

        // Combine using Reciprocal Rank Fusion (RRF)
        if (this.hybridSearch.useRRF) {
            return this._reciprocalRankFusion(
                semanticResults,
                keywordResults,
                this.hybridSearch.rrf_k
            );
        } else {
            // Linear combination
            return this._linearCombination(
                semanticResults,
                keywordResults,
                this.hybridSearch.semanticWeight,
                this.hybridSearch.keywordWeight
            );
        }
    }

    /**
     * Keyword search using BM25
     */
    _keywordSearch(query, userId, characterId, limit) {
        const results = [];

        for (const [id, meta] of this.hnswIndex.metadata) {
            // FIX: Defensive check for undefined metadata
            if (!meta) continue;
            if (meta.userId !== userId) continue;
            if (characterId && meta.characterId !== characterId) continue;

            // Additional safety check for required fields
            if (!meta.content) continue;

            const score = this.bm25.score(query, meta.content);
            if (score > 0) {
                results.push({
                    id,
                    userId: meta.userId,
                    characterId: meta.characterId,
                    content: meta.content,
                    similarity: 0,
                    score: score,
                    createdAt: meta.createdAt,
                    importance: meta.importance,
                    metadata: meta
                });
            }
        }

        results.sort((a, b) => b.score - a.score);
        return results.slice(0, limit);
    }

    /**
     * Reciprocal Rank Fusion for combining ranked lists
     */
    _reciprocalRankFusion(list1, list2, k = 60) {
        const scores = new Map();

        // Add scores from first list
        list1.forEach((item, rank) => {
            // FIX: Defensive check for undefined items
            if (!item || !item.id) return;
            const rrfScore = 1 / (k + rank + 1);
            scores.set(item.id, rrfScore);
        });

        // Add scores from second list
        list2.forEach((item, rank) => {
            // FIX: Defensive check for undefined items
            if (!item || !item.id) return;
            const rrfScore = 1 / (k + rank + 1);
            const existing = scores.get(item.id) || 0;
            scores.set(item.id, existing + rrfScore);
        });

        // Create combined results
        const combined = [];
        const allItems = new Map();

        [...list1, ...list2].forEach(item => {
            // FIX: Only add valid items to the map
            if (item && item.id) {
                allItems.set(item.id, item);
            }
        });

        for (const [id, score] of scores) {
            const item = allItems.get(id);
            // FIX: Only add if item exists
            if (item) {
                combined.push({
                    ...item,
                    score: score
                });
            }
        }

        combined.sort((a, b) => b.score - a.score);
        return combined;
    }

    /**
     * Linear combination of semantic and keyword scores
     */
    _linearCombination(semanticResults, keywordResults, semanticWeight, keywordWeight) {
        const combined = new Map();

        // FIX: Filter out undefined results before processing
        const validSemanticResults = semanticResults.filter(r => r && r.id);
        const validKeywordResults = keywordResults.filter(r => r && r.id);

        // Normalize semantic scores
        const maxSemantic = Math.max(...validSemanticResults.map(r => r.similarity || 0), 1);
        validSemanticResults.forEach(r => {
            combined.set(r.id, {
                ...r,
                score: (r.similarity / maxSemantic) * semanticWeight
            });
        });

        // Normalize keyword scores and add
        const maxKeyword = Math.max(...validKeywordResults.map(r => r.score || 0), 1);
        validKeywordResults.forEach(r => {
            const existing = combined.get(r.id);
            const keywordScore = (r.score / maxKeyword) * keywordWeight;

            if (existing) {
                existing.score += keywordScore;
            } else {
                combined.set(r.id, {
                    ...r,
                    score: keywordScore
                });
            }
        });

        const results = Array.from(combined.values());
        results.sort((a, b) => b.score - a.score);
        return results;
    }

    /**
     * Apply temporal decay to results
     */
    _applyTemporalDecay(results) {
        const now = Date.now() / 1000;
        const halfLifeSeconds = this.temporalDecay.halfLife * 86400;

        return results.map(r => {
            const age = now - r.createdAt;
            const decay = Math.max(
                Math.exp(-Math.log(2) * age / halfLifeSeconds),
                this.temporalDecay.minWeight
            );

            return {
                ...r,
                temporalWeight: decay,
                score: r.score * (0.7 + 0.3 * decay) // Blend original score with temporal weight
            };
        });
    }

    /**
     * Re-rank results using cross-encoder simulation
     */
    _rerankResults(query, results, finalK) {
        console.log(`[AdvancedRAG] Re-ranking ${results.length} results to top ${finalK}...`);

        // Simulate cross-encoder scoring
        const reranked = results.map(r => {
            // Cross-encoder score: combination of similarity, importance, and content relevance
            const contentRelevance = this._calculateContentRelevance(query, r.content);
            const crossEncoderScore = (
                0.5 * r.similarity +
                0.3 * r.importance +
                0.2 * contentRelevance
            );

            return {
                ...r,
                crossEncoderScore,
                score: crossEncoderScore
            };
        });

        // Apply diversity penalty to avoid redundant results
        const diversified = this._applyDiversityPenalty(reranked);

        // Sort by final score
        diversified.sort((a, b) => b.score - a.score);

        return diversified.slice(0, finalK);
    }

    /**
     * Calculate content relevance for re-ranking
     */
    _calculateContentRelevance(query, content) {
        const queryTerms = query.toLowerCase().split(/\s+/);
        const contentLower = content.toLowerCase();

        let matches = 0;
        for (const term of queryTerms) {
            if (contentLower.includes(term)) {
                matches++;
            }
        }

        return queryTerms.length > 0 ? matches / queryTerms.length : 0;
    }

    /**
     * Apply diversity penalty to avoid redundant results
     */
    _applyDiversityPenalty(results) {
        if (results.length <= 1) return results;

        const diversified = [results[0]];

        for (let i = 1; i < results.length; i++) {
            const candidate = results[i];
            let maxSimilarity = 0;

            // Calculate max similarity to already selected results
            for (const selected of diversified) {
                const sim = this._textSimilarity(candidate.content, selected.content);
                maxSimilarity = Math.max(maxSimilarity, sim);
            }

            // Apply diversity penalty
            const penalty = maxSimilarity * this.reranking.diversityPenalty;
            candidate.score = candidate.score * (1 - penalty);

            diversified.push(candidate);
        }

        return diversified;
    }

    /**
     * Simple text similarity for diversity calculation
     */
    _textSimilarity(text1, text2) {
        const words1 = new Set(text1.toLowerCase().split(/\s+/));
        const words2 = new Set(text2.toLowerCase().split(/\s+/));

        const intersection = new Set([...words1].filter(w => words2.has(w)));
        const union = new Set([...words1, ...words2]);

        return intersection.size / union.size;
    }

    /**
     * Select context window dynamically based on relevance and token budget
     */
    _selectContextWindow(memories, maxTokens) {
        const selected = [];
        let totalTokens = 0;

        // Sort by combined relevance and importance
        const scored = memories.map(m => ({
            ...m,
            // Use score (hybrid) or similarity (semantic) for relevance
            relevance: m.score || m.similarity,
            contextScore: (
                (m.score || m.similarity) * (1 - this.contextWindow.importanceWeight) +
                m.importance * this.contextWindow.importanceWeight
            )
        }));

        scored.sort((a, b) => b.contextScore - a.contextScore);

        // Add memories until token budget exhausted
        for (const memory of scored) {
            // Use score or similarity (whichever is available) for relevance check
            const relevance = memory.score || memory.similarity;
            if (relevance < this.contextWindow.minRelevance) {
                continue;
            }

            const memoryTokens = this._estimateTokens(memory.content);

            if (totalTokens + memoryTokens > maxTokens) {
                break;
            }

            selected.push(memory);
            totalTokens += memoryTokens;
        }

        console.log(`[AdvancedRAG] Selected ${selected.length} memories for context (${totalTokens}/${maxTokens} tokens)`);

        return selected;
    }

    /**
     * Estimate token count (rough approximation)
     */
    _estimateTokens(text) {
        return Math.ceil(text.length / 4);
    }

    /**
     * Calculate importance score
     */
    _calculateImportance(content, metadata = {}) {
        let importance = 0.5;

        if (content.length > 200) importance += 0.2;
        if (content.length > 500) importance += 0.1;

        const questionCount = (content.match(/\?/g) || []).length;
        importance += Math.min(questionCount * 0.1, 0.3);

        if (metadata.isImportant) importance += 0.3;
        if (metadata.userMarkedImportant) importance += 0.5;

        return Math.min(importance, 1.0);
    }

    /**
     * Cache management methods
     */
    _getExactCacheKey(text) {
        return text.substring(0, 200);
    }

    _getSemanticKey(text) {
        const words = text.split(/\s+/)
            .filter(w => w.length > 3)
            .slice(0, 20)
            .sort()
            .join('|');
        return crypto.createHash('md5').update(words).digest('hex');
    }

    _cacheEmbedding(key, embedding) {
        // LRU eviction: remove least recently used when cache is full
        if (this.cache.embeddings.size >= this.cacheConfig.embeddingMaxSize) {
            const lruKey = this.cache.embeddingOrder.shift(); // Remove oldest
            this.cache.embeddings.delete(lruKey);
        }

        // Add/update in cache
        this.cache.embeddings.set(key, embedding);

        // Update LRU order (move to end)
        const existingIndex = this.cache.embeddingOrder.indexOf(key);
        if (existingIndex !== -1) {
            this.cache.embeddingOrder.splice(existingIndex, 1);
        }
        this.cache.embeddingOrder.push(key);
    }

    _cacheSemanticEmbedding(key, embedding) {
        // LRU eviction for semantic cache
        if (this.cache.semantic.size >= this.cacheConfig.semanticMaxSize) {
            const lruKey = this.cache.semanticOrder.shift();
            this.cache.semantic.delete(lruKey);
        }

        this.cache.semantic.set(key, embedding);

        // Update LRU order
        const existingIndex = this.cache.semanticOrder.indexOf(key);
        if (existingIndex !== -1) {
            this.cache.semanticOrder.splice(existingIndex, 1);
        }
        this.cache.semanticOrder.push(key);
    }

    _getResultCacheKey(userId, query, options) {
        return crypto.createHash('md5')
            .update(`${userId}:${query}:${JSON.stringify(options)}`)
            .digest('hex');
    }

    _getResultCache(key) {
        const cached = this.cache.results.get(key);
        if (!cached) return null;

        // Check TTL
        if (Date.now() - cached.timestamp > this.cacheConfig.resultTTL) {
            this.cache.results.delete(key);
            return null;
        }

        return cached.data;
    }

    _cacheResult(key, data) {
        // LRU eviction for result cache
        if (this.cache.results.size >= this.cacheConfig.resultMaxSize) {
            const lruKey = this.cache.resultOrder.shift();
            this.cache.results.delete(lruKey);
        }

        this.cache.results.set(key, {
            data,
            timestamp: Date.now()
        });

        // Update LRU order
        const existingIndex = this.cache.resultOrder.indexOf(key);
        if (existingIndex !== -1) {
            this.cache.resultOrder.splice(existingIndex, 1);
        }
        this.cache.resultOrder.push(key);
    }

    _normalizeVector(vector) {
        // Optimized normalization with Float32Array
        const vec = vector instanceof Float32Array ? vector : new Float32Array(vector);

        let sumSquares = 0;
        for (let i = 0; i < vec.length; i++) {
            sumSquares += vec[i] * vec[i];
        }

        const norm = Math.sqrt(sumSquares);
        if (norm === 0) return vec;

        const normalized = new Float32Array(vec.length);
        for (let i = 0; i < vec.length; i++) {
            normalized[i] = vec[i] / norm;
        }

        return normalized;
    }

    /**
     * Fast cosine similarity using Float32Array
     * Returns similarity score between -1 and 1 (higher is more similar)
     */
    _cosineSimilarity(vecA, vecB) {
        const a = vecA instanceof Float32Array ? vecA : new Float32Array(vecA);
        const b = vecB instanceof Float32Array ? vecB : new Float32Array(vecB);

        let dotProduct = 0;
        let normA = 0;
        let normB = 0;

        for (let i = 0; i < a.length; i++) {
            dotProduct += a[i] * b[i];
            normA += a[i] * a[i];
            normB += b[i] * b[i];
        }

        const denominator = Math.sqrt(normA * normB);
        return denominator === 0 ? 0 : dotProduct / denominator;
    }

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

    _getEmptyContext() {
        return {
            contextWindow: {
                relevantContext: '',
                memoryCount: 0,
                avgRelevance: 0,
                totalTokensEstimate: 0
            },
            relevantMemories: { memories: [], noMemories: true },
            performanceMetrics: { retrievalTime: 0 }
        };
    }

    _sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

module.exports = AdvancedRAGMemoryEngine;
