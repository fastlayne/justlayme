// Database Maintenance System for JustLayMe
// Automated maintenance, cleanup, and optimization tasks

const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');
const { Mutex } = require('async-mutex');
const resourceLifecycleManager = require('./resource-lifecycle-manager');

// SECURITY: Whitelist of allowed table names to prevent SQL injection
const ALLOWED_TABLES = new Set([
    'users',
    'conversations',
    'messages',
    'characters',
    'custom_characters',
    'memory_embeddings',
    'memories',
    'user_sessions',
    'chat_history',
    'group_conversations',
    'group_messages'
]);

class DatabaseMaintenance {
    constructor(database, options = {}) {
        this.db = database;
        this.options = {
            // Cleanup thresholds
            maxLogAge: options.maxLogAge || 90 * 24 * 60 * 60 * 1000, // 90 days
            maxMemoryAge: options.maxMemoryAge || 30 * 24 * 60 * 60 * 1000, // 30 days
            maxSessionAge: options.maxSessionAge || 7 * 24 * 60 * 60 * 1000, // 7 days
            lowImportanceThreshold: options.lowImportanceThreshold || 0.3,
            
            // Maintenance schedule
            enableAutoMaintenance: options.enableAutoMaintenance !== false,
            maintenanceInterval: options.maintenanceInterval || 4 * 60 * 60 * 1000, // 4 hours
            vacuumInterval: options.vacuumInterval || 24 * 60 * 60 * 1000, // 24 hours
            
            // Backup settings
            enableBackups: options.enableBackups !== false,
            backupRetention: options.backupRetention || 7, // Keep 7 days
            backupPath: options.backupPath || path.join(__dirname, '../backups')
        };
        
        // Maintenance state
        this.maintenanceHistory = [];
        this.isMaintenanceRunning = false;
        this.isVacuumRunning = false;  // ARCHITECTURAL FIX: Add vacuum lock flag
        this.maintenanceMutex = new Mutex(); // Atomic lock for maintenance operations
        this.vacuumMutex = new Mutex(); // Atomic lock for vacuum operations
        this.lastMaintenanceRun = null;
        this.lastVacuumRun = null;
        this.lastBackupRun = null;
        
        // Statistics
        this.stats = {
            cleanupOperations: 0,
            recordsDeleted: 0,
            spaceReclaimed: 0,
            backupsCreated: 0,
            optimizationRuns: 0
        };
        
        console.log('🔧 Database Maintenance System initialized');

        if (this.options.enableAutoMaintenance) {
            this.startAutoMaintenance();
        }
    }

    /**
     * SECURITY: Validate table name against whitelist to prevent SQL injection
     * Table names cannot be parameterized in SQL, so we must validate before concatenation
     * @param {string} tableName - Table name to validate
     * @returns {string} - Validated table name
     * @throws {Error} - If table name is not in whitelist
     */
    validateTableName(tableName) {
        if (!ALLOWED_TABLES.has(tableName)) {
            throw new Error(`Invalid table name: ${tableName}. Not in allowed tables whitelist.`);
        }
        return tableName;
    }

