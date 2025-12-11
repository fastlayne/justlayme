/**
 * Memory Performance Monitor
 *
 * Real-time performance monitoring and metrics dashboard for the memory engine.
 * Tracks search times, cache hit rates, embedding generation, and system health.
 *
 * @author Performance Optimization Team
 * @date 2025-10-25
 */

class MemoryPerformanceMonitor {
    constructor(memoryEngine) {
        this.engine = memoryEngine;
        this.startTime = Date.now();
        this.checkpoints = [];

        // Performance thresholds
        this.thresholds = {
            searchTime: 50,           // Target: <50ms
            embeddingTime: 2000,      // Target: <2s
            cacheHitRate: 80,         // Target: >80%
            queueLength: 10           // Alert if queue > 10
        };

        // Alerts
        this.alerts = [];
        this.maxAlerts = 100;
    }

    /**
     * Record a performance checkpoint
     */
    checkpoint(label) {
        this.checkpoints.push({
            label,
            timestamp: Date.now(),
            stats: this.engine.getStats()
        });
    }

    /**
     * Check performance against thresholds
     */
    checkHealth() {
        const stats = this.engine.getStats();
        const health = {
            status: 'healthy',
            issues: [],
            metrics: {}
        };

        // Parse search time
        const avgSearchTime = parseFloat(stats.performance.avgSearchTime);
        if (avgSearchTime > this.thresholds.searchTime) {
            health.issues.push({
                severity: 'warning',
                metric: 'avgSearchTime',
                value: avgSearchTime,
                threshold: this.thresholds.searchTime,
                message: `Average search time ${avgSearchTime.toFixed(2)}ms exceeds target ${this.thresholds.searchTime}ms`
            });
            health.status = 'degraded';
        }

        // Check cache hit rate
        const embeddingCacheHit = parseFloat(stats.caches.embedding.hitRate);
        if (embeddingCacheHit < this.thresholds.cacheHitRate) {
            health.issues.push({
                severity: 'info',
                metric: 'embeddingCacheHitRate',
                value: embeddingCacheHit,
                threshold: this.thresholds.cacheHitRate,
                message: `Embedding cache hit rate ${embeddingCacheHit.toFixed(2)}% below target ${this.thresholds.cacheHitRate}%`
            });
        }

        // Check queue length
        if (stats.queue.queued > this.thresholds.queueLength) {
            health.issues.push({
                severity: 'critical',
                metric: 'queueLength',
                value: stats.queue.queued,
                threshold: this.thresholds.queueLength,
                message: `Embedding queue length ${stats.queue.queued} exceeds threshold ${this.thresholds.queueLength}`
            });
            health.status = 'critical';
        }

        // Store health metrics
        health.metrics = {
            avgSearchTime,
            maxSearchTime: parseFloat(stats.performance.maxSearchTime),
            embeddingCacheHitRate: embeddingCacheHit,
            searchCacheHitRate: parseFloat(stats.caches.search.hitRate),
            queueLength: stats.queue.queued,
            queueActive: stats.queue.active
        };

        // Add to alerts if issues found
        if (health.issues.length > 0) {
            this.addAlert({
                timestamp: Date.now(),
                status: health.status,
                issues: health.issues
            });
        }

        return health;
    }

    /**
     * Add alert to history
     */
    addAlert(alert) {
        this.alerts.unshift(alert);
        if (this.alerts.length > this.maxAlerts) {
            this.alerts.pop();
        }
    }

    /**
     * Get recent alerts
     */
    getRecentAlerts(limit = 10) {
        return this.alerts.slice(0, limit);
    }

    /**
     * Generate performance report
     */
    generateReport() {
        const stats = this.engine.getStats();
        const health = this.checkHealth();
        const uptime = Date.now() - this.startTime;

        return {
            timestamp: new Date().toISOString(),
            uptime: this._formatDuration(uptime),
            health: health,

            searches: {
                total: stats.searches.total,
                cached: stats.searches.cached,
                cachePercentage: stats.searches.cachePercentage,
                byType: {
                    neural: stats.searches.neural,
                    tfidf: stats.searches.tfidf,
                    hybrid: stats.searches.hybrid
                }
            },

            embeddings: {
                total: stats.embeddings.total,
                generated: stats.embeddings.generated,
                cached: stats.embeddings.cached,
                cacheHitRate: stats.embeddings.cacheHitRate,
                failed: stats.embeddings.failed,
                queued: stats.embeddings.queued
            },

            caches: {
                embedding: {
                    size: stats.caches.embedding.size,
                    maxSize: stats.caches.embedding.maxSize,
                    utilization: ((stats.caches.embedding.size / stats.caches.embedding.maxSize) * 100).toFixed(2) + '%',
                    hitRate: stats.caches.embedding.hitRate
                },
                search: {
                    size: stats.caches.search.size,
                    maxSize: stats.caches.search.maxSize,
                    utilization: ((stats.caches.search.size / stats.caches.search.maxSize) * 100).toFixed(2) + '%',
                    hitRate: stats.caches.search.hitRate
                }
            },

            queue: {
                active: stats.queue.active,
                queued: stats.queue.queued,
                processed: stats.queue.processed,
                errors: stats.queue.errors,
                maxConcurrent: stats.queue.maxConcurrent
            },

            pruning: {
                checked: stats.pruning.checked,
                pruned: stats.pruning.pruned,
                lastRun: stats.pruning.lastRun > 0 ?
                    new Date(stats.pruning.lastRun).toISOString() : 'never'
            },

            performance: {
                avgSearchTime: stats.performance.avgSearchTime,
                maxSearchTime: stats.performance.maxSearchTime,
                avgEmbeddingTime: stats.performance.avgEmbeddingTime,
                targetSearchTime: `<${this.thresholds.searchTime}ms`,
                searchTimeStatus: parseFloat(stats.performance.avgSearchTime) < this.thresholds.searchTime ? 'PASS' : 'FAIL'
            },

            checkpoints: this.checkpoints.length,
            recentAlerts: this.alerts.length
        };
    }

