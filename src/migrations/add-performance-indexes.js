#!/usr/bin/env node
/**
 * Database Performance Index Migration
 * Adds critical missing indexes identified in audit
 * Expected performance improvement: 10-15x faster queries
 *
 * Date: November 18, 2025
 * Priority: P0 - Critical Performance Issue
 */

const Database = require('../database');
const db = Database.getInstance();

// ANSI color codes for terminal output
const colors = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    red: '\x1b[31m',
    cyan: '\x1b[36m',
    dim: '\x1b[2m'
};

const log = {
    info: (msg) => console.log(`${colors.cyan}ℹ ${msg}${colors.reset}`),
    success: (msg) => console.log(`${colors.green}✓ ${msg}${colors.reset}`),
    warn: (msg) => console.log(`${colors.yellow}⚠ ${msg}${colors.reset}`),
    error: (msg) => console.log(`${colors.red}✗ ${msg}${colors.reset}`),
    dim: (msg) => console.log(`${colors.dim}  ${msg}${colors.reset}`)
};

/**
 * Indexes to add based on audit recommendations
 * Source: AUDIT_DATABASE.md lines 322-340
 */
const indexesToAdd = [
    {
        name: 'idx_conversations_user_created',
        table: 'conversations',
        columns: 'user_id, created_at DESC',
        reason: 'Optimize loading user conversations sorted by date (15x faster)',
        sql: 'CREATE INDEX IF NOT EXISTS idx_conversations_user_created ON conversations(user_id, created_at DESC)'
    },
    {
        name: 'idx_messages_conversation_created',
        table: 'messages',
        columns: 'conversation_uuid, created_at DESC',
        reason: 'Optimize loading conversation messages chronologically (13x faster)',
        sql: 'CREATE INDEX IF NOT EXISTS idx_messages_conversation_created ON messages(conversation_uuid, created_at DESC)'
    },
    {
        name: 'idx_messages_sender',
        table: 'messages',
        columns: 'sender_type',
        reason: 'Optimize filtering by message sender (user vs AI)',
        sql: 'CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_type)'
    },
    {
        name: 'idx_characters_user_id',
        table: 'characters',
        columns: 'user_id',
        reason: 'Optimize loading user characters (10x faster)',
        sql: 'CREATE INDEX IF NOT EXISTS idx_characters_user_id ON characters(user_id)'
    },
    {
        name: 'idx_characters_public',
        table: 'characters',
        columns: 'is_public, created_at DESC',
        reason: 'Optimize loading public character gallery',
        sql: 'CREATE INDEX IF NOT EXISTS idx_characters_public ON characters(is_public, created_at DESC)'
    },
    {
        name: 'idx_sessions_user',
        table: 'sessions',
        columns: 'user_id',
        reason: 'Optimize loading user sessions',
        sql: 'CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id)'
    },
    {
        name: 'idx_sessions_activity',
        table: 'sessions',
        columns: 'last_activity DESC',
        reason: 'Optimize finding active/recent sessions',
        sql: 'CREATE INDEX IF NOT EXISTS idx_sessions_activity ON sessions(last_activity DESC)'
    }
];

/**
 * Check if an index already exists
 */
async function indexExists(indexName) {
    try {
        const result = await db.query(
            "SELECT name FROM sqlite_master WHERE type='index' AND name=?",
            [indexName]
        );
        return result.length > 0;
    } catch (error) {
        log.warn(`Could not check if index ${indexName} exists: ${error.message}`);
        return false;
    }
}

/**
 * Get current database statistics
 */
async function getDatabaseStats() {
    try {
        const tables = await db.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
            []
        );

        const stats = {};
        for (const table of tables) {
            const countResult = await db.query(`SELECT COUNT(*) as count FROM ${table.name}`, []);
            stats[table.name] = countResult[0].count;
        }

        return stats;
    } catch (error) {
        log.warn(`Could not get database stats: ${error.message}`);
        return {};
    }
}

/**
 * Main migration function
 */
async function migrate() {
    log.info('Starting database index migration...\n');

    // Show current database statistics
    const stats = await getDatabaseStats();
    log.info('Current database statistics:');
    Object.entries(stats).forEach(([table, count]) => {
        log.dim(`  ${table}: ${count.toLocaleString()} rows`);
    });
    console.log('');

    let successCount = 0;
    let skipCount = 0;
    let errorCount = 0;

    // Add each index
    for (const index of indexesToAdd) {
        try {
            // Check if index already exists
            const exists = await indexExists(index.name);
            if (exists) {
                log.warn(`Index ${index.name} already exists, skipping`);
                log.dim(`  Table: ${index.table}, Columns: ${index.columns}`);
                skipCount++;
                continue;
            }

            // Create index
            log.info(`Creating index: ${index.name}`);
            log.dim(`  Table: ${index.table}`);
            log.dim(`  Columns: ${index.columns}`);
            log.dim(`  Reason: ${index.reason}`);

            await db.query(index.sql, []);

            log.success(`Index ${index.name} created successfully`);
            successCount++;
            console.log('');

        } catch (error) {
            log.error(`Failed to create index ${index.name}: ${error.message}`);
            errorCount++;
            console.log('');
        }
    }

    // Summary
    console.log('');
    log.info('Migration Summary:');
    log.success(`  ${successCount} indexes created`);
    if (skipCount > 0) log.warn(`  ${skipCount} indexes already existed`);
    if (errorCount > 0) log.error(`  ${errorCount} indexes failed`);
    console.log('');

    if (successCount > 0) {
        log.success('Performance improvement expected:');
        log.dim('  - Conversation loading: 15x faster');
        log.dim('  - Message loading: 13x faster');
        log.dim('  - Character loading: 10x faster');
        console.log('');
    }

    // List all indexes
    log.info('Current database indexes:');
    const indexes = await db.query(
        "SELECT name, tbl_name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%' ORDER BY tbl_name, name",
        []
    );
    indexes.forEach(idx => {
        log.dim(`  ${idx.tbl_name}.${idx.name}`);
    });
    console.log('');

    log.success('Migration completed successfully!');

    return {
        success: successCount,
        skipped: skipCount,
        errors: errorCount,
        total: indexesToAdd.length
    };
}

// Run migration
if (require.main === module) {
    migrate()
        .then(result => {
            if (result.errors > 0) {
                process.exit(1);
            }
            process.exit(0);
        })
        .catch(error => {
            log.error(`Migration failed: ${error.message}`);
            console.error(error);
            process.exit(1);
        });
}

module.exports = { migrate, indexesToAdd };
