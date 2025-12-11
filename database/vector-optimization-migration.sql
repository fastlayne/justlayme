-- ============================================================================
-- VECTOR STORAGE OPTIMIZATION MIGRATION
-- ============================================================================
-- Goal: Reduce storage by 81% and achieve <50ms search latency
-- Current: 768-dim vectors as JSON TEXT (~16KB each)
-- Target: Binary BLOB storage (~3KB each) + SQL-optimized similarity
-- ============================================================================

BEGIN TRANSACTION;

-- Step 1: Add BLOB column for optimized vector storage
-- Stores 768 floats as 3072 bytes (768 * 4 bytes per float32)
ALTER TABLE neural_memory_embeddings
ADD COLUMN embedding_blob BLOB;

-- Step 2: Create optimized indexes for vector search patterns
-- These indexes support fast pre-filtering before similarity computation

-- Index for user + migration status filtering
CREATE INDEX IF NOT EXISTS idx_user_blob_ready
ON neural_memory_embeddings(user_id, decay_factor, importance_score DESC)
WHERE embedding_blob IS NOT NULL;

-- Index for character-specific searches
CREATE INDEX IF NOT EXISTS idx_character_blob_ready
ON neural_memory_embeddings(character_id, user_id, importance_score DESC)
WHERE embedding_blob IS NOT NULL;

-- Index for temporal filtering (recent memories)
CREATE INDEX IF NOT EXISTS idx_temporal_search
ON neural_memory_embeddings(user_id, created_at DESC, importance_score DESC)
WHERE embedding_blob IS NOT NULL AND decay_factor >= 0.1;

-- Index for candidate pre-selection by importance
CREATE INDEX IF NOT EXISTS idx_importance_candidates
ON neural_memory_embeddings(user_id, importance_score DESC, last_accessed DESC)
WHERE embedding_blob IS NOT NULL;

-- Step 3: Create materialized view for frequently accessed memories
-- Precomputes top candidates for fast first-stage filtering
CREATE TABLE IF NOT EXISTS mv_top_memories AS
SELECT
    user_id,
    character_id,
    id,
    importance_score,
    relevance_score,
    decay_factor,
    created_at,
    last_accessed,
    -- Precompute combined ranking score
    (importance_score * 0.4 +
     relevance_score * 0.3 +
     decay_factor * 0.2 +
     (1.0 / (1 + (strftime('%s', 'now') - last_accessed) / 86400.0)) * 0.1) as precomputed_rank
FROM neural_memory_embeddings
WHERE embedding_blob IS NOT NULL
  AND decay_factor >= 0.1
ORDER BY user_id, precomputed_rank DESC;

-- Index on materialized view for fast lookups
CREATE INDEX IF NOT EXISTS idx_mv_top_memories_user
ON mv_top_memories(user_id, precomputed_rank DESC);

CREATE INDEX IF NOT EXISTS idx_mv_top_memories_character
ON mv_top_memories(user_id, character_id, precomputed_rank DESC);

-- Step 4: Create trigger to maintain materialized view
-- Automatically updates when embeddings change
CREATE TRIGGER IF NOT EXISTS trg_refresh_top_memories_insert
AFTER INSERT ON neural_memory_embeddings
WHEN NEW.embedding_blob IS NOT NULL
BEGIN
    INSERT INTO mv_top_memories (user_id, character_id, id, importance_score,
                                  relevance_score, decay_factor, created_at,
                                  last_accessed, precomputed_rank)
    VALUES (
        NEW.user_id,
        NEW.character_id,
        NEW.id,
        NEW.importance_score,
        NEW.relevance_score,
        NEW.decay_factor,
        NEW.created_at,
        NEW.last_accessed,
        (NEW.importance_score * 0.4 +
         NEW.relevance_score * 0.3 +
         NEW.decay_factor * 0.2 +
         (1.0 / (1 + (strftime('%s', 'now') - NEW.last_accessed) / 86400.0)) * 0.1)
    );
END;

CREATE TRIGGER IF NOT EXISTS trg_refresh_top_memories_update
AFTER UPDATE ON neural_memory_embeddings
WHEN NEW.embedding_blob IS NOT NULL
BEGIN
    DELETE FROM mv_top_memories WHERE id = NEW.id;
    INSERT INTO mv_top_memories (user_id, character_id, id, importance_score,
                                  relevance_score, decay_factor, created_at,
                                  last_accessed, precomputed_rank)
    VALUES (
        NEW.user_id,
        NEW.character_id,
        NEW.id,
        NEW.importance_score,
        NEW.relevance_score,
        NEW.decay_factor,
        NEW.created_at,
        NEW.last_accessed,
        (NEW.importance_score * 0.4 +
         NEW.relevance_score * 0.3 +
         NEW.decay_factor * 0.2 +
         (1.0 / (1 + (strftime('%s', 'now') - NEW.last_accessed) / 86400.0)) * 0.1)
    );
END;

CREATE TRIGGER IF NOT EXISTS trg_refresh_top_memories_delete
AFTER DELETE ON neural_memory_embeddings
BEGIN
    DELETE FROM mv_top_memories WHERE id = OLD.id;
END;

-- Step 5: Create statistics table for query performance tracking
CREATE TABLE IF NOT EXISTS vector_search_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER DEFAULT (strftime('%s', 'now')),
    user_id INTEGER,
    query_type TEXT, -- 'cached', 'optimized', 'fallback'
    latency_ms REAL,
    candidates_scanned INTEGER,
    results_returned INTEGER,
    cache_hit BOOLEAN DEFAULT 0
);

-- Index for analytics queries
CREATE INDEX IF NOT EXISTS idx_search_stats_timestamp
ON vector_search_stats(timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_search_stats_user
ON vector_search_stats(user_id, timestamp DESC);

-- Step 6: Create helper view for monitoring vector storage efficiency
CREATE VIEW IF NOT EXISTS v_vector_storage_stats AS
SELECT
    COUNT(*) as total_vectors,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT character_id) as unique_characters,
    COUNT(CASE WHEN embedding_blob IS NOT NULL THEN 1 END) as blob_vectors,
    COUNT(CASE WHEN embedding_vector_768 IS NOT NULL THEN 1 END) as text_vectors,
    ROUND(AVG(LENGTH(embedding_vector_768)), 0) as avg_text_size_bytes,
    ROUND(AVG(LENGTH(embedding_blob)), 0) as avg_blob_size_bytes,
    ROUND(
        (1.0 - AVG(LENGTH(embedding_blob)) * 1.0 / AVG(LENGTH(embedding_vector_768))) * 100,
        2
    ) as storage_reduction_percent,
    AVG(importance_score) as avg_importance,
    AVG(decay_factor) as avg_decay_factor
FROM neural_memory_embeddings
WHERE embedding_vector_768 IS NOT NULL OR embedding_blob IS NOT NULL;

COMMIT;

-- ============================================================================
-- USAGE NOTES:
-- ============================================================================
-- 1. Run this migration: sqlite3 justlayme.db < vector-optimization-migration.sql
-- 2. Convert existing vectors: Use migrate-vectors-to-blob.js script
-- 3. Deploy optimized search: Use optimized-vector-search.js class
-- 4. Monitor performance: SELECT * FROM v_vector_storage_stats;
-- 5. Drop old column after verification: ALTER TABLE neural_memory_embeddings DROP COLUMN embedding_vector_768;
-- ============================================================================
