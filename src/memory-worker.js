// Simple memory processing worker for Ultimate Memory Engine
const { parentPort, workerData } = require('worker_threads');

class MemoryWorker {
    constructor() {
        this.processingQueue = [];
        this.isProcessing = false;
    }

    async processJob(job) {
        try {
            switch (job.type) {
                case 'embedding_calculation':
                    return await this.calculateEmbedding(job.data);
                case 'memory_decay':
                    return await this.processMemoryDecay(job.data);
                case 'cluster_optimization':
                    return await this.optimizeCluster(job.data);
                default:
                    return { success: false, error: `Unknown job type: ${job.type}` };
            }
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    async calculateEmbedding(data) {
        // Simplified embedding calculation
        const words = data.text.toLowerCase().split(/\s+/);
        const embedding = new Array(100).fill(0);
        
        words.forEach(word => {
            const hash = require('crypto').createHash('md5').update(word).digest('hex');
            const index = parseInt(hash.substring(0, 2), 16) % 100;
            embedding[index] += 1;
        });
        
        // Normalize
        const magnitude = Math.sqrt(embedding.reduce((sum, val) => sum + val * val, 0));
        const normalized = magnitude > 0 ? embedding.map(val => val / magnitude) : embedding;
        
        return { success: true, embedding: normalized };
    }

    async processMemoryDecay(data) {
        try {
            // Validate input data to prevent calculation errors
            if (!data || typeof data.created !== 'number' || data.created < 0) {
                return { success: false, error: 'Invalid creation timestamp' };
            }
            
            // Calculate age with overflow protection
            const now = Date.now();
            const age = now - data.created;
            
            // Validate age is reasonable (not negative or excessively large)
            if (age < 0) {
                console.warn('⚠️ Memory has future creation date, setting age to 0');
                return { success: true, decayFactor: 1.0 };
            }
            
            // Prevent overflow for very old memories (max 10 years)
            const maxAge = 10 * 365 * 24 * 60 * 60 * 1000; // 10 years in milliseconds
            const clampedAge = Math.min(age, maxAge);
            
            // Calculate decay with numerical stability
            const halfLifeMs = 30 * 24 * 60 * 60 * 1000; // 30-day half-life
            const exponent = clampedAge / halfLifeMs;
            
            // Prevent underflow by setting minimum decay factor
            const minDecayFactor = Number.MIN_VALUE * 1000; // Tiny but non-zero
            const decayFactor = Math.max(minDecayFactor, Math.pow(0.5, exponent));
            
            // Validate result is a valid number
            if (!isFinite(decayFactor) || isNaN(decayFactor)) {
                console.error(`ERROR Invalid decay calculation for age ${age}ms`);
                return { success: false, error: 'Decay calculation overflow' };
            }
            
            return { 
                success: true, 
                decayFactor,
                age: clampedAge,
                exponent: Math.round(exponent * 1000) / 1000 // Round for logging
            };
            
        } catch (error) {
            console.error('Memory decay processing error:', error);
            return { success: false, error: error.message };
        }
    }

    async optimizeCluster(data) {
        // Simplified cluster optimization with proper memory management
        try {
            // Validate input data to prevent memory issues
            if (!data || typeof data !== 'object') {
                return { success: false, error: 'Invalid cluster data provided' };
            }
            
            // Create a copy of data to avoid modifying original (prevent memory references)
            const clusterData = JSON.parse(JSON.stringify(data));
            
            // Perform optimization with memory bounds checking
            if (clusterData.vectors && Array.isArray(clusterData.vectors)) {
                // Limit processing to prevent memory exhaustion
                const maxVectors = 1000;
                if (clusterData.vectors.length > maxVectors) {
                    console.warn(`⚠️ Cluster optimization: truncating ${clusterData.vectors.length} vectors to ${maxVectors}`);
                    clusterData.vectors = clusterData.vectors.slice(0, maxVectors);
                }
                
                // Clear references to large objects after processing
                clusterData.vectors = null;
            }
            
            // Force garbage collection hint for large operations
            if (global.gc && data.size && data.size > 1000000) { // 1MB threshold
                global.gc();
            }
            
            return { success: true, optimized: true, processedSize: data.size || 0 };
        } catch (error) {
            console.error('Cluster optimization error:', error);
            return { success: false, error: error.message };
        }
    }
}

// Worker message handling with validation (Bug #027)
if (parentPort) {
    const worker = new MemoryWorker();
    
    parentPort.on('message', async (message) => {
        try {
            // Validate message format
            const validation = validateWorkerMessage(message);
            if (!validation.valid) {
                parentPort.postMessage({
                    error: validation.error,
                    messageId: message?.id || 'unknown',
                    type: 'validation_error'
                });
                return;
            }
            
            const job = validation.job;
            const result = await worker.processJob(job);
            
            // Ensure result has required fields
            parentPort.postMessage({
                jobId: job.id,
                success: result.success !== false,
                timestamp: Date.now(),
                ...result
            });
            
        } catch (error) {
            console.error('Worker message processing error:', error);
            parentPort.postMessage({
                jobId: message?.id || 'unknown',
                success: false,
                error: error.message,
                type: 'processing_error',
                timestamp: Date.now()
            });
        }
    });
    
    // Send ready signal with enhanced information
    parentPort.postMessage({ 
        type: 'ready', 
        workerId: workerData?.id || `worker-${process.pid}`,
        timestamp: Date.now(),
        capabilities: ['embedding_calculation', 'memory_decay', 'cluster_optimization']
    });
}

// Message validation function (Bug #027)
function validateWorkerMessage(message) {
    if (!message || typeof message !== 'object') {
        return { valid: false, error: 'Message must be an object' };
    }
    
    if (!message.id) {
        return { valid: false, error: 'Message must have an id field' };
    }
    
    if (typeof message.id !== 'string' && typeof message.id !== 'number') {
        return { valid: false, error: 'Message id must be string or number' };
    }
    
    if (!message.type) {
        return { valid: false, error: 'Message must have a type field' };
    }
    
    const validTypes = ['embedding_calculation', 'memory_decay', 'cluster_optimization'];
    if (!validTypes.includes(message.type)) {
        return { 
            valid: false, 
            error: `Invalid message type: ${message.type}. Valid types: ${validTypes.join(', ')}`
        };
    }
    
    if (!message.data) {
        return { valid: false, error: 'Message must have a data field' };
    }
    
    if (typeof message.data !== 'object') {
        return { valid: false, error: 'Message data must be an object' };
    }
    
    // Type-specific validation
    switch (message.type) {
        case 'embedding_calculation':
            if (!message.data.text || typeof message.data.text !== 'string') {
                return { valid: false, error: 'Embedding calculation requires text field' };
            }
            if (message.data.text.length > 100000) {
                return { valid: false, error: 'Text too long for embedding calculation (max 100k chars)' };
            }
            break;
            
        case 'memory_decay':
            if (typeof message.data.created !== 'number' || message.data.created < 0) {
                return { valid: false, error: 'Memory decay requires valid created timestamp' };
            }
            break;
            
        case 'cluster_optimization':
            if (message.data.vectors && !Array.isArray(message.data.vectors)) {
                return { valid: false, error: 'Cluster optimization vectors must be an array' };
            }
            break;
    }
    
    return { valid: true, job: message };
}

module.exports = MemoryWorker;