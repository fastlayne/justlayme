// Performance Monitoring System for JustLayMe
// Comprehensive monitoring of database, memory, and AI system performance

const os = require('os');
const fs = require('fs').promises;
const path = require('path');
const EventEmitter = require('events');
const resourceLifecycleManager = require('./resource-lifecycle-manager');

class PerformanceMonitor extends EventEmitter {
    constructor(options = {}) {
        super();
        
        this.options = {
            sampleInterval: options.sampleInterval || 5000, // 5 seconds
            metricsRetention: options.metricsRetention || 24 * 60 * 60 * 1000, // 24 hours
            alertThresholds: options.alertThresholds || this.getDefaultThresholds(),
            enableFileLogging: options.enableFileLogging !== false,
            logPath: options.logPath || path.join(__dirname, '../logs/performance.log')
        };
        
        // Metrics storage
        this.metrics = {
            system: [],
            database: [],
            memory: [],
            ai: [],
            alerts: []
        };
        
        // Current state tracking
        this.currentState = {
            system: {},
            database: {},
            memory: {},
            ai: {},
            lastUpdate: null
        };
        
        // Performance baseline
        this.baseline = {
            established: false,
            system: null,
            database: null,
            memory: null
        };
        
        // Alert state
        this.activeAlerts = new Map();
        this.alertCooldowns = new Map();
        
        // External system references
        this.database = null;
        this.memoryEngine = null;
        this.memoryCache = null;
        
        console.log('ANALYZING Performance Monitor initialized');
        this.startMonitoring();
    }

    // Set external system references
    setDatabase(database) {
        this.database = database;
    }

    setMemoryEngine(memoryEngine) {
        this.memoryEngine = memoryEngine;
    }

    setMemoryCache(memoryCache) {
        this.memoryCache = memoryCache;
    }

    // Start monitoring
    startMonitoring() {
        // ARCHITECTURAL FIX: Register intervals with ResourceLifecycleManager
        // This ensures proper cleanup on shutdown and prevents memory leaks
        
        this.monitoringInterval = resourceLifecycleManager.registerInterval(
            'performance-monitor-metrics',
            async () => await this.collectMetrics(),
            this.options.sampleInterval,
            { stopOnError: false }
        );

        // Clean up old metrics periodically
        this.cleanupInterval = resourceLifecycleManager.registerInterval(
            'performance-monitor-cleanup',
            () => this.cleanupOldMetrics(),
            60 * 60 * 1000, // Every hour
            { stopOnError: false }
        );

        console.log('📈 Performance monitoring started');
    }

    // Collect all performance metrics
    async collectMetrics() {
        const timestamp = Date.now();
        
        try {
            // System metrics
            const systemMetrics = await this.collectSystemMetrics();
            this.metrics.system.push({ timestamp, ...systemMetrics });
            this.currentState.system = systemMetrics;
            
            // Database metrics
            if (this.database) {
                const dbMetrics = await this.collectDatabaseMetrics();
                this.metrics.database.push({ timestamp, ...dbMetrics });
                this.currentState.database = dbMetrics;
            }
            
            // Memory engine metrics
            if (this.memoryEngine) {
                const memoryMetrics = await this.collectMemoryEngineMetrics();
                this.metrics.memory.push({ timestamp, ...memoryMetrics });
                this.currentState.memory = memoryMetrics;
            }
            
            // Memory cache metrics
            if (this.memoryCache) {
                const cacheMetrics = this.collectMemoryCacheMetrics();
                this.currentState.memory = { ...this.currentState.memory, cache: cacheMetrics };
            }
            
            this.currentState.lastUpdate = timestamp;
            
            // Check for alerts
            await this.checkAlerts();
            
            // Establish baseline if not yet done
            if (!this.baseline.established) {
                this.establishBaseline();
            }
            
            // Log metrics if enabled
            if (this.options.enableFileLogging) {
                await this.logMetrics();
            }
            
            // Emit metrics event
            this.emit('metrics', this.currentState);
            
        } catch (error) {
            console.error('Error collecting metrics:', error);
        }
    }

    // Collect system performance metrics
    async collectSystemMetrics() {
        const loadAverage = os.loadavg();
        const totalMem = os.totalmem();
        const freeMem = os.freemem();
        const usedMem = totalMem - freeMem;
        
        // CPU usage (simplified)
        const cpuUsage = await this.getCPUUsage();
        
        // Disk usage
        const diskUsage = await this.getDiskUsage();
        
        return {
            cpu: {
                usage: cpuUsage,
                loadAverage: loadAverage[0],
                cores: os.cpus().length
            },
            memory: {
                total: totalMem,
                used: usedMem,
                free: freeMem,
                usage: (usedMem / totalMem) * 100
            },
            disk: diskUsage,
            uptime: os.uptime()
        };
    }