    // Start automatic maintenance
    startAutoMaintenance() {
        // ARCHITECTURAL FIX: Register intervals with ResourceLifecycleManager
        // This ensures proper cleanup on shutdown and prevents memory leaks
        
        // Regular maintenance
        this.maintenanceInterval = resourceLifecycleManager.registerInterval(
            'db-maintenance-regular',
            () => this.runMaintenance(),
            this.options.maintenanceInterval,
            { stopOnError: false }
        );
        
        // Vacuum operations
        this.vacuumInterval = resourceLifecycleManager.registerInterval(
            'db-maintenance-vacuum',
            () => this.runVacuum(),
            this.options.vacuumInterval,
            { stopOnError: false }
        );
        
        // Daily backup (at 2 AM if possible)
        const now = new Date();
        const nextBackup = new Date();
        nextBackup.setHours(2, 0, 0, 0);
        
        if (nextBackup <= now) {
            nextBackup.setDate(nextBackup.getDate() + 1);
        }
        
        const timeToBackup = nextBackup.getTime() - now.getTime();
        
        // Use ResourceLifecycleManager for initial timeout
        resourceLifecycleManager.registerTimeout('db-backup-initial', () => {
            this.createBackup();
            // Then run daily using ResourceLifecycleManager
            this.backupInterval = resourceLifecycleManager.registerInterval(
                'db-maintenance-backup',
                () => this.createBackup(),
                24 * 60 * 60 * 1000,
                { stopOnError: false }
            );
        }, timeToBackup);
        
        console.log('LOADING Automatic maintenance started');
        console.log(`   - Next maintenance: ${new Date(Date.now() + this.options.maintenanceInterval).toLocaleString()}`);
        console.log(`   - Next vacuum: ${new Date(Date.now() + this.options.vacuumInterval).toLocaleString()}`);
        console.log(`   - Next backup: ${nextBackup.toLocaleString()}`);
    }

    // Run comprehensive maintenance
    async runMaintenance(force = false) {
        // ARCHITECTURAL FIX: Use async-mutex for truly atomic lock acquisition
        // This prevents race conditions that can occur with manual flag checking
        const release = force
            ? await this.maintenanceMutex.acquire() // Wait for lock in force mode
            : this.maintenanceMutex.tryAcquire();   // Non-blocking in normal mode

        if (!release) {
            console.log('⏳ Maintenance already running, skipping...');
            return;
        }

        this.isMaintenanceRunning = true; // Update flag for status reporting
        const startTime = Date.now();
        
        console.log('🔧 Starting database maintenance...');
        
        try {
            const tasks = [];
            
            // 1. Clean old logs
            tasks.push(this.cleanOldLogs());
            
            // 2. Clean old memories
            tasks.push(this.cleanOldMemories());
            
            // 3. Clean old sessions
            tasks.push(this.cleanOldSessions());
            
            // 4. Clean orphaned records
            tasks.push(this.cleanOrphanedRecords());
            
            // 5. Update statistics
            tasks.push(this.updateTableStatistics());
            
            // 6. Optimize indexes
            tasks.push(this.optimizeIndexes());
            
            // 7. Clean verification tokens
            tasks.push(this.cleanExpiredTokens());
            
            const results = await Promise.allSettled(tasks);
            
            // Log results
            const successful = results.filter(r => r.status === 'fulfilled').length;
            const failed = results.filter(r => r.status === 'rejected');
            
            if (failed.length > 0) {
                console.error('ERROR Some maintenance tasks failed:');
                failed.forEach((result, index) => {
                    console.error(`   Task ${index + 1}: ${result.reason}`);
                });
            }
            
            const duration = Date.now() - startTime;
            this.lastMaintenanceRun = Date.now();
            this.stats.optimizationRuns++;
            
            // Record maintenance run
            this.maintenanceHistory.push({
                timestamp: Date.now(),
                duration,
                tasksSuccessful: successful,
                tasksFailed: failed.length,
                type: 'maintenance'
            });
            
            // Keep only last 50 maintenance runs
            if (this.maintenanceHistory.length > 50) {
                this.maintenanceHistory.shift();
            }
            
            console.log(`SUCCESS Maintenance completed in ${(duration / 1000).toFixed(2)}s (${successful}/${results.length} tasks successful)`);
            
        } catch (error) {
            console.error('ERROR Maintenance failed:', error);
        } finally {
            this.isMaintenanceRunning = false;
            release(); // Release the mutex lock
        }
    }

    // Clean old log entries
    async cleanOldLogs() {
        try {
            const cutoffTime = Date.now() - this.options.maxLogAge;
            const cutoffDate = new Date(cutoffTime).toISOString();
            
            const deleted = await this.db.query(`
                DELETE FROM email_verification_logs 
                WHERE created_at < ?
            `, [cutoffDate]);
            
            this.stats.recordsDeleted += deleted.rowCount || 0;
            console.log(`🧹 Cleaned ${deleted.rowCount || 0} old log entries`);
            
        } catch (error) {
            console.error('Failed to clean old logs:', error);
            throw error;
        }
    }

