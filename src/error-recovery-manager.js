/**
 * Comprehensive Error Recovery Manager
 * Handles all error scenarios with automatic recovery, retry logic, and fallbacks
 * Part of the comprehensive fix for memory engine issues
 */

const { EventEmitter } = require('events');
const fs = require('fs').promises;
const path = require('path');
const resourceLifecycleManager = require('./resource-lifecycle-manager');

class ErrorRecoveryManager extends EventEmitter {
    constructor(options = {}) {
        super();

        // Configuration
        this.config = {
            maxRetries: options.maxRetries || 3,
            retryDelay: options.retryDelay || 1000,
            backoffMultiplier: options.backoffMultiplier || 2,
            maxBackoff: options.maxBackoff || 30000,
            enableCircuitBreaker: options.enableCircuitBreaker !== false,
            circuitBreakerThreshold: options.circuitBreakerThreshold || 5,
            circuitBreakerTimeout: options.circuitBreakerTimeout || 60000,
            logToFile: options.logToFile !== false,
            errorLogPath: options.errorLogPath || path.join(__dirname, '../logs/error-recovery.log'),
            enableAutoRecovery: options.enableAutoRecovery !== false,
            healthCheckInterval: options.healthCheckInterval || 30000
        };

        // Error tracking
        this.errorHistory = [];
        this.errorPatterns = new Map();
        this.recoveryStrategies = new Map();
        this.circuitBreakers = new Map();

        // Metrics
        this.metrics = {
            totalErrors: 0,
            recoveredErrors: 0,
            unrecoverableErrors: 0,
            retriesAttempted: 0,
            circuitBreakersTripped: 0,
            autoRecoveries: 0
        };

        // Recovery state
        this.isRecovering = false;
        this.recoveryQueue = [];

        // Initialize recovery strategies
        this.initializeRecoveryStrategies();

        // Start health monitoring
        if (this.config.enableAutoRecovery) {
            this.startHealthMonitoring();
        }
    }

    initializeRecoveryStrategies() {
        // Database errors
        this.registerStrategy('SQLITE_BUSY', async (error, context) => {
            await this.delay(Math.random() * 1000); // Random backoff
            return { retry: true, delay: 1000 };
        });

        this.registerStrategy('SQLITE_LOCKED', async (error, context) => {
            // Force unlock if possible
            if (context.db) {
                try {
                    await context.db.query('PRAGMA wal_checkpoint(TRUNCATE)');
                } catch (e) {
                    console.warn('Failed to force unlock:', e);
                }
            }
            return { retry: true, delay: 2000 };
        });

        // Worker thread errors
        this.registerStrategy('WORKER_DIED', async (error, context) => {
            // Restart worker with clean state
            if (context.restartWorker) {
                await context.restartWorker();
                return { recovered: true };
            }
            return { retry: false, fallback: 'processInMainThread' };
        });

        this.registerStrategy('WORKER_TIMEOUT', async (error, context) => {
            // Kill hung worker and restart
            if (context.worker) {
                await context.worker.terminate();
                if (context.restartWorker) {
                    await context.restartWorker();
                    return { retry: true, delay: 500 };
                }
            }
            return { fallback: 'processInMainThread' };
        });

        // Memory errors
        this.registerStrategy('OUT_OF_MEMORY', async (error, context) => {
            // Clear caches and force garbage collection
            if (context.cache) {
                context.cache.clear();
            }
            if (global.gc) {
                global.gc();
            }
            // Reduce worker count
            if (context.reduceWorkers) {
                await context.reduceWorkers();
            }
            return { retry: true, delay: 5000 };
        });

        // Network errors
        this.registerStrategy('ECONNREFUSED', async (error, context) => {
            // Service might be starting up
            return { retry: true, delay: 3000, maxRetries: 5 };
        });

        this.registerStrategy('ETIMEDOUT', async (error, context) => {
            // Increase timeout for next attempt
            if (context.adjustTimeout) {
                context.adjustTimeout(context.timeout * 2);
            }
            return { retry: true, delay: 2000 };
        });

        // File system errors
        this.registerStrategy('ENOENT', async (error, context) => {
            // Create missing file/directory
            if (context.createIfMissing && error.path) {
                try {
                    const dir = path.dirname(error.path);
                    await fs.mkdir(dir, { recursive: true });
                    if (context.defaultContent) {
                        await fs.writeFile(error.path, context.defaultContent);
                    }
                    return { recovered: true };
                } catch (e) {
                    console.error('Failed to create missing file:', e);
                }
            }
            return { retry: false, error: 'File not found' };
        });

        this.registerStrategy('EACCES', async (error, context) => {
            // Permission error - can't auto-recover
            return { retry: false, error: 'Permission denied' };
        });

        // Generic fallback
        this.registerStrategy('UNKNOWN', async (error, context) => {
            // Log and retry with backoff
            await this.logError(error, context);
            return { retry: true, delay: 1000 };
        });
    }

    registerStrategy(errorType, handler) {
        this.recoveryStrategies.set(errorType, handler);
    }

