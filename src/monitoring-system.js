/**
 * Comprehensive Monitoring and Metrics System
 * Real-time monitoring, alerting, and performance metrics for the memory engine
 * Part of the comprehensive fix for memory engine issues
 */

const { EventEmitter } = require('events');
const fs = require('fs').promises;
const path = require('path');
const os = require('os');
const resourceLifecycleManager = require('./resource-lifecycle-manager');

class MonitoringSystem extends EventEmitter {
    constructor(options = {}) {
        super();

        // Configuration
        this.config = {
            metricsInterval: options.metricsInterval || 10000, // 10 seconds
            alertThresholds: {
                memoryUsage: options.memoryThreshold || 0.85, // 85%
                cpuUsage: options.cpuThreshold || 0.80, // 80%
                errorRate: options.errorRateThreshold || 10, // errors per minute
                responseTime: options.responseTimeThreshold || 5000, // 5 seconds
                queueLength: options.queueLengthThreshold || 100,
                workerRestarts: options.workerRestartsThreshold || 5
            },
            retention: {
                metrics: options.metricsRetention || 24 * 60 * 60 * 1000, // 24 hours
                alerts: options.alertsRetention || 7 * 24 * 60 * 60 * 1000 // 7 days
            },
            exportPath: options.exportPath || path.join(__dirname, '../logs/metrics'),
            enableExport: options.enableExport !== false,
            enableAlerts: options.enableAlerts !== false
        };

        // Metrics storage
        this.metrics = {
            system: [],
            application: [],
            database: [],
            workers: [],
            memory: [],
            errors: []
        };

        // Alert history
        this.alerts = [];
        this.activeAlerts = new Set();

        // Performance tracking
        this.performanceMarks = new Map();
        this.performanceMeasures = [];

        // Component references
        this.components = new Map();

        // Start monitoring
        this.startMonitoring();
    }

    registerComponent(name, component) {
        this.components.set(name, component);
        console.log(`📊 Registered component for monitoring: ${name}`);
    }

    startMonitoring() {
        // ARCHITECTURAL FIX: Register interval with ResourceLifecycleManager
        // This ensures proper cleanup on shutdown and prevents memory leaks
        
        // System metrics collection
        this.metricsInterval = resourceLifecycleManager.registerInterval(
            'monitoring-system-metrics',
            () => this.collectMetrics(),
            this.config.metricsInterval,
            { stopOnError: false }
        );

        // CPU tracking
        this.lastCpuInfo = os.cpus();

        console.log('🔍 Monitoring system started');
    }

    async collectMetrics() {
        const timestamp = Date.now();

        try {
            // Collect all metrics
            const systemMetrics = this.collectSystemMetrics();
            const applicationMetrics = await this.collectApplicationMetrics();
            const databaseMetrics = await this.collectDatabaseMetrics();
            const workerMetrics = await this.collectWorkerMetrics();
            const memoryMetrics = this.collectMemoryMetrics();

            // Store metrics
            this.storeMetrics('system', systemMetrics, timestamp);
            this.storeMetrics('application', applicationMetrics, timestamp);
            this.storeMetrics('database', databaseMetrics, timestamp);
            this.storeMetrics('workers', workerMetrics, timestamp);
            this.storeMetrics('memory', memoryMetrics, timestamp);

            // Check for alerts
            if (this.config.enableAlerts) {
                this.checkAlerts({
                    system: systemMetrics,
                    application: applicationMetrics,
                    database: databaseMetrics,
                    workers: workerMetrics,
                    memory: memoryMetrics
                });
            }

            // Export if enabled
            if (this.config.enableExport) {
                await this.exportMetrics(timestamp);
            }

            // Emit metrics event
            this.emit('metrics', {
                timestamp,
                system: systemMetrics,
                application: applicationMetrics,
                database: databaseMetrics,
                workers: workerMetrics,
                memory: memoryMetrics
            });

        } catch (error) {
            console.error('Failed to collect metrics:', error);
            this.storeMetrics('errors', { error: error.message }, timestamp);
        }
    }