    // Clean old memory entries
    async cleanOldMemories() {
        try {
            const cutoffTime = Date.now() - this.options.maxMemoryAge;
            const cutoffTimestamp = Math.floor(cutoffTime / 1000);
            
            // Clean low-importance, rarely accessed memories
            const deleted = await this.db.query(`
                DELETE FROM memory_embeddings 
                WHERE created_at < datetime(?, 'unixepoch')
                AND importance_score < ?
                AND (
                    SELECT COUNT(*) FROM memory_embeddings me2 
                    WHERE me2.user_id = memory_embeddings.user_id
                ) > 50
            `, [cutoffTimestamp, this.options.lowImportanceThreshold]);
            
            // Clean optimized memory table too if it exists
            const deletedOptimized = await this.db.query(`
                DELETE FROM memory_embeddings_optimized 
                WHERE created_at < ?
                AND importance_score < ?
                AND access_count < 2
                AND (
                    SELECT COUNT(*) FROM memory_embeddings_optimized me2 
                    WHERE me2.user_id = memory_embeddings_optimized.user_id
                ) > 100
            `, [cutoffTimestamp, this.options.lowImportanceThreshold]).catch(() => ({ rowCount: 0 }));
            
            const totalDeleted = (deleted.rowCount || 0) + (deletedOptimized.rowCount || 0);
            this.stats.recordsDeleted += totalDeleted;
            
            console.log(`🧹 Cleaned ${totalDeleted} old memory entries`);
            
        } catch (error) {
            console.error('Failed to clean old memories:', error);
            throw error;
        }
    }

    // Clean old sessions
    async cleanOldSessions() {
        try {
            const cutoffTime = Date.now() - this.options.maxSessionAge;
            const cutoffDate = new Date(cutoffTime).toISOString();
            
            const deleted = await this.db.query(`
                DELETE FROM sessions 
                WHERE last_activity < ? 
                AND is_premium = 0
            `, [cutoffDate]);
            
            this.stats.recordsDeleted += deleted.rowCount || 0;
            console.log(`🧹 Cleaned ${deleted.rowCount || 0} old sessions`);
            
        } catch (error) {
            console.error('Failed to clean old sessions:', error);
            throw error;
        }
    }

    // Clean orphaned records
    async cleanOrphanedRecords() {
        try {
            let totalDeleted = 0;
            
            // Clean messages without conversations
            const orphanedMessages = await this.db.query(`
                DELETE FROM messages 
                WHERE conversation_id NOT IN (SELECT id FROM conversations)
            `);
            totalDeleted += orphanedMessages.rowCount || 0;
            
            // Clean character memories without characters
            const orphanedCharacterMemories = await this.db.query(`
                DELETE FROM character_memories 
                WHERE character_id NOT IN (SELECT id FROM characters)
            `);
            totalDeleted += orphanedCharacterMemories.rowCount || 0;
            
            // Clean character learning without characters
            const orphanedCharacterLearning = await this.db.query(`
                DELETE FROM character_learning 
                WHERE character_id NOT IN (SELECT id FROM characters)
            `);
            totalDeleted += orphanedCharacterLearning.rowCount || 0;
            
            // Clean voice samples without users
            const orphanedVoiceSamples = await this.db.query(`
                DELETE FROM voice_samples 
                WHERE user_id NOT IN (SELECT CAST(id AS TEXT) FROM users)
            `);
            totalDeleted += orphanedVoiceSamples.rowCount || 0;
            
            // Clean user feedback without users or messages
            const orphanedFeedback = await this.db.query(`
                DELETE FROM user_feedback 
                WHERE user_id NOT IN (SELECT id FROM users)
                OR message_id NOT IN (SELECT id FROM messages)
            `).catch(() => ({ rowCount: 0 }));
            totalDeleted += orphanedFeedback.rowCount || 0;
            
            this.stats.recordsDeleted += totalDeleted;
            console.log(`🧹 Cleaned ${totalDeleted} orphaned records`);
            
        } catch (error) {
            console.error('Failed to clean orphaned records:', error);
            throw error;
        }
    }