    // Get CPU usage percentage
    async getCPUUsage() {
        return new Promise((resolve) => {
            const startUsage = process.cpuUsage();
            const startTime = Date.now();
            
            setTimeout(() => {
                const endUsage = process.cpuUsage(startUsage);
                const endTime = Date.now();
                
                const userCPU = endUsage.user / 1000; // Convert to milliseconds
                const systemCPU = endUsage.system / 1000;
                const totalCPU = userCPU + systemCPU;
                const totalTime = endTime - startTime;
                
                const usage = (totalCPU / totalTime) * 100;
                resolve(Math.min(usage, 100)); // Cap at 100%
            }, 100);
        });
    }

    // Get disk usage
    async getDiskUsage() {
        try {
            const dbPath = path.join(__dirname, '../database');
            const stats = await fs.stat(dbPath);
            
            // Get database file size
            const dbFilePath = path.join(dbPath, 'justlayme.db');
            let dbSize = 0;
            try {
                const dbStats = await fs.stat(dbFilePath);
                dbSize = dbStats.size;
            } catch (e) {
                // Database file might not exist yet
            }
            
            return {
                databaseSize: dbSize,
                databasePath: dbPath,
                lastModified: stats.mtime
            };
        } catch (error) {
            return {
                databaseSize: 0,
                error: error.message
            };
        }
    }

    // Collect database performance metrics
    async collectDatabaseMetrics() {
        try {
            let dbStats = {};
            
            if (typeof this.database.getStats === 'function') {
                dbStats = this.database.getStats();
            }
            
            // Additional database health checks
            const healthCheck = await this.performDatabaseHealthCheck();
            
            return {
                stats: dbStats,
                health: healthCheck,
                connectionPoolSize: dbStats.activeConnections || 0,
                queryPerformance: {
                    averageTime: dbStats.averageQueryTime || 0,
                    successRate: parseFloat(dbStats.successRate) || 100,
                    totalQueries: dbStats.totalQueries || 0
                }
            };
        } catch (error) {
            return {
                error: error.message,
                healthy: false
            };
        }
    }

    // Database health check
    async performDatabaseHealthCheck() {
        try {
            const startTime = Date.now();
            await this.database.query('SELECT 1 as health_check');
            const responseTime = Date.now() - startTime;
            
            return {
                healthy: true,
                responseTime,
                timestamp: Date.now()
            };
        } catch (error) {
            return {
                healthy: false,
                error: error.message,
                timestamp: Date.now()
            };
        }
    }

    // Collect memory engine metrics
    async collectMemoryEngineMetrics() {
        try {
            // Profile cache size
            const profileCacheSize = this.memoryEngine.userProfiles?.size || 0;
            const contextWindowSize = this.memoryEngine.contextWindows?.size || 0;
            
            // Memory health check
            const healthCheck = await this.performMemoryEngineHealthCheck();
            
            return {
                profileCache: {
                    size: profileCacheSize,
                    maxSize: 1000 // Estimated max
                },
                contextWindows: {
                    size: contextWindowSize
                },
                health: healthCheck,
                initialized: this.memoryEngine.initialized || false
            };
        } catch (error) {
            return {
                error: error.message,
                healthy: false
            };
        }
    }

    // Memory engine health check
    async performMemoryEngineHealthCheck() {
        try {
            // Test basic functionality
            if (typeof this.memoryEngine.convertUserId === 'function') {
                const testUserId = this.memoryEngine.convertUserId(123);
                if (testUserId !== 123) {
                    throw new Error('User ID conversion failed');
                }
            }
            
            return {
                healthy: true,
                timestamp: Date.now()
            };
        } catch (error) {
            return {
                healthy: false,
                error: error.message,
                timestamp: Date.now()
            };
        }
    }

    // Collect memory cache metrics
    collectMemoryCacheMetrics() {
        if (!this.memoryCache || typeof this.memoryCache.getStats !== 'function') {
            return { available: false };
        }
        
        const stats = this.memoryCache.getStats();
        const health = this.memoryCache.isHealthy();
        
        return {
            available: true,
            ...stats,
            health
        };
    }

