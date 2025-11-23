// Database adapter for JustLayMe - supports both PostgreSQL and SQLite
const sqlite3 = require('sqlite3').verbose();
const { Pool } = require('pg');
const path = require('path');
const fs = require('fs');

class DatabaseAdapter {
    constructor() {
        this.usePostgres = process.env.DATABASE_URL && process.env.DATABASE_URL.includes('postgresql');
        
        if (this.usePostgres) {
            this.pg = new Pool({ connectionString: process.env.DATABASE_URL });
            console.log('Using PostgreSQL database');
        } else {
            this.db = new sqlite3.Database(path.join(__dirname, 'justlayme.db'));
            console.log('Using SQLite database');
            this.initSQLite();
        }
    }

    initSQLite() {
        const schema = fs.readFileSync(path.join(__dirname, 'init-sqlite.sql'), 'utf8');
        this.db.exec(schema, (err) => {
            if (err) {
                console.error('SQLite initialization error:', err);
            } else {
                console.log('SQLite database initialized');
            }
        });
    }

    async query(text, params = []) {
        if (this.usePostgres) {
            return this.pg.query(text, params);
        } else {
            return new Promise((resolve, reject) => {
                // Convert PostgreSQL syntax to SQLite
                let sqliteText = text
                    .replace(/\$(\d+)/g, '?') // Replace $1, $2 with ?
                    .replace(/UUID/g, 'TEXT') // UUID -> TEXT
                    .replace(/gen_random_uuid\(\)/g, "hex(randomblob(16))") // UUID generation
                    .replace(/NOW\(\)/g, "datetime('now')") // NOW() -> datetime('now')
                    .replace(/TIMESTAMP/g, 'TEXT') // TIMESTAMP -> TEXT
                    .replace(/BOOLEAN/g, 'INTEGER') // BOOLEAN -> INTEGER
                    .replace(/JSONB/g, 'TEXT') // JSONB -> TEXT
                    .replace(/VARCHAR\(\d+\)/g, 'TEXT') // VARCHAR(n) -> TEXT
                    .replace(/TEXT\[\]/g, 'TEXT') // Array types -> TEXT
                    .replace(/INTEGER DEFAULT false/g, 'INTEGER DEFAULT 0') // false -> 0
                    .replace(/INTEGER DEFAULT true/g, 'INTEGER DEFAULT 1') // true -> 1
                    .replace(/CREATE TABLE IF NOT EXISTS/g, 'CREATE TABLE IF NOT EXISTS'); // Keep as is

                if (text.includes('RETURNING')) {
                    // Handle RETURNING clause for SQLite
                    const returning = text.match(/RETURNING\s+(.+)$/i);
                    if (returning) {
                        sqliteText = sqliteText.replace(/\s+RETURNING\s+.+$/i, '');
                        const tableMatch = text.match(/INSERT INTO\s+(\w+)/i);
                        if (!tableMatch) {
                            reject(new Error('Could not extract table name from INSERT statement'));
                            return;
                        }
                        const tableName = tableMatch[1];
                        const dbRef = this.db; // Save reference to avoid this context issues

                        this.db.run(sqliteText, params, function(err) {
                            if (err) {
                                reject(err);
                            } else {
                                // For INSERT, get the inserted row using saved db reference
                                const lastId = this.lastID;
                                const selectQuery = `SELECT * FROM ${tableName} WHERE rowid = ?`;
                                dbRef.get(selectQuery, [lastId], (err, row) => {
                                    if (err) reject(err);
                                    else resolve({ rows: row ? [row] : [] });
                                });
                            }
                        });
                        return;
                    }
                }

                if (text.trim().toUpperCase().startsWith('SELECT')) {
                    this.db.all(sqliteText, params, (err, rows) => {
                        if (err) reject(err);
                        else resolve({ rows: rows || [] });
                    });
                } else {
                    this.db.run(sqliteText, params, function(err) {
                        if (err) reject(err);
                        else resolve({ rows: [], rowCount: this.changes });
                    });
                }
            });
        }
    }

    async close() {
        if (this.usePostgres) {
            await this.pg.end();
        } else {
            this.db.close();
        }
    }
}

module.exports = DatabaseAdapter;