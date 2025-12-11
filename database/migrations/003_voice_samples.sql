-- Voice Samples Table Migration
-- Stores user voice samples for XTTS-v2 voice cloning

CREATE TABLE IF NOT EXISTS voice_samples (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    sample_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    duration_seconds REAL,
    mime_type TEXT NOT NULL,
    language TEXT DEFAULT 'en',
    quality_score REAL,
    is_active INTEGER DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Index for fast user lookup
CREATE INDEX IF NOT EXISTS idx_voice_samples_user_id ON voice_samples(user_id);

-- Index for active samples query
CREATE INDEX IF NOT EXISTS idx_voice_samples_active ON voice_samples(user_id, is_active);

-- Index for created date sorting
CREATE INDEX IF NOT EXISTS idx_voice_samples_created ON voice_samples(created_at DESC);

-- Voice Synthesis Jobs Table
-- Tracks voice synthesis requests for monitoring and caching
CREATE TABLE IF NOT EXISTS voice_synthesis_jobs (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    voice_sample_id TEXT NOT NULL,
    text TEXT NOT NULL,
    language TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    output_file_path TEXT,
    error_message TEXT,
    processing_time_ms INTEGER,
    created_at INTEGER NOT NULL,
    completed_at INTEGER,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (voice_sample_id) REFERENCES voice_samples(id) ON DELETE CASCADE
);

-- Index for job lookup
CREATE INDEX IF NOT EXISTS idx_voice_jobs_user ON voice_synthesis_jobs(user_id, created_at DESC);

-- Index for status filtering
CREATE INDEX IF NOT EXISTS idx_voice_jobs_status ON voice_synthesis_jobs(status);

-- Voice Sample Usage Statistics
CREATE TABLE IF NOT EXISTS voice_sample_usage (
    id TEXT PRIMARY KEY,
    voice_sample_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    synthesis_count INTEGER DEFAULT 0,
    last_used_at INTEGER,
    total_characters_synthesized INTEGER DEFAULT 0,
    average_quality_score REAL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (voice_sample_id) REFERENCES voice_samples(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(voice_sample_id)
);

-- Index for usage statistics lookup
CREATE INDEX IF NOT EXISTS idx_voice_usage_sample ON voice_sample_usage(voice_sample_id);

-- Version tracking
INSERT OR REPLACE INTO schema_version (version, applied_at)
VALUES ('003_voice_samples', strftime('%s', 'now'));