    // Update table statistics
    async updateTableStatistics() {
        try {
            // Run ANALYZE to update statistics for query optimizer
            await this.db.query('ANALYZE');
            
            // Update internal statistics
            const tableStats = {};
            
            const tables = ['users', 'conversations', 'messages', 'characters', 'memory_embeddings'];
            
            for (const table of tables) {
                try {
                    // SECURITY: Validate table name before using in SQL query
                    const validatedTable = this.validateTableName(table);
                    const countResult = await this.db.query(`SELECT COUNT(*) as count FROM ${validatedTable}`);
                    tableStats[table] = countResult.rows[0].count;
                } catch (error) {
                    tableStats[table] = 0;
                }
            }
            
            console.log('STATS Updated table statistics:', tableStats);
            
        } catch (error) {
            console.error('Failed to update statistics:', error);
            throw error;
        }
    }

    // Optimize indexes
    async optimizeIndexes() {
        try {
            // Reindex if fragmentation is high
            await this.db.query('REINDEX');
            
            // Run optimization
            await this.db.query('PRAGMA optimize');
            
            console.log('OPTIMIZING Optimized database indexes');
            
        } catch (error) {
            console.error('Failed to optimize indexes:', error);
            throw error;
        }
    }

    // Clean expired verification tokens
    async cleanExpiredTokens() {
        try {
            const deleted = await this.db.query(`
                UPDATE users
                SET email_verification_token = NULL,
                    email_verification_expires = NULL
                WHERE email_verification_expires < ${this.db.getCurrentTimestamp()}
                AND email_verified = 0
            `);

            this.stats.recordsDeleted += deleted.rowCount || 0;
            console.log(`🧹 Cleaned ${deleted.rowCount || 0} expired verification tokens`);
            
        } catch (error) {
            console.error('Failed to clean expired tokens:', error);
            throw error;
        }
    }

    // Run vacuum operation
    async runVacuum() {
        // ARCHITECTURAL FIX: Use async-mutex for atomic vacuum locking
        if (this.isMaintenanceRunning) {
            console.log('⏳ Maintenance running, skipping vacuum...');
            return;
        }

        // Try to acquire vacuum lock atomically
        const release = this.vacuumMutex.tryAcquire();
        if (!release) {
            console.log('⏳ Vacuum already running, skipping...');
            return;
        }

        this.isVacuumRunning = true; // Update flag for status reporting
        console.log('🧹 Starting database vacuum...');
        const startTime = Date.now();
        
        try {
            // Get database size before vacuum
            const sizeBefore = await this.getDatabaseSize();
            
            // Run vacuum
            await this.db.query('VACUUM');
            
            // Get database size after vacuum
            const sizeAfter = await this.getDatabaseSize();
            const spaceReclaimed = sizeBefore - sizeAfter;
            
            this.stats.spaceReclaimed += Math.max(spaceReclaimed, 0);
            this.lastVacuumRun = Date.now();
            
            const duration = Date.now() - startTime;
            
            // Record vacuum run
            this.maintenanceHistory.push({
                timestamp: Date.now(),
                duration,
                type: 'vacuum',
                sizeBefore,
                sizeAfter,
                spaceReclaimed: Math.max(spaceReclaimed, 0)
            });
            
            if (spaceReclaimed > 0) {
                console.log(`SUCCESS Vacuum completed in ${(duration / 1000).toFixed(2)}s, reclaimed ${this.formatBytes(spaceReclaimed)}`);
            } else {
                console.log(`SUCCESS Vacuum completed in ${(duration / 1000).toFixed(2)}s, no space reclaimed`);
            }

        } catch (error) {
            console.error('ERROR Vacuum failed:', error);
        } finally {
            // ARCHITECTURAL FIX: Always clear vacuum lock and release mutex
            this.isVacuumRunning = false;
            release(); // Release the mutex lock
        }
    }

