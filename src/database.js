// Database adapter for JustLayMe - supports both PostgreSQL and SQLite
const sqlite3 = require('sqlite3').verbose();
const { Pool } = require('pg');
const path = require('path');
const fs = require('fs');

// Singleton instance storage
let databaseInstance = null;

class DatabaseAdapter {
    constructor() {
        // Implement singleton pattern to prevent file descriptor leaks
        if (databaseInstance) {
            return databaseInstance;
        }
        this.usePostgres = process.env.DATABASE_URL && process.env.DATABASE_URL.includes('postgresql');
        
        // Security monitoring
        this.securityMetrics = {
            totalQueries: 0,
            failedQueries: 0,
            suspiciousQueries: 0,
            blockedQueries: 0,
            startTime: Date.now()
        };
        
        if (this.usePostgres) {
            // Configure secure PostgreSQL connection
            const config = { 
                connectionString: process.env.DATABASE_URL,
                // SSL configuration for production security
                ssl: process.env.NODE_ENV === 'production' ? {
                    rejectUnauthorized: true,
                    ca: process.env.DATABASE_CA_CERT,
                    cert: process.env.DATABASE_CLIENT_CERT,
                    key: process.env.DATABASE_CLIENT_KEY,
                    // Fallback for managed databases that don't require cert validation
                    ...(process.env.DATABASE_SSL_MODE === 'require' && { rejectUnauthorized: false })
                } : false,
                // Connection pool security settings
                max: 10,
                idleTimeoutMillis: 30000,
                connectionTimeoutMillis: 5000,
                maxUses: 7500,
                // Application identification for monitoring
                application_name: 'JustLayme_Secure',
                // Query timeout for security
                query_timeout: 30000,
                statement_timeout: 30000
            };
            
            this.pg = new Pool(config);
            console.log('Using PostgreSQL database with security configuration');
        } else {
            this.db = new sqlite3.Database(path.join(__dirname, '../database/justlayme.db'));
            console.log('Using SQLite database (singleton instance)');
            this.initSQLite();
        }

        // Store the singleton instance
        databaseInstance = this;
    }

    initSQLite() {
        // CRITICAL: Enable foreign keys for data integrity
        this.db.run('PRAGMA foreign_keys = ON', (err) => {
            if (err) {
                console.error('❌ CRITICAL: Failed to enable foreign keys:', err);
                throw new Error('Database initialization failed: Foreign keys could not be enabled');
            } else {
                // Verify foreign keys are actually enabled
                this.db.get('PRAGMA foreign_keys', (err, row) => {
                    if (err) {
                        console.error('❌ CRITICAL: Failed to verify foreign keys:', err);
                    } else if (row && row.foreign_keys === 1) {
                        console.log('✅ Foreign keys ENABLED - Data integrity enforced');
                    } else {
                        console.error('❌ CRITICAL: Foreign keys are DISABLED - Data integrity at risk!');
                        throw new Error('Foreign keys verification failed');
                    }
                });
            }
        });

        const schema = fs.readFileSync(path.join(__dirname, '../database/init-sqlite.sql'), 'utf8');
        this.db.exec(schema, (err) => {
            if (err) {
                console.error('SQLite initialization error:', err);
            } else {
                console.log('SQLite database initialized');
            }
        });
    }