    // Check for performance alerts
    async checkAlerts() {
        const thresholds = this.options.alertThresholds;
        const alerts = [];
        
        // System alerts
        if (this.currentState.system.cpu?.usage > thresholds.cpu.critical) {
            alerts.push({
                type: 'system',
                level: 'critical',
                message: `High CPU usage: ${this.currentState.system.cpu.usage.toFixed(1)}%`,
                value: this.currentState.system.cpu.usage,
                threshold: thresholds.cpu.critical
            });
        } else if (this.currentState.system.cpu?.usage > thresholds.cpu.warning) {
            alerts.push({
                type: 'system',
                level: 'warning',
                message: `Elevated CPU usage: ${this.currentState.system.cpu.usage.toFixed(1)}%`,
                value: this.currentState.system.cpu.usage,
                threshold: thresholds.cpu.warning
            });
        }
        
        if (this.currentState.system.memory?.usage > thresholds.memory.critical) {
            alerts.push({
                type: 'system',
                level: 'critical',
                message: `High memory usage: ${this.currentState.system.memory.usage.toFixed(1)}%`,
                value: this.currentState.system.memory.usage,
                threshold: thresholds.memory.critical
            });
        }
        
        // Database alerts
        if (this.currentState.database.health && !this.currentState.database.health.healthy) {
            alerts.push({
                type: 'database',
                level: 'critical',
                message: 'Database health check failed',
                error: this.currentState.database.health.error
            });
        }
        
        if (this.currentState.database.queryPerformance?.responseTime > thresholds.database.responseTime) {
            alerts.push({
                type: 'database',
                level: 'warning',
                message: `Slow database response: ${this.currentState.database.queryPerformance.responseTime}ms`,
                value: this.currentState.database.queryPerformance.responseTime,
                threshold: thresholds.database.responseTime
            });
        }
        
        // Memory engine alerts
        if (this.currentState.memory.health && !this.currentState.memory.health.healthy) {
            alerts.push({
                type: 'memory_engine',
                level: 'warning',
                message: 'Memory engine health check failed',
                error: this.currentState.memory.health.error
            });
        }
        
        // Process new alerts
        for (const alert of alerts) {
            await this.processAlert(alert);
        }
    }

    // Process individual alert
    async processAlert(alert) {
        const alertKey = `${alert.type}:${alert.level}:${alert.message}`;
        const now = Date.now();
        
        // Check cooldown
        if (this.alertCooldowns.has(alertKey)) {
            const lastAlert = this.alertCooldowns.get(alertKey);
            if (now - lastAlert < 5 * 60 * 1000) { // 5 minute cooldown
                return;
            }
        }
        
        // Add timestamp and ID
        alert.id = crypto.randomUUID();
        alert.timestamp = now;
        
        // Store alert
        this.metrics.alerts.push(alert);
        this.activeAlerts.set(alertKey, alert);
        this.alertCooldowns.set(alertKey, now);
        
        // Emit alert event
        this.emit('alert', alert);
        
        // Log alert
        console.warn(`🚨 ALERT [${alert.level.toUpperCase()}] ${alert.type}: ${alert.message}`);
        
        // Auto-resolve certain alerts if conditions improve
        if (alert.level === 'warning') {
            setTimeout(() => {
                this.checkAlertResolution(alertKey, alert);
            }, 30 * 1000); // Check resolution after 30 seconds
        }
    }

    // Check if alert can be resolved
    checkAlertResolution(alertKey, originalAlert) {
        const thresholds = this.options.alertThresholds;
        let resolved = false;
        
        switch (originalAlert.type) {
            case 'system':
                if (originalAlert.message.includes('CPU') && 
                    this.currentState.system.cpu?.usage < thresholds.cpu.warning) {
                    resolved = true;
                }
                break;
            case 'database':
                if (originalAlert.message.includes('response') &&
                    this.currentState.database.queryPerformance?.responseTime < thresholds.database.responseTime) {
                    resolved = true;
                }
                break;
        }
        
        if (resolved) {
            this.activeAlerts.delete(alertKey);
            this.emit('alert_resolved', originalAlert);
            console.log(`SUCCESS Alert resolved: ${originalAlert.message}`);
        }
    }

    // Establish performance baseline
    establishBaseline() {
        if (this.metrics.system.length < 12) return; // Need at least 1 minute of data
        
        const recentSystem = this.metrics.system.slice(-12);
        const recentDatabase = this.metrics.database.slice(-12);
        const recentMemory = this.metrics.memory.slice(-12);
        
        this.baseline = {
            established: true,
            system: {
                cpu: this.calculateAverage(recentSystem, 'cpu.usage'),
                memory: this.calculateAverage(recentSystem, 'memory.usage'),
                disk: this.calculateAverage(recentSystem, 'disk.databaseSize')
            },
            database: {
                responseTime: this.calculateAverage(recentDatabase, 'health.responseTime'),
                successRate: this.calculateAverage(recentDatabase, 'queryPerformance.successRate')
            },
            memory: {
                profileCacheSize: this.calculateAverage(recentMemory, 'profileCache.size'),
                contextWindowSize: this.calculateAverage(recentMemory, 'contextWindows.size')
            },
            timestamp: Date.now()
        };
        
        console.log('ANALYZING Performance baseline established:', this.baseline);
    }

