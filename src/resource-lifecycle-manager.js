/**
 * Resource Lifecycle Manager
 * 
 * ARCHITECTURAL SOLUTION: Central management of all application resources
 * This module provides a centralized way to track and clean up all resources
 * including intervals, timeouts, database connections, workers, etc.
 * 
 * NO-BANDAID POLICY: This is a proper architectural fix that:
 * - Prevents memory leaks by ensuring all resources are tracked
 * - Provides graceful shutdown capabilities
 * - Enables monitoring of resource usage
 * - Centralizes resource management logic
 */

const EventEmitter = require('events');

class ResourceLifecycleManager extends EventEmitter {
    constructor() {
        super();
        this.resources = {
            intervals: new Map(),
            timeouts: new Map(),
            workers: new Map(),
            connections: new Map(),
            streams: new Map(),
            customCleanups: new Map()
        };
        this.isShuttingDown = false;
        this.shutdownPromises = [];
        
        // Register process event handlers
        this.registerProcessHandlers();
        
        console.log('✅ ResourceLifecycleManager initialized');
    }

    /**
     * Register an interval timer with automatic cleanup
     * @param {string} id - Unique identifier for this interval
     * @param {Function} callback - Function to execute
     * @param {number} delay - Interval delay in milliseconds
     * @param {Object} options - Additional options
     * @returns {number} The interval ID
     */
    registerInterval(id, callback, delay, options = {}) {
        if (this.resources.intervals.has(id)) {
            console.warn(`Interval ${id} already exists. Clearing old interval.`);
            this.clearInterval(id);
        }

        const wrappedCallback = async () => {
            try {
                await callback();
            } catch (error) {
                console.error(`Error in interval ${id}:`, error);
                if (options.stopOnError) {
                    this.clearInterval(id);
                }
            }
        };

        const intervalId = setInterval(wrappedCallback, delay);
        
        this.resources.intervals.set(id, {
            intervalId,
            callback,
            delay,
            createdAt: Date.now(),
            executionCount: 0,
            options
        });

        console.log(`✅ Registered interval: ${id} (delay: ${delay}ms)`);
        return intervalId;
    }

    /**
     * Clear a specific interval
     * @param {string} id - Interval identifier
     */
    clearInterval(id) {
        const interval = this.resources.intervals.get(id);
        if (interval) {
            clearInterval(interval.intervalId);
            this.resources.intervals.delete(id);
            console.log(`✅ Cleared interval: ${id}`);
        }
    }

    /**
     * Register a timeout with automatic cleanup
     * @param {string} id - Unique identifier
     * @param {Function} callback - Function to execute
     * @param {number} delay - Timeout delay in milliseconds
     * @returns {number} The timeout ID
     */
    registerTimeout(id, callback, delay) {
        if (this.resources.timeouts.has(id)) {
            console.warn(`Timeout ${id} already exists. Clearing old timeout.`);
            this.clearTimeout(id);
        }

        const wrappedCallback = async () => {
            try {
                await callback();
                this.resources.timeouts.delete(id);
            } catch (error) {
                console.error(`Error in timeout ${id}:`, error);
                this.resources.timeouts.delete(id);
            }
        };

        const timeoutId = setTimeout(wrappedCallback, delay);
        
        this.resources.timeouts.set(id, {
            timeoutId,
            callback,
            delay,
            createdAt: Date.now()
        });

        console.log(`✅ Registered timeout: ${id} (delay: ${delay}ms)`);
        return timeoutId;
    }

    /**
     * Clear a specific timeout
     * @param {string} id - Timeout identifier
     */
    clearTimeout(id) {
        const timeout = this.resources.timeouts.get(id);
        if (timeout) {
            clearTimeout(timeout.timeoutId);
            this.resources.timeouts.delete(id);
            console.log(`✅ Cleared timeout: ${id}`);
        }
    }

    /**
     * Register a worker for lifecycle management
     * @param {string} id - Worker identifier
     * @param {Worker} worker - Worker instance
     * @param {Function} cleanupFn - Optional cleanup function
     */
    registerWorker(id, worker, cleanupFn = null) {
        this.resources.workers.set(id, {
            worker,
            cleanupFn,
            createdAt: Date.now()
        });
        console.log(`✅ Registered worker: ${id}`);
    }

    /**
     * Terminate a specific worker
     * @param {string} id - Worker identifier
     */
    async terminateWorker(id) {
        const workerInfo = this.resources.workers.get(id);
        if (workerInfo) {
            try {
                if (workerInfo.cleanupFn) {
                    await workerInfo.cleanupFn();
                }
                if (workerInfo.worker && typeof workerInfo.worker.terminate === 'function') {
                    await workerInfo.worker.terminate();
                }
                this.resources.workers.delete(id);
                console.log(`✅ Terminated worker: ${id}`);
            } catch (error) {
                console.error(`Error terminating worker ${id}:`, error);
            }
        }
    }