    collectSystemMetrics() {
        const cpus = os.cpus();
        const currentCpuInfo = cpus.map(cpu => cpu.times);

        // Calculate CPU usage
        let totalDiff = 0;
        let idleDiff = 0;

        currentCpuInfo.forEach((cpu, i) => {
            const lastCpu = this.lastCpuInfo[i].times;
            const total = Object.values(cpu).reduce((a, b) => a + b, 0);
            const lastTotal = Object.values(lastCpu).reduce((a, b) => a + b, 0);
            const idle = cpu.idle;
            const lastIdle = lastCpu.idle;

            totalDiff += total - lastTotal;
            idleDiff += idle - lastIdle;
        });

        // Prevent NaN/Infinity from division by zero and clamp between 0 and 1
        const cpuUsage = totalDiff > 0
            ? Math.max(0, Math.min(1, 1 - (idleDiff / totalDiff)))
            : 0;
        this.lastCpuInfo = cpus;

        const totalMem = os.totalmem();
        const freeMem = os.freemem();
        const memoryUsage = (totalMem - freeMem) / totalMem;

        return {
            cpuUsage: Math.round(cpuUsage * 100) / 100,
            cpuCount: cpus.length,
            memoryUsage: Math.round(memoryUsage * 100) / 100,
            totalMemory: totalMem,
            freeMemory: freeMem,
            loadAverage: os.loadavg(),
            uptime: os.uptime(),
            platform: os.platform(),
            hostname: os.hostname()
        };
    }

    async collectApplicationMetrics() {
        const metrics = {
            requestsPerSecond: 0,
            averageResponseTime: 0,
            activeRequests: 0,
            queueLength: 0,
            cacheHitRate: 0,
            errors: 0
        };

        // Collect from registered components
        const memoryEngine = this.components.get('memoryEngine');
        if (memoryEngine) {
            const engineMetrics = await memoryEngine.getMetrics();
            metrics.cacheHitRate = engineMetrics.cacheHitRate || 0;
            metrics.queueLength = engineMetrics.queueLength || 0;
        }

        const resourceManager = this.components.get('resourceManager');
        if (resourceManager) {
            const rmMetrics = resourceManager.getMetrics();
            metrics.activeRequests = rmMetrics.activeOperations || 0;
        }

        // Calculate response times
        if (this.performanceMeasures.length > 0) {
            const recentMeasures = this.performanceMeasures.filter(
                m => m.timestamp > Date.now() - 60000
            );
            if (recentMeasures.length > 0) {
                metrics.requestsPerSecond = recentMeasures.length / 60;
                metrics.averageResponseTime = recentMeasures.reduce(
                    (sum, m) => sum + m.duration, 0
                ) / recentMeasures.length;
            }
        }

        return metrics;
    }

    async collectDatabaseMetrics() {
        const metrics = {
            connectionPoolSize: 0,
            activeConnections: 0,
            queuedRequests: 0,
            averageQueryTime: 0,
            slowQueries: 0,
            failedQueries: 0
        };

        const dbPool = this.components.get('databasePool');
        if (dbPool) {
            const poolMetrics = dbPool.getMetrics();
            metrics.connectionPoolSize = poolMetrics.totalConnections || 0;
            metrics.activeConnections = poolMetrics.activeConnections || 0;
            metrics.queuedRequests = poolMetrics.queueLength || 0;
            metrics.averageQueryTime = poolMetrics.avgUsageTime || 0;
            metrics.failedQueries = poolMetrics.failedAcquisitions || 0;
        }

        return metrics;
    }

    async collectWorkerMetrics() {
        const metrics = {
            totalWorkers: 0,
            activeWorkers: 0,
            restartCount: 0,
            messageQueue: 0,
            averageProcessingTime: 0,
            errors: 0
        };

        const resourceManager = this.components.get('resourceManager');
        if (resourceManager) {
            const rmMetrics = resourceManager.getMetrics();
            metrics.totalWorkers = rmMetrics.workers?.total || 0;
            metrics.activeWorkers = rmMetrics.workers?.active || 0;
            metrics.restartCount = rmMetrics.workers?.restarts || 0;
        }

        return metrics;
    }

    collectMemoryMetrics() {
        const memUsage = process.memoryUsage();

        return {
            heapUsed: memUsage.heapUsed,
            heapTotal: memUsage.heapTotal,
            rss: memUsage.rss,
            external: memUsage.external,
            arrayBuffers: memUsage.arrayBuffers,
            heapUsagePercent: Math.round((memUsage.heapUsed / memUsage.heapTotal) * 100),
            gcStats: global.gc ? this.getGCStats() : null
        };
    }

    getGCStats() {
        // This would need v8 module for detailed GC stats
        // Placeholder for basic GC tracking
        return {
            collections: 0,
            pauseTime: 0
        };
    }

    storeMetrics(category, data, timestamp) {
        const entry = { timestamp, ...data };

        this.metrics[category].push(entry);

        // Trim old metrics
        const cutoff = Date.now() - this.config.retention.metrics;
        this.metrics[category] = this.metrics[category].filter(
            m => m.timestamp > cutoff
        );
    }

