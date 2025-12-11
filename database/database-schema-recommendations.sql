-- JustLayMe Database Schema Recommendations for Chat History and Email Verification
-- Date: 2025-06-15

-- 1. Add email verification fields to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verification_token VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verification_expires TIMESTAMP;
ALTER TABLE users ADD COLUMN IF NOT EXISTS professional_email BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS company_domain VARCHAR(255);

-- 2. Create conversations table for better chat organization
CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    character_id VARCHAR(50) NOT NULL, -- Using character name/id string
    title VARCHAR(255),
    summary TEXT,
    is_archived BOOLEAN DEFAULT FALSE,
    is_favorite BOOLEAN DEFAULT FALSE,
    last_message_at TIMESTAMP DEFAULT NOW(),
    message_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    metadata JSONB DEFAULT '{}',
    UNIQUE(user_id, character_id, created_at)
);

-- 3. Enhance messages table for premium features
ALTER TABLE messages ADD COLUMN IF NOT EXISTS conversation_uuid UUID REFERENCES conversations(id) ON DELETE CASCADE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_edited BOOLEAN DEFAULT FALSE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS edited_at TIMESTAMP;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS tokens_used INTEGER;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS model_used VARCHAR(100);
ALTER TABLE messages ADD COLUMN IF NOT EXISTS response_time_ms INTEGER;

-- 4. Create message_attachments table for future multimedia support
CREATE TABLE IF NOT EXISTS message_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID REFERENCES messages(id) ON DELETE CASCADE,
    attachment_type VARCHAR(50) NOT NULL, -- 'image', 'audio', 'file'
    file_url TEXT NOT NULL,
    file_size INTEGER,
    mime_type VARCHAR(100),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

-- 5. Create conversation_tags table for organization
CREATE TABLE IF NOT EXISTS conversation_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    tag_name VARCHAR(50) NOT NULL,
    color VARCHAR(7), -- hex color
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, tag_name)
);

CREATE TABLE IF NOT EXISTS conversation_tag_mappings (
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES conversation_tags(id) ON DELETE CASCADE,
    PRIMARY KEY (conversation_id, tag_id)
);

-- 6. Create chat_exports table for premium export feature
CREATE TABLE IF NOT EXISTS chat_exports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    export_format VARCHAR(20) NOT NULL, -- 'json', 'txt', 'pdf'
    file_url TEXT,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

-- 7. Create email_verification_logs for tracking
CREATE TABLE IF NOT EXISTS email_verification_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    action VARCHAR(50) NOT NULL, -- 'sent', 'clicked', 'verified', 'expired'
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 8. Create premium_features_usage for analytics
CREATE TABLE IF NOT EXISTS premium_features_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    feature_name VARCHAR(100) NOT NULL,
    usage_count INTEGER DEFAULT 1,
    last_used_at TIMESTAMP DEFAULT NOW(),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, feature_name)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_conversations_user_character ON conversations(user_id, character_id);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message ON conversations(last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_uuid ON messages(conversation_uuid);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_email_verified ON users(email_verified);
CREATE INDEX IF NOT EXISTS idx_users_professional_email ON users(professional_email);
CREATE INDEX IF NOT EXISTS idx_email_verification_token ON users(email_verification_token);

-- Function to automatically update conversation stats
CREATE OR REPLACE FUNCTION update_conversation_stats() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE conversations 
        SET last_message_at = NEW.created_at,
            message_count = message_count + 1,
            updated_at = NOW()
        WHERE id = NEW.conversation_uuid;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_conversation_stats_trigger
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION update_conversation_stats();