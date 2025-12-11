-- Migration 003: Vector BLOB Storage Optimization
-- Date: 2025-10-25
-- Goal: Achieve <50ms search latency through binary vector storage
--
-- Changes:
-- 1. Add embedding_blob column for binary Float32 storage
-- 2. Create optimized indexes for vector search
-- 3. Drop redundant indexes
-- 4. Set up migration tracking

-- ============================================================
-- PHASE 1: BACKUP & VERIFICATION
-- ============================================================

-- Record pre-migration state
CREATE TABLE IF NOT EXISTS vector_migration_backup (
    id INTEGER PRIMARY KEY,
    backup_timestamp INTEGER DEFAULT (strftime('%s', 'now')),
    total_records INTEGER,
    records_with_json INTEGER,
    total_json_size INTEGER,
    checksum TEXT
);

INSERT INTO vector_migration_backup (total_records, records_with_json, total_json_size, checksum)
SELECT
    COUNT(*) as total_records,
    COUNT(embedding_vector_768) as records_with_json,
    SUM(LENGTH(embedding_vector_768)) as total_json_size,
    HEX(SUM(LENGTH(embedding_vector_768))) as checksum
FROM neural_memory_embeddings;

-- ============================================================
-- PHASE 2: ADD BLOB COLUMN
-- ============================================================

-- Add binary vector storage column (3072 bytes = 768 floats * 4 bytes)
ALTER TABLE neural_memory_embeddings
ADD COLUMN embedding_blob BLOB;

-- Add migration tracking columns
ALTER TABLE neural_memory_embeddings
ADD COLUMN blob_migration_status TEXT DEFAULT 'pending';

ALTER TABLE neural_memory_embeddings
ADD COLUMN blob_migration_attempted_at INTEGER;

ALTER TABLE neural_memory_embeddings
ADD COLUMN blob_migration_completed_at INTEGER;

-- ============================================================
-- PHASE 3: CREATE OPTIMIZED INDEXES
-- ============================================================

-- Index for BLOB availability (used in WHERE clauses)
CREATE INDEX IF NOT EXISTS idx_embedding_blob_available
ON neural_memory_embeddings(user_id, character_id, blob_migration_status)
WHERE embedding_blob IS NOT NULL;

-- Composite index for vector search pattern
CREATE INDEX IF NOT EXISTS idx_vector_search_composite
ON neural_memory_embeddings(
    user_id,
    character_id,
    importance_score DESC,
    decay_factor DESC,
    last_accessed DESC
)
WHERE embedding_blob IS NOT NULL;

-- Covering index for metadata-only queries (avoids table lookup)
CREATE INDEX IF NOT EXISTS idx_memory_metadata_covering
ON neural_memory_embeddings(
    user_id,
    character_id,
    id,
    importance_score,
    created_at,
    last_accessed,
    blob_migration_status
)
WHERE embedding_blob IS NOT NULL;

-- Partial index for recent high-value memories (fast path)
CREATE INDEX IF NOT EXISTS idx_recent_important_memories
ON neural_memory_embeddings(user_id, character_id, id, importance_score)
WHERE embedding_blob IS NOT NULL
    AND importance_score >= 0.5
    AND created_at >= strftime('%s', 'now') - 2592000; -- Last 30 days

-- ============================================================
-- PHASE 4: DROP REDUNDANT INDEXES
-- ============================================================

-- These indexes are now redundant with composite indexes
DROP INDEX IF EXISTS idx_neural_memory_user_importance;
DROP INDEX IF EXISTS idx_neural_user_importance;
DROP INDEX IF EXISTS idx_neural_importance_search;

-- ============================================================
-- PHASE 5: DATABASE OPTIMIZATION
-- ============================================================

-- Ensure WAL mode for concurrent reads during migration
PRAGMA journal_mode=WAL;

-- Increase cache size for better performance (128MB)
PRAGMA cache_size=-128000;

-- Optimize page size for BLOB storage (larger pages = fewer I/O)
-- Note: Only applies to new databases or after VACUUM
PRAGMA page_size=8192;

-- Enable memory-mapped I/O (512MB)
PRAGMA mmap_size=536870912;

-- Analyze table statistics for query optimizer
ANALYZE neural_memory_embeddings;

-- ============================================================
-- PHASE 6: CREATE MIGRATION TRACKING VIEW
-- ============================================================