    async query(text, params = []) {
        const queryStart = Date.now();
        this.securityMetrics.totalQueries++;
        
        // Input validation and SQL injection prevention
        if (!text || typeof text !== 'string') {
            this.securityMetrics.failedQueries++;
            throw new Error('Query text must be a non-empty string');
        }
        
        // Ensure params is an array
        if (!Array.isArray(params)) {
            this.securityMetrics.failedQueries++;
            throw new Error('Query parameters must be an array');
        }
        
        // Security monitoring - detect suspicious patterns
        const suspiciousPatterns = [
            /;\s*DROP\s+/i, /;\s*DELETE\s+FROM\s+/i, /;\s*UPDATE\s+/i,
            /UNION\s+SELECT/i, /EXEC\s*\(/i, /EXECUTE\s*\(/i,
            /INSERT\s+INTO.*SELECT/i, /LOAD_FILE\s*\(/i
        ];
        
        for (const pattern of suspiciousPatterns) {
            if (pattern.test(text)) {
                this.securityMetrics.suspiciousQueries++;
                console.warn('⚠️ SECURITY: Suspicious SQL pattern detected:', {
                    pattern: pattern.toString(),
                    query_preview: text.substring(0, 100) + '...',
                    timestamp: new Date().toISOString()
                });
                break;
            }
        }
        
        // Validate parameter count matches placeholders for PostgreSQL
        if (this.usePostgres) {
            const paramMatches = text.match(/\$\d+/g);
            const expectedParamCount = paramMatches ? Math.max(...paramMatches.map(p => parseInt(p.substring(1)))) : 0;
            if (params.length < expectedParamCount) {
                throw new Error(`Parameter count mismatch: expected ${expectedParamCount}, got ${params.length}`);
            }
        }
        
        // Validate parameter types for security
        for (let i = 0; i < params.length; i++) {
            const param = params[i];
            // Allow null, undefined, numbers, strings, booleans, and Dates
            if (param !== null && param !== undefined && 
                typeof param !== 'string' && typeof param !== 'number' && 
                typeof param !== 'boolean' && !(param instanceof Date)) {
                throw new Error(`Invalid parameter type at index ${i}: ${typeof param}`);
            }
        }
        
        // Use parameters directly - parameterized queries are safe from SQL injection
        
        // Access control validation - block dangerous operations without proper context
        if (!this.isOperationAllowed(text, params)) {
            this.securityMetrics.blockedQueries++;
            throw new Error('Access denied: Operation not permitted');
        }

        if (this.usePostgres) {
            try {
                return await this.pg.query(text, params);
            } catch (error) {
                console.error('PostgreSQL query error:', error.message, { query: text.substring(0, 100) });
                throw error;
            }
        } else {
            return new Promise((resolve, reject) => {
                try {
                    // Enhanced PostgreSQL to SQLite conversion with type safety
                    let sqliteText = text
                        .replace(/\$(\d+)/g, '?') // Replace $1, $2 with ?
                        .replace(/\bUUID\b/gi, 'TEXT') // UUID -> TEXT (word boundary to avoid partial matches)
                        .replace(/gen_random_uuid\(\)/gi, "hex(randomblob(16))") // UUID generation
                        .replace(/DEFAULT\s+NOW\(\)/gi, "DEFAULT (datetime('now'))") // DEFAULT NOW() with parentheses
                        .replace(/DEFAULT\s+CURRENT_TIMESTAMP/gi, "DEFAULT (datetime('now'))") // DEFAULT CURRENT_TIMESTAMP
                        .replace(/NOW\(\)/gi, "datetime('now')") // NOW() -> datetime('now')
                        .replace(/CURRENT_TIMESTAMP/gi, "datetime('now')") // CURRENT_TIMESTAMP
                        .replace(/NOW\(\)\s*-\s*INTERVAL\s+'(\d+)\s+days?'/gi, "datetime('now', '-$1 days')") // NOW() - INTERVAL 'N days'
                        .replace(/NOW\(\)\s*-\s*INTERVAL\s+'(\d+)\s+hours?'/gi, "datetime('now', '-$1 hours')") // NOW() - INTERVAL 'N hours'
                        .replace(/NOW\(\)\s*-\s*INTERVAL\s+'(\d+)\s+hour'/gi, "datetime('now', '-$1 hours')") // NOW() - INTERVAL 'N hour' (singular)
                        .replace(/NOW\(\)\s*\+\s*INTERVAL\s+'(\d+)\s+days?'/gi, "datetime('now', '+$1 days')") // NOW() + INTERVAL 'N days'
                        .replace(/NOW\(\)\s*\+\s*INTERVAL\s+'(\d+)\s+hours?'/gi, "datetime('now', '+$1 hours')") // NOW() + INTERVAL 'N hours'
                        .replace(/NOW\(\)\s*\+\s*INTERVAL\s+'(\d+)\s+hour'/gi, "datetime('now', '+$1 hours')") // NOW() + INTERVAL 'N hour' (singular)
                        .replace(/NOW\(\)\s*\+\s*INTERVAL\s+'24\s+hours?'/gi, "datetime('now', '+24 hours')") // NOW() + INTERVAL '24 hours' (specific case)
                        .replace(/(\w+)::date/gi, 'DATE($1)') // PostgreSQL date casting to SQLite DATE function
                        .replace(/TIMESTAMP\s+WITH\s+TIME\s+ZONE/gi, 'TEXT') // TIMESTAMPTZ -> TEXT
                        .replace(/TIMESTAMP/gi, 'TEXT') // TIMESTAMP -> TEXT
                        .replace(/BOOLEAN/gi, 'INTEGER') // BOOLEAN -> INTEGER
                        .replace(/\bFLOAT\b/gi, 'REAL') // FLOAT -> REAL
                        .replace(/JSONB/gi, 'TEXT') // JSONB -> TEXT
                        .replace(/JSON/gi, 'TEXT') // JSON -> TEXT
                        .replace(/VARCHAR\(\d+\)/gi, 'TEXT') // VARCHAR(n) -> TEXT
                        .replace(/CHAR\(\d+\)/gi, 'TEXT') // CHAR(n) -> TEXT
                        .replace(/TEXT\[\]/gi, 'TEXT') // Array types -> TEXT
                        .replace(/INTEGER\[\]/gi, 'TEXT') // Integer arrays -> TEXT
                        .replace(/INTEGER DEFAULT false/gi, 'INTEGER DEFAULT 0') // false -> 0
                        .replace(/INTEGER DEFAULT true/gi, 'INTEGER DEFAULT 1') // true -> 1
                        .replace(/SERIAL\s+PRIMARY\s+KEY/gi, 'INTEGER PRIMARY KEY AUTOINCREMENT') // SERIAL PRIMARY KEY
                        .replace(/BIGSERIAL\s+PRIMARY\s+KEY/gi, 'INTEGER PRIMARY KEY AUTOINCREMENT') // BIGSERIAL PRIMARY KEY
                        .replace(/SERIAL/gi, 'INTEGER AUTOINCREMENT') // SERIAL -> AUTOINCREMENT
                        .replace(/BIGSERIAL/gi, 'INTEGER AUTOINCREMENT') // BIGSERIAL
                        .replace(/ON CONFLICT\s*\([^)]+\)\s*DO\s*UPDATE/gi, 'ON CONFLICT DO UPDATE') // Simplify conflicts
                        .replace(/LIMIT\s+ALL/gi, '') // Remove LIMIT ALL
                        .replace(/OFFSET\s+0/gi, ''); // Remove OFFSET 0

                    // Handle RETURNING clause for SQLite
                    if (text.includes('RETURNING')) {
                        const returning = text.match(/RETURNING\s+(.+)$/i);
                        if (returning) {
                            sqliteText = sqliteText.replace(/\s+RETURNING\s+.+$/i, '');
                            
                            const dbInstance = this.db; // Capture database instance
                            dbInstance.run(sqliteText, params, function(err) {
                                if (err) {
                                    console.error('SQLite RETURNING query error:', {
                                        message: err.message,
                                        query_preview: sqliteText.substring(0, 50) + '...'
                                    });
                                    const sanitizedError = new Error('Database query failed');
                                    sanitizedError.code = err.code;
                                    reject(sanitizedError);
                                } else {
                                    const insertId = this.lastID; // Capture lastID in proper context
                                    const changeCount = this.changes;
                                    
                                    // For INSERT, get the inserted row with proper table name extraction
                                    const tableMatch = text.match(/INSERT\s+INTO\s+["`]?([a-zA-Z_][a-zA-Z0-9_]*)["`]?/i);
                                    if (tableMatch && insertId) {
                                        const tableName = tableMatch[1];
                                        // Use double quotes for table names to handle reserved words
                                        const selectQuery = `SELECT * FROM "${tableName}" WHERE rowid = ?`;
                                        dbInstance.get(selectQuery, [insertId], (err, row) => {
                                            if (err) {
                                                console.error('SQLite SELECT after INSERT error:', err.message);
                                                const sanitizedError = new Error('Database query failed');
                                                sanitizedError.code = err.code;
                                                reject(sanitizedError);
                                            } else {
                                                resolve({ rows: row ? [row] : [], rowCount: 1, lastID: insertId });
                                            }
                                        });
                                    } else {
                                        resolve({ rows: [], rowCount: changeCount || 0, lastID: insertId });
                                    }
                                }
                            });
                            return;
                        }
                    }

                    // Execute query based on type
                    const upperText = text.trim().toUpperCase();
                    if (upperText.startsWith('SELECT') || upperText.startsWith('WITH') || upperText.startsWith('PRAGMA')) {
                        this.db.all(sqliteText, params, (err, rows) => {
                            if (err) {
                                console.error('SQLite SELECT query error:', {
                                    message: err.message,
                                    query_preview: sqliteText.substring(0, 50) + '...'
                                });
                                const sanitizedError = new Error('Database query failed');
                                sanitizedError.code = err.code;
                                reject(sanitizedError);
                            } else {
                                resolve({ rows: rows || [], rowCount: (rows || []).length });
                            }
                        });
                    } else {
                        this.db.run(sqliteText, params, function(err) {
                            if (err) {
                                console.error('SQLite modification query error:', {
                                    message: err.message,
                                    query_preview: sqliteText.substring(0, 50) + '...'
                                });
                                const sanitizedError = new Error('Database query failed');
                                sanitizedError.code = err.code;
                                reject(sanitizedError);
                            } else {
                                resolve({ 
                                    rows: [], 
                                    rowCount: this.changes || 0, 
                                    lastID: this.lastID,
                                    command: upperText.split(' ')[0]
                                });
                            }
                        });
                    }
                } catch (error) {
                    console.error('Database query processing error:', error.message);
                    reject(error);
                }
            });
        }
    }

    getSecurityMetrics() {
        const uptime = Date.now() - this.securityMetrics.startTime;
        return {
            ...this.securityMetrics,
            uptime: uptime,
            queriesPerSecond: this.securityMetrics.totalQueries / (uptime / 1000),
            failureRate: this.securityMetrics.failedQueries / this.securityMetrics.totalQueries,
            suspiciousRate: this.securityMetrics.suspiciousQueries / this.securityMetrics.totalQueries
        };
    }

    isOperationAllowed(text, params) {
        const upperText = text.trim().toUpperCase();
        
        // Block certain dangerous operations completely
        const blockedPatterns = [
            /DROP\s+TABLE/i, /DROP\s+DATABASE/i, /DROP\s+SCHEMA/i,
            /ALTER\s+TABLE.*DROP/i, /TRUNCATE\s+TABLE/i,
            /GRANT\s+/i, /REVOKE\s+/i,
            /CREATE\s+USER/i, /DROP\s+USER/i,
            /LOAD\s+DATA/i, /SELECT\s+.*INTO\s+OUTFILE/i
        ];
        
        for (const pattern of blockedPatterns) {
            if (pattern.test(text)) {
                console.warn('🚫 SECURITY: Blocked dangerous operation:', {
                    operation: pattern.toString(),
                    query_preview: text.substring(0, 100) + '...',
                    timestamp: new Date().toISOString()
                });
                return false;
            }
        }
        
        // Allow all other operations (they should already be parameterized and safe)
        return true;
    }

    // Transaction support (simplified - executes queries sequentially)
    async transaction(callback) {
        // For SQLite, we'll use BEGIN/COMMIT/ROLLBACK
        // For PostgreSQL, we'd need a client from the pool

        if (this.usePostgres) {
            const client = await this.pg.connect();
            try {
                await client.query('BEGIN');

                // Create a query function that uses the client
                const queryFn = (text, params) => client.query(text, params);

                // Execute the callback with the query function
                await callback(queryFn);

                await client.query('COMMIT');
            } catch (error) {
                await client.query('ROLLBACK');
                throw error;
            } finally {
                client.release();
            }
        } else {
            // SQLite transaction handling
            return new Promise((resolve, reject) => {
                this.db.serialize(() => {
                    this.db.run('BEGIN TRANSACTION', (err) => {
                        if (err) {
                            reject(err);
                            return;
                        }

                        // Create a query function for SQLite
                        const queryFn = (text, params) => {
                            return this.query(text, params);
                        };

                        // Execute the callback
                        Promise.resolve(callback(queryFn))
                            .then(() => {
                                this.db.run('COMMIT', (err) => {
                                    if (err) {
                                        this.db.run('ROLLBACK');
                                        reject(err);
                                    } else {
                                        resolve();
                                    }
                                });
                            })
                            .catch((error) => {
                                this.db.run('ROLLBACK', () => {
                                    reject(error);
                                });
                            });
                    });
                });
            });
        }
    }

    // Static method to get singleton instance
    static getInstance() {
        if (!databaseInstance) {
            databaseInstance = new DatabaseAdapter();
        }
        return databaseInstance;
    }

    // Static method to reset singleton (for testing or forced reconnection)
    static resetInstance() {
        if (databaseInstance) {
            databaseInstance.close();
            databaseInstance = null;
        }
    }

    // Get database-specific current timestamp function
    // This prevents hardcoding database-specific SQL in application code
    getCurrentTimestamp() {
        return this.usePostgres ? "NOW()" : "datetime('now')";
    }

    async close() {
        if (this.usePostgres) {
            await this.pg.end();
        } else {
            this.db.close();
        }
        // Clear the singleton instance when closing
        if (databaseInstance === this) {
            databaseInstance = null;
        }
    }
}

module.exports = DatabaseAdapter;