    checkAlerts(metrics) {
        const { alertThresholds } = this.config;

        // Memory usage alert
        if (metrics.system.memoryUsage > alertThresholds.memoryUsage) {
            this.triggerAlert('HIGH_MEMORY_USAGE', {
                current: metrics.system.memoryUsage,
                threshold: alertThresholds.memoryUsage,
                severity: 'warning'
            });
        }

        // CPU usage alert
        if (metrics.system.cpuUsage > alertThresholds.cpuUsage) {
            this.triggerAlert('HIGH_CPU_USAGE', {
                current: metrics.system.cpuUsage,
                threshold: alertThresholds.cpuUsage,
                severity: 'warning'
            });
        }

        // Response time alert
        if (metrics.application.averageResponseTime > alertThresholds.responseTime) {
            this.triggerAlert('SLOW_RESPONSE_TIME', {
                current: metrics.application.averageResponseTime,
                threshold: alertThresholds.responseTime,
                severity: 'warning'
            });
        }

        // Queue length alert
        if (metrics.application.queueLength > alertThresholds.queueLength) {
            this.triggerAlert('HIGH_QUEUE_LENGTH', {
                current: metrics.application.queueLength,
                threshold: alertThresholds.queueLength,
                severity: 'error'
            });
        }

        // Worker restarts alert
        if (metrics.workers.restartCount > alertThresholds.workerRestarts) {
            this.triggerAlert('EXCESSIVE_WORKER_RESTARTS', {
                current: metrics.workers.restartCount,
                threshold: alertThresholds.workerRestarts,
                severity: 'error'
            });
        }
    }

    triggerAlert(type, data) {
        const alertKey = `${type}_${JSON.stringify(data)}`;

        // Avoid duplicate alerts
        if (this.activeAlerts.has(alertKey)) {
            return;
        }

        const alert = {
            id: Date.now() + '_' + Math.random(),
            type,
            data,
            timestamp: Date.now(),
            resolved: false,
            autoResolveTimeout: null
        };

        this.alerts.push(alert);
        this.activeAlerts.add(alertKey);

        // Emit alert
        this.emit('alert', alert);

        console.warn(`⚠️ ALERT: ${type}`, data);

        // Auto-resolve after some time and store timeout handle for cleanup
        alert.autoResolveTimeout = setTimeout(() => {
            this.activeAlerts.delete(alertKey);
            alert.resolved = true;
            alert.autoResolveTimeout = null;
        }, 300000); // 5 minutes

        // Trim old alerts
        const cutoff = Date.now() - this.config.retention.alerts;
        this.alerts = this.alerts.filter(a => a.timestamp > cutoff);
    }

    // Performance tracking methods
    markStart(label) {
        this.performanceMarks.set(label, Date.now());
    }

    markEnd(label, metadata = {}) {
        const startTime = this.performanceMarks.get(label);
        if (!startTime) {
            console.warn(`No start mark found for ${label}`);
            return;
        }

        const duration = Date.now() - startTime;
        this.performanceMarks.delete(label);

        const measure = {
            label,
            duration,
            timestamp: Date.now(),
            ...metadata
        };

        this.performanceMeasures.push(measure);

        // Trim old measures
        this.performanceMeasures = this.performanceMeasures.filter(
            m => m.timestamp > Date.now() - 3600000
        );

        return duration;
    }

    async exportMetrics(timestamp) {
        try {
            const exportData = {
                timestamp,
                metrics: this.metrics,
                alerts: this.alerts.filter(a => !a.resolved),
                performance: {
                    measures: this.performanceMeasures.slice(-100)
                }
            };

            const dir = this.config.exportPath;
            await fs.mkdir(dir, { recursive: true });

            const filename = `metrics_${new Date(timestamp).toISOString().replace(/:/g, '-')}.json`;
            const filepath = path.join(dir, filename);

            await fs.writeFile(filepath, JSON.stringify(exportData, null, 2));

            // Clean old exports
            const files = await fs.readdir(dir);
            const cutoff = Date.now() - this.config.retention.metrics;

            for (const file of files) {
                if (file.startsWith('metrics_')) {
                    const filePath = path.join(dir, file);
                    try {
                        const stats = await fs.stat(filePath);
                        if (stats.mtimeMs < cutoff) {
                            await fs.unlink(filePath);
                        }
                    } catch (error) {
                        console.error(`Failed to clean up old export ${file}:`, error);
                    }
                }
            }

        } catch (error) {
            console.error('Failed to export metrics:', error);
        }
    }