    // Create database backup
    async createBackup() {
        console.log('BACKUP Creating database backup...');
        
        try {
            // Ensure backup directory exists
            await fs.mkdir(this.options.backupPath, { recursive: true });
            
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
            const backupFileName = `justlayme-backup-${timestamp}.db`;
            const backupPath = path.join(this.options.backupPath, backupFileName);
            
            // For SQLite, we can copy the file
            const dbPath = path.join(__dirname, '../database/justlayme.db');
            
            try {
                await fs.access(dbPath);
                await fs.copyFile(dbPath, backupPath);
                
                // Verify backup
                const stats = await fs.stat(backupPath);
                if (stats.size > 0) {
                    this.stats.backupsCreated++;
                    this.lastBackupRun = Date.now();
                    
                    console.log(`SUCCESS Backup created: ${backupFileName} (${this.formatBytes(stats.size)})`);
                    
                    // Clean old backups
                    await this.cleanOldBackups();
                    
                } else {
                    throw new Error('Backup file is empty');
                }
                
            } catch (error) {
                console.error('Failed to create backup:', error);
                throw error;
            }
            
        } catch (error) {
            console.error('ERROR Backup failed:', error);
        }
    }

    // Clean old backup files
    async cleanOldBackups() {
        try {
            const files = await fs.readdir(this.options.backupPath);
            const backupFiles = files
                .filter(file => file.startsWith('justlayme-backup-'))
                .map(async (file) => {
                    const filePath = path.join(this.options.backupPath, file);
                    const stats = await fs.stat(filePath);
                    return {
                        name: file,
                        path: filePath,
                        mtime: stats.mtime
                    };
                });
            
            const backupsWithStats = await Promise.all(backupFiles);
            
            // Sort by modification time (newest first)
            backupsWithStats.sort((a, b) => b.mtime - a.mtime);
            
            // Remove backups beyond retention period
            const backupsToDelete = backupsWithStats.slice(this.options.backupRetention);
            
            for (const backup of backupsToDelete) {
                await fs.unlink(backup.path);
                console.log(`🗑️ Deleted old backup: ${backup.name}`);
            }
            
        } catch (error) {
            console.error('Failed to clean old backups:', error);
        }
    }

    // Get database file size
    async getDatabaseSize() {
        try {
            const dbPath = path.join(__dirname, '../database/justlayme.db');
            const stats = await fs.stat(dbPath);
            return stats.size;
        } catch (error) {
            return 0;
        }
    }

    // Performance health check
    async performHealthCheck() {
        console.log('OPTIMIZING Performing database health check...');
        
        const health = {
            timestamp: Date.now(),
            healthy: true,
            issues: [],
            recommendations: [],
            stats: {}
        };
        
        try {
            // Check database connectivity
            await this.db.query('SELECT 1');
            
            // Check database size
            const dbSize = await this.getDatabaseSize();
            health.stats.databaseSize = this.formatBytes(dbSize);
            
            if (dbSize > 1024 * 1024 * 1024) { // > 1GB
                health.issues.push('Database size is quite large (>1GB)');
                health.recommendations.push('Consider running VACUUM and cleaning old data');
            }
            
            // Check for table fragmentation
            const fragmentation = await this.checkFragmentation();
            if (fragmentation > 30) {
                health.issues.push(`High fragmentation detected (${fragmentation}%)`);
                health.recommendations.push('Run VACUUM to defragment database');
            }
            
            // Check for orphaned records
            const orphanedCount = await this.countOrphanedRecords();
            if (orphanedCount > 100) {
                health.issues.push(`${orphanedCount} orphaned records found`);
                health.recommendations.push('Run maintenance to clean orphaned records');
            }
            
            // Check last maintenance
            if (!this.lastMaintenanceRun || Date.now() - this.lastMaintenanceRun > 24 * 60 * 60 * 1000) {
                health.issues.push('Maintenance has not run in the last 24 hours');
                health.recommendations.push('Run database maintenance');
            }
            
            // Check backup status
            if (!this.lastBackupRun || Date.now() - this.lastBackupRun > 48 * 60 * 60 * 1000) {
                health.issues.push('No backup created in the last 48 hours');
                health.recommendations.push('Create database backup');
            }
            
            health.healthy = health.issues.length === 0;
            
        } catch (error) {
            health.healthy = false;
            health.issues.push(`Database connectivity error: ${error.message}`);
            health.recommendations.push('Check database connection and restart if necessary');
        }
        
        return health;
    }