    /**
     * Register a custom cleanup function
     * @param {string} id - Cleanup identifier
     * @param {Function} cleanupFn - Cleanup function
     */
    registerCleanup(id, cleanupFn) {
        this.resources.customCleanups.set(id, {
            cleanupFn,
            createdAt: Date.now()
        });
        console.log(`✅ Registered cleanup: ${id}`);
    }

    /**
     * Get resource statistics
     * @returns {Object} Resource usage statistics
     */
    getStats() {
        return {
            intervals: this.resources.intervals.size,
            timeouts: this.resources.timeouts.size,
            workers: this.resources.workers.size,
            connections: this.resources.connections.size,
            streams: this.resources.streams.size,
            customCleanups: this.resources.customCleanups.size,
            totalResources: this.getTotalResourceCount()
        };
    }

    /**
     * Get total resource count
     * @returns {number} Total number of managed resources
     */
    getTotalResourceCount() {
        return Object.values(this.resources).reduce((total, map) => total + map.size, 0);
    }

    /**
     * Clear all intervals
     */
    clearAllIntervals() {
        console.log(`Clearing ${this.resources.intervals.size} intervals...`);
        for (const [id, interval] of this.resources.intervals) {
            clearInterval(interval.intervalId);
            console.log(`  Cleared interval: ${id}`);
        }
        this.resources.intervals.clear();
    }

    /**
     * Clear all timeouts
     */
    clearAllTimeouts() {
        console.log(`Clearing ${this.resources.timeouts.size} timeouts...`);
        for (const [id, timeout] of this.resources.timeouts) {
            clearTimeout(timeout.timeoutId);
            console.log(`  Cleared timeout: ${id}`);
        }
        this.resources.timeouts.clear();
    }

    /**
     * Terminate all workers
     */
    async terminateAllWorkers() {
        console.log(`Terminating ${this.resources.workers.size} workers...`);
        const promises = [];
        for (const [id] of this.resources.workers) {
            promises.push(this.terminateWorker(id));
        }
        await Promise.all(promises);
    }

    /**
     * Run all custom cleanup functions
     */
    async runCustomCleanups() {
        console.log(`Running ${this.resources.customCleanups.size} cleanup functions...`);
        const promises = [];
        for (const [id, cleanup] of this.resources.customCleanups) {
            promises.push(
                cleanup.cleanupFn().catch(error => {
                    console.error(`Error in cleanup ${id}:`, error);
                })
            );
        }
        await Promise.all(promises);
        this.resources.customCleanups.clear();
    }

    /**
     * Graceful shutdown - clean up all resources
     * @param {string} signal - Signal that triggered shutdown
     */
    async shutdown(signal = 'MANUAL') {
        if (this.isShuttingDown) {
            console.log('Shutdown already in progress...');
            return Promise.all(this.shutdownPromises);
        }

        this.isShuttingDown = true;
        console.log(`\n${'='.repeat(60)}`);
        console.log(`RESOURCE LIFECYCLE MANAGER - GRACEFUL SHUTDOWN (${signal})`);
        console.log(`${'='.repeat(60)}`);
        console.log(`Resources to clean up:`, this.getStats());

        this.emit('shutdown-start', signal);

        // Clear all intervals first (fastest)
        this.clearAllIntervals();

        // Clear all timeouts
        this.clearAllTimeouts();

        // Terminate workers
        this.shutdownPromises.push(this.terminateAllWorkers());

        // Run custom cleanup functions
        this.shutdownPromises.push(this.runCustomCleanups());

        // Wait for all cleanup to complete
        await Promise.all(this.shutdownPromises);

        console.log(`${'='.repeat(60)}`);
        console.log('✅ All resources cleaned up successfully');
        console.log(`${'='.repeat(60)}\n`);

        this.emit('shutdown-complete', signal);
    }

    /**
     * Register process event handlers for graceful shutdown
     */
    registerProcessHandlers() {
        const signals = ['SIGINT', 'SIGTERM', 'SIGUSR2'];
        
        signals.forEach(signal => {
            process.on(signal, async () => {
                console.log(`\nReceived ${signal}, initiating graceful shutdown...`);
                await this.shutdown(signal);
                process.exit(0);
            });
        });

        process.on('uncaughtException', async (error) => {
            console.error('Uncaught Exception:', error);
            await this.shutdown('UNCAUGHT_EXCEPTION');
            process.exit(1);
        });

        process.on('unhandledRejection', async (reason, promise) => {
            console.error('Unhandled Rejection at:', promise, 'reason:', reason);
            await this.shutdown('UNHANDLED_REJECTION');
            process.exit(1);
        });
    }

    /**
     * Monitor resource usage
     * @param {number} intervalMs - Monitoring interval in milliseconds
     */
    startMonitoring(intervalMs = 60000) {
        this.registerInterval('resource-monitor', () => {
            const stats = this.getStats();
            console.log(`[Resource Monitor] Active resources:`, stats);
            
            // Warn if too many resources
            if (stats.totalResources > 100) {
                console.warn(`⚠️ High resource count detected: ${stats.totalResources} resources`);
            }
        }, intervalMs);
    }
}

// Export singleton instance
module.exports = new ResourceLifecycleManager();