    // Calculate average of nested property
    calculateAverage(data, property) {
        const values = data
            .map(item => this.getNestedValue(item, property))
            .filter(val => val !== null && val !== undefined && !isNaN(val));
        
        return values.length > 0 ? values.reduce((a, b) => a + b, 0) / values.length : 0;
    }

    // Get nested object value by dot notation
    getNestedValue(obj, path) {
        return path.split('.').reduce((current, key) => {
            return current && current[key] !== undefined ? current[key] : null;
        }, obj);
    }

    // Clean up old metrics
    cleanupOldMetrics() {
        const cutoff = Date.now() - this.options.metricsRetention;
        
        ['system', 'database', 'memory', 'ai', 'alerts'].forEach(type => {
            const originalLength = this.metrics[type].length;
            this.metrics[type] = this.metrics[type].filter(metric => metric.timestamp > cutoff);
            
            if (originalLength > this.metrics[type].length) {
                console.log(`🧹 Cleaned ${originalLength - this.metrics[type].length} old ${type} metrics`);
            }
        });
    }

    // Log metrics to file
    async logMetrics() {
        try {
            const logEntry = {
                timestamp: new Date().toISOString(),
                metrics: this.currentState
            };
            
            const logLine = JSON.stringify(logEntry) + '\n';
            await fs.appendFile(this.options.logPath, logLine);
            
        } catch (error) {
            console.error('Failed to log metrics:', error);
        }
    }

    // Get performance summary
    getPerformanceSummary() {
        const summary = {
            timestamp: Date.now(),
            status: 'healthy',
            current: this.currentState,
            baseline: this.baseline,
            alerts: {
                active: this.activeAlerts.size,
                recent: this.metrics.alerts.filter(a => Date.now() - a.timestamp < 60 * 60 * 1000).length
            },
            metrics: {
                system: this.metrics.system.length,
                database: this.metrics.database.length,
                memory: this.metrics.memory.length
            }
        };
        
        // Determine overall status
        if (this.activeAlerts.size > 0) {
            const criticalAlerts = Array.from(this.activeAlerts.values()).filter(a => a.level === 'critical');
            summary.status = criticalAlerts.length > 0 ? 'critical' : 'warning';
        }
        
        return summary;
    }

    // Get detailed metrics for specific time range
    getMetricsRange(startTime, endTime, types = ['system', 'database', 'memory']) {
        const results = {};
        
        types.forEach(type => {
            results[type] = this.metrics[type].filter(metric => 
                metric.timestamp >= startTime && metric.timestamp <= endTime
            );
        });
        
        return results;
    }

    // Export metrics to file
    async exportMetrics(filePath, options = {}) {
        try {
            const exportData = {
                exported: new Date().toISOString(),
                options: this.options,
                baseline: this.baseline,
                metrics: options.includeAllMetrics ? this.metrics : this.getPerformanceSummary(),
                summary: this.getPerformanceSummary()
            };
            
            await fs.writeFile(filePath, JSON.stringify(exportData, null, 2));
            console.log(`ANALYZING Metrics exported to ${filePath}`);
            
        } catch (error) {
            console.error('Failed to export metrics:', error);
            throw error;
        }
    }

    // Default alert thresholds
    getDefaultThresholds() {
        return {
            cpu: {
                warning: 70,
                critical: 90
            },
            memory: {
                warning: 80,
                critical: 95
            },
            database: {
                responseTime: 1000, // 1 second
                errorRate: 5 // 5%
            },
            disk: {
                usage: 90 // 90%
            }
        };
    }

    // Stop monitoring
    stopMonitoring() {
        // ARCHITECTURAL FIX: Clear intervals via ResourceLifecycleManager
        // This ensures consistent cleanup across the application
        resourceLifecycleManager.clearInterval('performance-monitor-metrics');
        resourceLifecycleManager.clearInterval('performance-monitor-cleanup');
        
        console.log('📊 Performance monitoring stopped');
    }

    // Graceful shutdown
    async shutdown() {
        this.stopMonitoring();
        
        // Final metrics export if logging enabled
        if (this.options.enableFileLogging) {
            try {
                const finalExportPath = path.join(path.dirname(this.options.logPath), 'final-metrics.json');
                await this.exportMetrics(finalExportPath, { includeAllMetrics: true });
            } catch (error) {
                console.error('Failed to export final metrics:', error);
            }
        }
        
        console.log('✅ Performance Monitor shutdown complete');
    }
}

module.exports = PerformanceMonitor;