    getSummary() {
        const recentSystem = this.metrics.system.slice(-6); // Last minute
        const recentApp = this.metrics.application.slice(-6);
        const recentWorkers = this.metrics.workers.slice(-6);

        return {
            system: {
                avgCpuUsage: this.average(recentSystem, 'cpuUsage'),
                avgMemoryUsage: this.average(recentSystem, 'memoryUsage'),
                uptime: recentSystem[recentSystem.length - 1]?.uptime || 0
            },
            application: {
                avgResponseTime: this.average(recentApp, 'averageResponseTime'),
                totalRequests: this.sum(recentApp, 'requestsPerSecond') * 60,
                errorRate: this.average(recentApp, 'errors')
            },
            workers: {
                totalRestarts: this.sum(recentWorkers, 'restartCount'),
                avgProcessingTime: this.average(recentWorkers, 'averageProcessingTime')
            },
            alerts: {
                active: this.alerts.filter(a => !a.resolved).length,
                total: this.alerts.length
            }
        };
    }

    average(array, key) {
        if (array.length === 0) return 0;
        const sum = array.reduce((acc, item) => acc + (item[key] || 0), 0);
        return Math.round((sum / array.length) * 100) / 100;
    }

    sum(array, key) {
        return array.reduce((acc, item) => acc + (item[key] || 0), 0);
    }

    async generateReport() {
        const summary = this.getSummary();
        const timestamp = new Date().toISOString();

        const report = `
=================================================================
         JUSTLAYME MEMORY ENGINE MONITORING REPORT
=================================================================
Generated: ${timestamp}

SYSTEM METRICS
--------------
• CPU Usage: ${summary.system.avgCpuUsage}%
• Memory Usage: ${summary.system.avgMemoryUsage}%
• Uptime: ${Math.floor(summary.system.uptime / 3600)} hours

APPLICATION METRICS
-------------------
• Average Response Time: ${summary.application.avgResponseTime}ms
• Total Requests (last hour): ${summary.application.totalRequests}
• Error Rate: ${summary.application.errorRate}/min

WORKER METRICS
--------------
• Total Restarts: ${summary.workers.totalRestarts}
• Avg Processing Time: ${summary.workers.avgProcessingTime}ms

ALERTS
------
• Active Alerts: ${summary.alerts.active}
• Total Alerts (7 days): ${summary.alerts.total}

TOP PERFORMANCE ISSUES
----------------------
${this.getTopIssues().join('\n')}

RECOMMENDATIONS
---------------
${this.getRecommendations(summary).join('\n')}
=================================================================
        `;

        return report;
    }

    getTopIssues() {
        const issues = [];

        // Analyze recent alerts
        const recentAlerts = this.alerts.filter(
            a => a.timestamp > Date.now() - 3600000 && !a.resolved
        );

        const alertCounts = {};
        recentAlerts.forEach(alert => {
            alertCounts[alert.type] = (alertCounts[alert.type] || 0) + 1;
        });

        Object.entries(alertCounts)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 5)
            .forEach(([type, count]) => {
                issues.push(`• ${type}: ${count} occurrences`);
            });

        return issues.length > 0 ? issues : ['• No significant issues detected'];
    }

    getRecommendations(summary) {
        const recommendations = [];

        if (summary.system.avgMemoryUsage > 80) {
            recommendations.push('• Consider increasing memory allocation or optimizing memory usage');
        }

        if (summary.system.avgCpuUsage > 70) {
            recommendations.push('• CPU usage is high - consider scaling horizontally or optimizing algorithms');
        }

        if (summary.application.avgResponseTime > 1000) {
            recommendations.push('• Response times are slow - review database queries and caching strategy');
        }

        if (summary.workers.totalRestarts > 10) {
            recommendations.push('• Worker instability detected - investigate memory leaks or errors');
        }

        return recommendations.length > 0
            ? recommendations
            : ['• System is operating within normal parameters'];
    }

    async shutdown() {
        console.log('🛑 Shutting down monitoring system...');

        // ARCHITECTURAL FIX: Clear interval via ResourceLifecycleManager
        // This ensures consistent cleanup across the application
        resourceLifecycleManager.clearInterval('monitoring-system-metrics');

        // Clear all alert auto-resolve timeouts to prevent resource leaks
        for (const alert of this.alerts) {
            if (alert.autoResolveTimeout) {
                clearTimeout(alert.autoResolveTimeout);
                alert.autoResolveTimeout = null;
            }
        }

        // Export final metrics
        if (this.config.enableExport) {
            await this.exportMetrics(Date.now());
        }

        // Generate final report
        const report = await this.generateReport();
        console.log(report);

        console.log('✅ Monitoring system shutdown complete');
    }
}

// Export singleton instance
let instance = null;

module.exports = {
    MonitoringSystem,
    getInstance: (options = {}) => {
        if (!instance) {
            instance = new MonitoringSystem(options);
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