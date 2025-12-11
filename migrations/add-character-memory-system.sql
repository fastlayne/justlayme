-- ============================================================================
-- Character Memory System Migration
-- ============================================================================
-- This migration adds support for character-specific memories and learning
-- Characters will remember important facts, preferences, and events about users
-- ============================================================================

-- Character Interaction Memories Table
CREATE TABLE IF NOT EXISTS character_interaction_memories (
    id TEXT PRIMARY KEY,
    character_id TEXT NOT NULL,
    user_id INTEGER NOT NULL,
    conversation_id TEXT NOT NULL,
    memory_type TEXT NOT NULL CHECK(memory_type IN ('fact', 'preference', 'event', 'emotion')),
    memory_content TEXT NOT NULL,
    importance_score REAL DEFAULT 0.5 CHECK(importance_score >= 0 AND importance_score <= 1),
    mentioned_count INTEGER DEFAULT 1,
    last_accessed TEXT DEFAULT (datetime('now')),
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (character_id) REFERENCES custom_characters(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
);

-- Indexes for fast memory retrieval
CREATE INDEX IF NOT EXISTS idx_char_memories_char_user
ON character_interaction_memories(character_id, user_id, importance_score DESC);

CREATE INDEX IF NOT EXISTS idx_char_memories_access
ON character_interaction_memories(last_accessed DESC);

CREATE INDEX IF NOT EXISTS idx_char_memories_type
ON character_interaction_memories(memory_type, character_id);

-- ============================================================================
-- Character Evolution Tracking Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS character_evolution_tracking (
    id TEXT PRIMARY KEY,
    character_id TEXT NOT NULL,
    user_id INTEGER NOT NULL,
    evolution_type TEXT CHECK(evolution_type IN ('personality_shift', 'new_trait', 'refined_speech', 'interest_developed')),
    description TEXT NOT NULL,
    impact_level REAL DEFAULT 0.5 CHECK(impact_level >= 0 AND impact_level <= 1),
    interaction_count INTEGER DEFAULT 0,
    applied INTEGER DEFAULT 0, -- 0 = suggested, 1 = applied
    created_at TEXT DEFAULT (datetime('now')),
    applied_at TEXT,
    FOREIGN KEY (character_id) REFERENCES custom_characters(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_char_evolution_char
ON character_evolution_tracking(character_id, user_id, created_at DESC);

-- ============================================================================
-- Character Relationships Graph Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS character_relationships_graph (
    id TEXT PRIMARY KEY,
    character_a_id TEXT NOT NULL,
    character_b_id TEXT NOT NULL,
    relationship_type TEXT NOT NULL,
    relationship_description TEXT,
    user_id INTEGER NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (character_a_id) REFERENCES custom_characters(id) ON DELETE CASCADE,
    FOREIGN KEY (character_b_id) REFERENCES custom_characters(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(character_a_id, character_b_id, user_id),
    CHECK(character_a_id != character_b_id)
);

CREATE INDEX IF NOT EXISTS idx_char_relationships
ON character_relationships_graph(user_id, character_a_id);

CREATE INDEX IF NOT EXISTS idx_char_relationships_b
ON character_relationships_graph(user_id, character_b_id);

-- ============================================================================
-- The Grey Mirror Analysis History Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS black_mirror_analyses (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    conversation_id TEXT NOT NULL,
    health_score REAL,
    sentiment_score REAL,
    toxicity_score REAL,
    engagement_level TEXT,
    communication_balance REAL,
    total_messages INTEGER,
    user_messages INTEGER,
    assistant_messages INTEGER,
    full_report TEXT,
    recommendations TEXT, -- JSON array of recommendations
    analysis_date TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_black_mirror_user_conv
ON black_mirror_analyses(user_id, conversation_id, analysis_date DESC);

CREATE INDEX IF NOT EXISTS idx_black_mirror_health
ON black_mirror_analyses(conversation_id, health_score DESC);

-- ============================================================================
-- Memory Decay and Importance Adjustment Functions (via triggers)
-- ============================================================================

-- Trigger to increment mentioned_count and boost importance when memory is accessed
CREATE TRIGGER IF NOT EXISTS memory_access_boost
AFTER UPDATE OF last_accessed ON character_interaction_memories
FOR EACH ROW
BEGIN
    UPDATE character_interaction_memories
    SET
        mentioned_count = mentioned_count + 1,
        importance_score = MIN(1.0, importance_score + 0.05)
    WHERE id = NEW.id;
END;

-- ============================================================================
-- Initial Data / Examples (Optional)
-- ============================================================================

-- Example memory types documentation
INSERT OR IGNORE INTO character_interaction_memories
(id, character_id, user_id, conversation_id, memory_type, memory_content, importance_score)
VALUES
('example_memory_1', 'example_char', 0, 'example_conv', 'fact', 'This is an example memory - delete this row', 0.1);

-- Clean up example data
DELETE FROM character_interaction_memories WHERE id = 'example_memory_1';

-- ============================================================================
-- Migration Complete
-- ============================================================================
-- Tables Created:
--   - character_interaction_memories (stores character memories)
--   - character_evolution_tracking (tracks character personality changes)
--   - character_relationships_graph (defines relationships between characters)
--   - black_mirror_analyses (stores historical analysis results)
--
-- Indexes Created:
--   - Optimized for memory retrieval by character+user
--   - Optimized for analysis history queries
--   - Optimized for relationship lookups
--
-- Triggers Created:
--   - memory_access_boost (increases importance when memory is used)
-- ============================================================================