    async handleError(error, context = {}) {
        this.metrics.totalErrors++;

        // Track error pattern
        const errorType = this.identifyErrorType(error);
        this.trackErrorPattern(errorType);

        // Check circuit breaker
        if (this.config.enableCircuitBreaker && this.isCircuitOpen(errorType)) {
            this.metrics.circuitBreakersTripped++;
            throw new Error(`Circuit breaker open for ${errorType}`);
        }

        // Log error
        await this.logError(error, context);

        // Add to history
        this.errorHistory.push({
            error: error.message,
            type: errorType,
            context,
            timestamp: Date.now()
        });

        // Trim history
        if (this.errorHistory.length > 1000) {
            this.errorHistory = this.errorHistory.slice(-500);
        }

        // Attempt recovery
        try {
            const result = await this.attemptRecovery(error, errorType, context);
            if (result.recovered) {
                this.metrics.recoveredErrors++;
                this.resetCircuitBreaker(errorType);
                return result.value;
            }
            throw error;
        } catch (recoveryError) {
            this.metrics.unrecoverableErrors++;
            this.tripCircuitBreaker(errorType);
            throw recoveryError;
        }
    }

    identifyErrorType(error) {
        const message = error.message || '';
        const code = error.code || '';

        // SQLite errors
        if (message.includes('SQLITE_BUSY') || code === 'SQLITE_BUSY') return 'SQLITE_BUSY';
        if (message.includes('SQLITE_LOCKED') || code === 'SQLITE_LOCKED') return 'SQLITE_LOCKED';

        // Worker errors
        if (message.includes('Worker died') || code === 'ERR_WORKER_OUT_OF_MEMORY') return 'WORKER_DIED';
        if (message.includes('Worker timeout')) return 'WORKER_TIMEOUT';

        // Memory errors
        if (code === 'ERR_WORKER_OUT_OF_MEMORY' || message.includes('out of memory')) return 'OUT_OF_MEMORY';

        // Network errors
        if (code === 'ECONNREFUSED') return 'ECONNREFUSED';
        if (code === 'ETIMEDOUT') return 'ETIMEDOUT';

        // File system errors
        if (code === 'ENOENT') return 'ENOENT';
        if (code === 'EACCES') return 'EACCES';

        return 'UNKNOWN';
    }

    async attemptRecovery(error, errorType, context) {
        const strategy = this.recoveryStrategies.get(errorType) || this.recoveryStrategies.get('UNKNOWN');

        for (let attempt = 1; attempt <= this.config.maxRetries; attempt++) {
            // Recheck circuit breaker state during retry loop
            if (this.config.enableCircuitBreaker && this.isCircuitOpen(errorType)) {
                console.log(`⚠️ Circuit breaker opened during retry for ${errorType}`);
                break;
            }

            this.metrics.retriesAttempted++;

            try {
                // Execute recovery strategy
                const result = await strategy(error, { ...context, attempt });

                if (result.recovered) {
                    console.log(`✅ Recovered from ${errorType} after ${attempt} attempts`);
                    return { recovered: true, value: result.value };
                }

                if (!result.retry) {
                    if (result.fallback && context[result.fallback]) {
                        // Use fallback method
                        const value = await context[result.fallback](error);
                        return { recovered: true, value };
                    }
                    break;
                }

                // Calculate delay with exponential backoff
                const delay = Math.min(
                    result.delay * Math.pow(this.config.backoffMultiplier, attempt - 1),
                    this.config.maxBackoff
                );

                await this.delay(delay);

            } catch (strategyError) {
                console.error(`Recovery strategy failed for ${errorType}:`, strategyError);

                if (attempt === this.config.maxRetries) {
                    throw strategyError;
                }
            }
        }

        throw error;
    }

    trackErrorPattern(errorType) {
        if (!this.errorPatterns.has(errorType)) {
            this.errorPatterns.set(errorType, {
                count: 0,
                firstSeen: Date.now(),
                lastSeen: Date.now(),
                recovered: 0,
                failed: 0
            });
        }

        const pattern = this.errorPatterns.get(errorType);
        pattern.count++;
        pattern.lastSeen = Date.now();
    }

    isCircuitOpen(errorType) {
        const breaker = this.circuitBreakers.get(errorType);
        if (!breaker) return false;

        if (breaker.state === 'open') {
            // Check if timeout has passed
            if (Date.now() - breaker.openedAt > this.config.circuitBreakerTimeout) {
                // Move to half-open state
                breaker.state = 'half-open';
                breaker.testRequests = 0;
                return false;
            }
            return true;
        }

        return false;
    }

    tripCircuitBreaker(errorType) {
        if (!this.config.enableCircuitBreaker) return;

        let breaker = this.circuitBreakers.get(errorType);
        if (!breaker) {
            breaker = {
                failures: 0,
                state: 'closed',
                openedAt: null,
                testRequests: 0
            };
            this.circuitBreakers.set(errorType, breaker);
        }

        breaker.failures++;

        if (breaker.failures >= this.config.circuitBreakerThreshold) {
            breaker.state = 'open';
            breaker.openedAt = Date.now();
            console.warn(`⚠️ Circuit breaker tripped for ${errorType}`);
            this.emit('circuitBreakerTripped', { errorType, breaker });
        }
    }

