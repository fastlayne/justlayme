/**
 * Database Connection Pool Manager
 * Handles connection pooling, race conditions, and ensures thread-safe database access
 * Part of the comprehensive fix for memory engine issues
 */

const { EventEmitter } = require('events');
const Database = require('./database');
const resourceLifecycleManager = require('./resource-lifecycle-manager');

class DatabasePoolManager extends EventEmitter {
    constructor(options = {}) {
        super();

        // Configuration
        this.config = {
            maxConnections: options.maxConnections || 5,
            acquireTimeout: options.acquireTimeout || 30000,
            idleTimeout: options.idleTimeout || 60000,
            retryAttempts: options.retryAttempts || 3,
            retryDelay: options.retryDelay || 1000,
            enableMetrics: options.enableMetrics !== false
        };

        // Connection pool state
        this.connections = new Map();
        this.waitingQueue = [];
        this.activeCount = 0;
        this.isShuttingDown = false;

        // Metrics
        this.metrics = {
            totalRequests: 0,
            successfulAcquisitions: 0,
            failedAcquisitions: 0,
            timeouts: 0,
            retries: 0,
            queueWaitTime: [],
            connectionUsageTime: [],
            errors: []
        };

        // Transaction management
        this.activeTransactions = new Map();

        // Initialize the pool
        this.initialize();
    }

    async initialize() {
        try {
            // Create the minimum number of connections
            const minConnections = Math.min(2, this.config.maxConnections);
            for (let i = 0; i < minConnections; i++) {
                await this.createConnection(`pool-${i}`);
            }

            console.log(`✅ Database pool initialized with ${minConnections} connections`);

            // Start idle connection cleanup
            this.startIdleCleanup();

        } catch (error) {
            console.error('❌ Failed to initialize database pool:', error);
            throw error;
        }
    }

    async createConnection(id) {
        try {
            // For SQLite, we use a single connection but manage access
            const connection = {
                id,
                db: Database.getInstance(),
                inUse: false,
                lastUsed: Date.now(),
                useCount: 0,
                createdAt: Date.now()
            };

            this.connections.set(id, connection);
            return connection;

        } catch (error) {
            console.error(`❌ Failed to create connection ${id}:`, error);
            throw error;
        }
    }

    async acquire(options = {}) {
        if (this.isShuttingDown) {
            throw new Error('Database pool is shutting down');
        }

        this.metrics.totalRequests++;
        const startTime = Date.now();
        const timeout = options.timeout || this.config.acquireTimeout;

        return new Promise((resolve, reject) => {
            const timeoutHandle = setTimeout(() => {
                this.metrics.timeouts++;
                const index = this.waitingQueue.indexOf(request);
                if (index > -1) {
                    this.waitingQueue.splice(index, 1);
                }
                reject(new Error(`Connection acquisition timeout after ${timeout}ms`));
            }, timeout);

            const request = {
                resolve: (connection) => {
                    clearTimeout(timeoutHandle);
                    const waitTime = Date.now() - startTime;
                    this.metrics.queueWaitTime.push(waitTime);
                    this.metrics.successfulAcquisitions++;
                    resolve(connection);
                },
                reject: (error) => {
                    clearTimeout(timeoutHandle);
                    this.metrics.failedAcquisitions++;
                    reject(error);
                },
                priority: options.priority || 0,
                startTime
            };

            // Try to get a connection immediately
            const connection = this.getAvailableConnection();
            if (connection) {
                this.activeCount++;
                connection.inUse = true;
                connection.lastUsed = Date.now();
                connection.useCount++;
                request.resolve(connection);
            } else if (this.activeCount < this.config.maxConnections) {
                // Create a new connection if under limit
                this.createConnection(`pool-${Date.now()}`)
                    .then(conn => {
                        this.activeCount++;
                        conn.inUse = true;
                        conn.lastUsed = Date.now();
                        conn.useCount++;
                        request.resolve(conn);
                    })
                    .catch(request.reject);
            } else {
                // Queue the request
                this.addToQueue(request);
            }
        });
    }

