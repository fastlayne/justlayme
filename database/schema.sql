-- JustLayMe Database Schema with Chat History

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    username VARCHAR(100) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    subscription_tier VARCHAR(50) DEFAULT 'free',
    context_limit INTEGER DEFAULT 8192
);

-- Characters table
CREATE TABLE IF NOT EXISTS characters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    personality TEXT,
    backstory TEXT,
    traits JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);

-- Chat sessions table
CREATE TABLE IF NOT EXISTS chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    character_id UUID REFERENCES characters(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_message_at TIMESTAMP,
    title VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    context_window INTEGER DEFAULT 8192
);

-- Chat messages table with vector embeddings for semantic search
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES chat_sessions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    token_count INTEGER,
    embedding VECTOR(384), -- For semantic search with all-MiniLM-L6-v2
    importance_score FLOAT DEFAULT 0.5
);

-- Context summaries for long conversations
CREATE TABLE IF NOT EXISTS context_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES chat_sessions(id) ON DELETE CASCADE,
    summary TEXT NOT NULL,
    message_range INT4RANGE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    token_count INTEGER
);

-- User preferences
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    theme VARCHAR(20) DEFAULT 'dark',
    auto_save BOOLEAN DEFAULT true,
    context_mode VARCHAR(20) DEFAULT 'adaptive', -- 'full', 'sliding', 'adaptive'
    max_context_tokens INTEGER DEFAULT 8192,
    summary_threshold INTEGER DEFAULT 4096
);

-- Indexes for performance
CREATE INDEX idx_messages_session ON chat_messages(session_id, created_at DESC);
CREATE INDEX idx_messages_user ON chat_messages(user_id, created_at DESC);
CREATE INDEX idx_sessions_user ON chat_sessions(user_id, last_message_at DESC);
CREATE INDEX idx_messages_embedding ON chat_messages USING ivfflat (embedding vector_cosine_ops);

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Function to get conversation context
CREATE OR REPLACE FUNCTION get_context_messages(
    p_session_id UUID,
    p_max_tokens INTEGER DEFAULT 8192
) RETURNS TABLE (
    id UUID,
    role VARCHAR,
    content TEXT,
    created_at TIMESTAMP,
    token_count INTEGER
) AS $$
DECLARE
    v_total_tokens INTEGER := 0;
BEGIN
    RETURN QUERY
    WITH recent_messages AS (
        SELECT 
            m.id,
            m.role,
            m.content,
            m.created_at,
            m.token_count,
            m.importance_score
        FROM chat_messages m
        WHERE m.session_id = p_session_id
        ORDER BY m.created_at DESC
    ),
    selected_messages AS (
        SELECT *,
            SUM(token_count) OVER (ORDER BY created_at DESC) as running_total
        FROM recent_messages
    )
    SELECT 
        sm.id,
        sm.role,
        sm.content,
        sm.created_at,
        sm.token_count
    FROM selected_messages sm
    WHERE sm.running_total <= p_max_tokens
    ORDER BY sm.created_at ASC;
END;
$$ LANGUAGE plpgsql;