    resetCircuitBreaker(errorType) {
        const breaker = this.circuitBreakers.get(errorType);
        if (breaker) {
            breaker.failures = 0;
            breaker.state = 'closed';
            breaker.openedAt = null;
        }
    }

    async logError(error, context) {
        const logEntry = {
            timestamp: new Date().toISOString(),
            error: {
                message: error.message,
                stack: error.stack,
                code: error.code
            },
            context,
            metrics: this.metrics
        };

        // Console log
        console.error('❌ Error:', error.message);

        // File log
        if (this.config.logToFile) {
            try {
                const dir = path.dirname(this.config.errorLogPath);
                await fs.mkdir(dir, { recursive: true });

                const logLine = JSON.stringify(logEntry) + '\n';
                await fs.appendFile(this.config.errorLogPath, logLine);
            } catch (logError) {
                console.error('Failed to write error log:', logError);
            }
        }

        // Emit event for monitoring
        this.emit('error', logEntry);
    }

    startHealthMonitoring() {
        // ARCHITECTURAL FIX: Register interval with ResourceLifecycleManager
        // This ensures proper cleanup on shutdown and prevents memory leaks
        this.healthCheckInterval = resourceLifecycleManager.registerInterval(
            'error-recovery-health-check',
            async () => {
                try {
                    await this.performHealthCheck();
                } catch (error) {
                    console.error('Health check failed:', error);
                }
            },
            this.config.healthCheckInterval,
            { stopOnError: false }
        );
    }

    async performHealthCheck() {
        const unhealthyPatterns = [];

        for (const [errorType, pattern] of this.errorPatterns) {
            const durationMinutes = Math.max(1, (Date.now() - pattern.firstSeen) / 1000 / 60);
            const errorRate = pattern.count / durationMinutes; // errors per minute

            if (errorRate > 10) {
                unhealthyPatterns.push({
                    type: errorType,
                    rate: errorRate,
                    pattern
                });
            }
        }

        if (unhealthyPatterns.length > 0) {
            console.warn('⚠️ Unhealthy error patterns detected:', unhealthyPatterns);
            this.emit('unhealthy', unhealthyPatterns);

            // Attempt auto-recovery
            if (this.config.enableAutoRecovery) {
                await this.performAutoRecovery(unhealthyPatterns);
            }
        }
    }

    async performAutoRecovery(unhealthyPatterns) {
        this.metrics.autoRecoveries++;
        console.log('🔧 Attempting auto-recovery...');

        for (const { type } of unhealthyPatterns) {
            switch (type) {
                case 'OUT_OF_MEMORY':
                    // Force garbage collection
                    if (global.gc) {
                        global.gc();
                    }
                    // Clear caches
                    this.emit('clearCaches');
                    break;

                case 'SQLITE_BUSY':
                case 'SQLITE_LOCKED':
                    // Restart database connections
                    this.emit('restartDatabase');
                    break;

                case 'WORKER_DIED':
                case 'WORKER_TIMEOUT':
                    // Restart all workers
                    this.emit('restartWorkers');
                    break;
            }
        }
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    getMetrics() {
        const errorRates = {};
        for (const [type, pattern] of this.errorPatterns) {
            const duration = (Date.now() - pattern.firstSeen) / 1000 / 60; // minutes
            errorRates[type] = {
                total: pattern.count,
                ratePerMinute: pattern.count / duration,
                recoveryRate: (pattern.recovered + pattern.failed) > 0
                    ? (pattern.recovered / (pattern.recovered + pattern.failed) * 100)
                    : 0
            };
        }

        return {
            ...this.metrics,
            errorRates,
            circuitBreakers: Array.from(this.circuitBreakers.entries()).map(([type, breaker]) => ({
                type,
                state: breaker.state,
                failures: breaker.failures
            })),
            recentErrors: this.errorHistory.slice(-10)
        };
    }

    async shutdown() {
        console.log('🛑 Shutting down error recovery manager...');

        // ARCHITECTURAL FIX: Clear interval via ResourceLifecycleManager
        // This ensures consistent cleanup across the application
        resourceLifecycleManager.clearInterval('error-recovery-health-check');

        // Final log
        await this.logError(
            new Error('Shutdown'),
            { metrics: this.getMetrics(), reason: 'graceful_shutdown' }
        );

        console.log('✅ Error recovery manager shutdown complete');
    }
}

// Export singleton instance
let instance = null;

module.exports = {
    ErrorRecoveryManager,
    getInstance: (options = {}) => {
        if (!instance) {
            instance = new ErrorRecoveryManager(options);
        }
        return instance;
    },
    resetInstance: () => {
        if (instance) {
            instance.shutdown();
            instance = null;
        }
    }
};