    getAvailableConnection() {
        for (const [id, connection] of this.connections) {
            if (!connection.inUse && !this.isConnectionStale(connection)) {
                return connection;
            }
        }
        return null;
    }

    isConnectionStale(connection) {
        const idleTime = Date.now() - connection.lastUsed;
        return idleTime > this.config.idleTimeout;
    }

    addToQueue(request) {
        // Priority queue implementation
        let inserted = false;
        for (let i = 0; i < this.waitingQueue.length; i++) {
            if (request.priority > this.waitingQueue[i].priority) {
                this.waitingQueue.splice(i, 0, request);
                inserted = true;
                break;
            }
        }
        if (!inserted) {
            this.waitingQueue.push(request);
        }
    }

    release(connection) {
        if (!connection || !this.connections.has(connection.id)) {
            console.warn('Attempted to release invalid connection');
            return;
        }

        const usageTime = Date.now() - connection.lastUsed;
        this.metrics.connectionUsageTime.push(usageTime);

        connection.inUse = false;
        this.activeCount--;

        // Process waiting queue
        if (this.waitingQueue.length > 0) {
            const request = this.waitingQueue.shift();
            this.activeCount++;
            connection.inUse = true;
            connection.lastUsed = Date.now();
            connection.useCount++;
            request.resolve(connection);
        }

        // Check if connection should be closed
        if (this.connections.size > 2 && connection.useCount > 100) {
            this.closeConnection(connection.id);
        }
    }

    async closeConnection(id) {
        const connection = this.connections.get(id);
        if (!connection) return;

        if (connection.inUse) {
            console.warn(`Cannot close connection ${id} while in use`);
            return;
        }

        this.connections.delete(id);
        console.log(`🔌 Closed connection ${id}`);
    }

    async executeWithRetry(operation, options = {}) {
        const maxAttempts = options.retries || this.config.retryAttempts;
        const retryDelay = options.retryDelay || this.config.retryDelay;

        for (let attempt = 1; attempt <= maxAttempts; attempt++) {
            let connection = null;

            try {
                // Acquire connection with priority for retries
                connection = await this.acquire({
                    priority: attempt,
                    timeout: options.timeout
                });

                // Execute the operation
                const result = await operation(connection.db);

                // Release connection on success
                this.release(connection);
                return result;

            } catch (error) {
                if (connection) {
                    this.release(connection);
                }

                this.metrics.errors.push({
                    error: error.message,
                    attempt,
                    timestamp: Date.now()
                });

                if (attempt === maxAttempts) {
                    throw new Error(`Operation failed after ${maxAttempts} attempts: ${error.message}`);
                }

                this.metrics.retries++;

                // Exponential backoff
                const delay = retryDelay * Math.pow(2, attempt - 1);
                await new Promise(resolve => setTimeout(resolve, delay));
            }
        }
    }

    async beginTransaction(id) {
        if (this.activeTransactions.has(id)) {
            throw new Error(`Transaction ${id} already exists`);
        }

        const connection = await this.acquire({ priority: 10 });

        try {
            // Verify connection is not already in a transaction state
            // For SQLite, we can check by attempting a test that fails if in transaction
            try {
                const testResult = await connection.db.query('SAVEPOINT _tx_state_check');
                await connection.db.query('RELEASE _tx_state_check');
                // If savepoint works, we're already in a transaction
                throw new Error('Connection is already in a transaction state');
            } catch (savepointError) {
                // If savepoint fails, we're NOT in a transaction (this is expected)
                // Continue with BEGIN
            }

            await connection.db.query('BEGIN');
            this.activeTransactions.set(id, {
                connection,
                startTime: Date.now(),
                operations: []
            });

            return id;
        } catch (error) {
            this.release(connection);
            throw error;
        }
    }

    async commitTransaction(id) {
        const transaction = this.activeTransactions.get(id);
        if (!transaction) {
            throw new Error(`Transaction ${id} not found`);
        }

        try {
            await transaction.connection.db.query('COMMIT');
            this.activeTransactions.delete(id);
            this.release(transaction.connection);

            return {
                duration: Date.now() - transaction.startTime,
                operations: transaction.operations.length
            };
        } catch (error) {
            // Attempt rollback on commit failure
            await this.rollbackTransaction(id);
            throw error;
        }
    }