    // Check database fragmentation
    async checkFragmentation() {
        try {
            const result = await this.db.query('PRAGMA freelist_count');
            const freePages = result.rows[0].freelist_count || 0;
            
            const totalResult = await this.db.query('PRAGMA page_count');
            const totalPages = totalResult.rows[0].page_count || 1;
            
            return (freePages / totalPages) * 100;
            
        } catch (error) {
            return 0;
        }
    }

    // Count orphaned records
    async countOrphanedRecords() {
        try {
            let count = 0;
            
            // Count messages without conversations
            const orphanedMessages = await this.db.query(`
                SELECT COUNT(*) as count 
                FROM messages 
                WHERE conversation_id NOT IN (SELECT id FROM conversations)
            `);
            count += orphanedMessages.rows[0].count || 0;
            
            // Count other orphaned records...
            // (implementation similar to cleanOrphanedRecords but with COUNT)
            
            return count;
            
        } catch (error) {
            return 0;
        }
    }

    // Get maintenance report
    getMaintenanceReport() {
        const recent = this.maintenanceHistory.slice(-10);
        
        return {
            stats: this.stats,
            lastMaintenance: this.lastMaintenanceRun,
            lastVacuum: this.lastVacuumRun,
            lastBackup: this.lastBackupRun,
            recentHistory: recent,
            isRunning: this.isMaintenanceRunning,
            autoMaintenanceEnabled: this.options.enableAutoMaintenance
        };
    }

    // Manual operations
    async runFullMaintenance() {
        console.log('🔧 Running full maintenance (manual)...');
        await this.runMaintenance(true);
        await this.runVacuum();
        await this.createBackup();
    }

    // Export database statistics
    async exportDatabaseStats() {
        const stats = {
            timestamp: Date.now(),
            databaseSize: await this.getDatabaseSize(),
            fragmentation: await this.checkFragmentation(),
            orphanedRecords: await this.countOrphanedRecords(),
            maintenanceStats: this.stats,
            tableStats: {}
        };
        
        // Get table statistics
        const tables = ['users', 'conversations', 'messages', 'characters', 'memory_embeddings'];

        for (const table of tables) {
            try {
                // SECURITY: Validate table name before using in SQL query
                const validatedTable = this.validateTableName(table);
                const countResult = await this.db.query(`SELECT COUNT(*) as count FROM ${validatedTable}`);
                stats.tableStats[table] = countResult.rows[0].count;
            } catch (error) {
                stats.tableStats[table] = 0;
            }
        }
        
        return stats;
    }

    // Utility methods
    formatBytes(bytes) {
        const sizes = ['B', 'KB', 'MB', 'GB'];
        if (bytes === 0) return '0B';
        const i = Math.floor(Math.log(bytes) / Math.log(1024));
        return `${(bytes / Math.pow(1024, i)).toFixed(2)}${sizes[i]}`;
    }

    // Graceful shutdown
    async shutdown() {
        console.log('🛑 Shutting down database maintenance...');
        
        // ARCHITECTURAL FIX: Clear intervals via ResourceLifecycleManager
        // This ensures consistent cleanup across the application
        resourceLifecycleManager.clearInterval('db-maintenance-regular');
        resourceLifecycleManager.clearInterval('db-maintenance-vacuum');
        resourceLifecycleManager.clearInterval('db-maintenance-backup');
        resourceLifecycleManager.clearTimeout('db-backup-initial');
        
        // Wait for current maintenance to finish
        while (this.isMaintenanceRunning) {
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
        
        console.log('✅ Database maintenance shutdown complete');
    }
}

module.exports = DatabaseMaintenance;