    /**
     * Generate detailed performance dashboard
     */
    getDashboard() {
        const report = this.generateReport();

        const dashboard = `
╔════════════════════════════════════════════════════════════════╗
║          MEMORY ENGINE PERFORMANCE DASHBOARD                   ║
╠════════════════════════════════════════════════════════════════╣
║ Status: ${this._pad(report.health.status.toUpperCase(), 20)} Uptime: ${this._pad(report.uptime, 20)} ║
╠════════════════════════════════════════════════════════════════╣
║ SEARCH PERFORMANCE                                              ║
║   Avg Time: ${this._pad(report.performance.avgSearchTime, 15)} Target: ${this._pad(report.performance.targetSearchTime, 15)} ║
║   Max Time: ${this._pad(report.performance.maxSearchTime, 15)} Status: ${this._pad(report.performance.searchTimeStatus, 15)} ║
║   Total:    ${this._pad(report.searches.total.toString(), 15)} Cached: ${this._pad(report.searches.cachePercentage, 15)} ║
╠════════════════════════════════════════════════════════════════╣
║ EMBEDDING GENERATION                                            ║
║   Avg Time: ${this._pad(report.performance.avgEmbeddingTime, 15)} Total:  ${this._pad(report.embeddings.total.toString(), 15)} ║
║   Cache:    ${this._pad(report.embeddings.cacheHitRate, 15)} Failed: ${this._pad(report.embeddings.failed.toString(), 15)} ║
║   Queue:    ${this._pad(report.queue.queued.toString(), 15)} Active: ${this._pad(report.queue.active.toString(), 15)} ║
╠════════════════════════════════════════════════════════════════╣
║ CACHE UTILIZATION                                               ║
║   Embedding: ${this._pad(report.caches.embedding.utilization, 10)} Hit: ${this._pad(report.caches.embedding.hitRate, 10)} ║
║   Search:    ${this._pad(report.caches.search.utilization, 10)} Hit: ${this._pad(report.caches.search.hitRate, 10)} ║
╠════════════════════════════════════════════════════════════════╣
║ MEMORY PRUNING                                                  ║
║   Checked:   ${this._pad(report.pruning.checked.toString(), 20)} Pruned: ${this._pad(report.pruning.pruned.toString(), 20)} ║
║   Last Run:  ${this._pad(this._formatTimestamp(report.pruning.lastRun), 45)} ║
╠════════════════════════════════════════════════════════════════╣
`;

        // Add health issues if any
        if (report.health.issues.length > 0) {
            const issues = report.health.issues.map(issue =>
                `║ [${issue.severity.toUpperCase()}] ${issue.message.substring(0, 57).padEnd(57)} ║`
            ).join('\n');
            return dashboard + `║ ALERTS                                                          ║\n${issues}\n╚════════════════════════════════════════════════════════════════╝\n`;
        } else {
            return dashboard + `║ No performance issues detected                                  ║\n╚════════════════════════════════════════════════════════════════╝\n`;
        }
    }

    /**
     * Start continuous monitoring
     */
    startMonitoring(intervalMs = 60000) {
        this.monitoringInterval = setInterval(() => {
            const health = this.checkHealth();
            if (health.status !== 'healthy') {
                console.log('\n[PerformanceMonitor] Health check alert:');
                console.log(this.getDashboard());
            }
        }, intervalMs);

        console.log('[PerformanceMonitor] Started continuous monitoring');
    }

    /**
     * Stop continuous monitoring
     */
    stopMonitoring() {
        if (this.monitoringInterval) {
            clearInterval(this.monitoringInterval);
            console.log('[PerformanceMonitor] Stopped continuous monitoring');
        }
    }

    // ==================== HELPER METHODS ====================

    _formatDuration(ms) {
        const seconds = Math.floor(ms / 1000);
        const minutes = Math.floor(seconds / 60);
        const hours = Math.floor(minutes / 60);
        const days = Math.floor(hours / 24);

        if (days > 0) return `${days}d ${hours % 24}h`;
        if (hours > 0) return `${hours}h ${minutes % 60}m`;
        if (minutes > 0) return `${minutes}m ${seconds % 60}s`;
        return `${seconds}s`;
    }

    _formatTimestamp(timestamp) {
        if (timestamp === 'never') return 'never';
        return new Date(timestamp).toLocaleString();
    }

    _pad(str, length) {
        return String(str).padEnd(length).substring(0, length);
    }
}

module.exports = MemoryPerformanceMonitor;