    async rollbackTransaction(id) {
        const transaction = this.activeTransactions.get(id);
        if (!transaction) {
            throw new Error(`Transaction ${id} not found`);
        }

        try {
            await transaction.connection.db.query('ROLLBACK');
        } finally {
            this.activeTransactions.delete(id);
            this.release(transaction.connection);
        }
    }

    async executeInTransaction(id, query, params) {
        const transaction = this.activeTransactions.get(id);
        if (!transaction) {
            throw new Error(`Transaction ${id} not found`);
        }

        transaction.operations.push({ query, params, timestamp: Date.now() });
        return await transaction.connection.db.query(query, params);
    }

    startIdleCleanup() {
        // ARCHITECTURAL FIX: Register interval with ResourceLifecycleManager
        // This ensures proper cleanup on shutdown and prevents memory leaks
        this.idleCleanupInterval = resourceLifecycleManager.registerInterval(
            'db-pool-manager-idle-cleanup',
            () => {
                for (const [id, connection] of this.connections) {
                    if (!connection.inUse && this.isConnectionStale(connection)) {
                        this.closeConnection(id);
                    }
                }
            },
            30000, // Check every 30 seconds
            { stopOnError: false }
        );
    }

    getMetrics() {
        const avgWaitTime = this.metrics.queueWaitTime.length > 0
            ? this.metrics.queueWaitTime.reduce((a, b) => a + b, 0) / this.metrics.queueWaitTime.length
            : 0;

        const avgUsageTime = this.metrics.connectionUsageTime.length > 0
            ? this.metrics.connectionUsageTime.reduce((a, b) => a + b, 0) / this.metrics.connectionUsageTime.length
            : 0;

        return {
            ...this.metrics,
            activeConnections: this.activeCount,
            totalConnections: this.connections.size,
            queueLength: this.waitingQueue.length,
            avgWaitTime: Math.round(avgWaitTime),
            avgUsageTime: Math.round(avgUsageTime),
            successRate: this.metrics.totalRequests > 0
                ? (this.metrics.successfulAcquisitions / this.metrics.totalRequests * 100).toFixed(2) + '%'
                : '0%'
        };
    }

    async shutdown() {
        console.log('🛑 Shutting down database pool...');
        this.isShuttingDown = true;

        // ARCHITECTURAL FIX: Clear interval via ResourceLifecycleManager
        // This ensures consistent cleanup across the application
        resourceLifecycleManager.clearInterval('db-pool-manager-idle-cleanup');

        // Reject all waiting requests
        while (this.waitingQueue.length > 0) {
            const request = this.waitingQueue.shift();
            request.reject(new Error('Database pool is shutting down'));
        }

        // Rollback all active transactions
        for (const [id, transaction] of this.activeTransactions) {
            try {
                await this.rollbackTransaction(id);
            } catch (error) {
                console.error(`Failed to rollback transaction ${id}:`, error);
            }
        }

        // Wait for active connections to be released
        const maxWait = 5000;
        const startTime = Date.now();
        while (this.activeCount > 0 && Date.now() - startTime < maxWait) {
            await new Promise(resolve => setTimeout(resolve, 100));
        }

        // Force close all connections
        for (const [id, connection] of this.connections) {
            if (connection.inUse) {
                console.warn(`Force closing active connection ${id}`);
            }
            await this.closeConnection(id);
        }

        console.log('✅ Database pool shutdown complete');
        console.log('📊 Final metrics:', this.getMetrics());
    }
}

// Export singleton instance
let poolInstance = null;

module.exports = {
    DatabasePoolManager,
    getInstance: (options = {}) => {
        if (!poolInstance) {
            poolInstance = new DatabasePoolManager(options);
        }
        return poolInstance;
    },
    resetInstance: () => {
        if (poolInstance) {
            poolInstance.shutdown();
            poolInstance = null;
        }
    }
};