CREATE VIEW IF NOT EXISTS blob_migration_progress AS
SELECT
    blob_migration_status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM neural_memory_embeddings), 2) as percentage,
    AVG(CASE
        WHEN blob_migration_completed_at IS NOT NULL AND blob_migration_attempted_at IS NOT NULL
        THEN blob_migration_completed_at - blob_migration_attempted_at
        ELSE NULL
    END) as avg_time_seconds
FROM neural_memory_embeddings
GROUP BY blob_migration_status
ORDER BY count DESC;

-- ============================================================
-- PHASE 7: VERIFICATION QUERIES
-- ============================================================

-- View to verify migration integrity
CREATE VIEW IF NOT EXISTS blob_migration_verification AS
SELECT
    (SELECT COUNT(*) FROM neural_memory_embeddings) as total_records,
    (SELECT COUNT(*) FROM neural_memory_embeddings WHERE embedding_vector_768 IS NOT NULL) as json_vectors,
    (SELECT COUNT(*) FROM neural_memory_embeddings WHERE embedding_blob IS NOT NULL) as blob_vectors,
    (SELECT COUNT(*) FROM neural_memory_embeddings
     WHERE embedding_vector_768 IS NOT NULL AND embedding_blob IS NULL) as pending_conversion,
    (SELECT COUNT(*) FROM neural_memory_embeddings
     WHERE embedding_vector_768 IS NOT NULL AND embedding_blob IS NOT NULL) as completed_conversion,
    (SELECT SUM(LENGTH(embedding_vector_768)) FROM neural_memory_embeddings) as total_json_bytes,
    (SELECT SUM(LENGTH(embedding_blob)) FROM neural_memory_embeddings) as total_blob_bytes,
    ROUND((SELECT SUM(LENGTH(embedding_vector_768)) FROM neural_memory_embeddings) * 1.0 /
          NULLIF((SELECT SUM(LENGTH(embedding_blob)) FROM neural_memory_embeddings), 0), 2) as compression_ratio;

-- ============================================================
-- PHASE 8: UPDATE MIGRATION AUDIT
-- ============================================================

INSERT INTO migration_audit (
    migration_name,
    status,
    total_records,
    checksum_before
)
SELECT
    '003_vector_blob_optimization',
    'schema_ready',
    COUNT(*),
    HEX(GROUP_CONCAT(id || ':' || COALESCE(LENGTH(embedding_vector_768), 0)))
FROM neural_memory_embeddings;

-- ============================================================
-- VERIFICATION INSTRUCTIONS
-- ============================================================

-- Run these queries after schema migration:

-- 1. Check migration progress
-- SELECT * FROM blob_migration_progress;

-- 2. Verify data integrity
-- SELECT * FROM blob_migration_verification;

-- 3. Check index usage
-- EXPLAIN QUERY PLAN
-- SELECT id, memory_content, importance_score
-- FROM neural_memory_embeddings
-- WHERE user_id = 1 AND character_id = 'test' AND embedding_blob IS NOT NULL
-- ORDER BY importance_score DESC
-- LIMIT 10;

-- 4. Verify backup
-- SELECT * FROM vector_migration_backup;

-- ============================================================
-- ROLLBACK SCRIPT
-- ============================================================

-- To rollback this migration (EMERGENCY USE ONLY):
--
-- ALTER TABLE neural_memory_embeddings DROP COLUMN embedding_blob;
-- ALTER TABLE neural_memory_embeddings DROP COLUMN blob_migration_status;
-- ALTER TABLE neural_memory_embeddings DROP COLUMN blob_migration_attempted_at;
-- ALTER TABLE neural_memory_embeddings DROP COLUMN blob_migration_completed_at;
-- DROP INDEX IF EXISTS idx_embedding_blob_available;
-- DROP INDEX IF EXISTS idx_vector_search_composite;
-- DROP INDEX IF EXISTS idx_memory_metadata_covering;
-- DROP INDEX IF EXISTS idx_recent_important_memories;
-- DROP VIEW IF EXISTS blob_migration_progress;
-- DROP VIEW IF EXISTS blob_migration_verification;
-- DROP TABLE IF EXISTS vector_migration_backup;
-- UPDATE migration_audit SET status = 'rolled_back', completed_at = strftime('%s', 'now')
-- WHERE migration_name = '003_vector_blob_optimization';

-- ============================================================
-- MIGRATION COMPLETE
-- ============================================================
-- Next step: Run migration script (migrate-vectors-to-blob.js)
