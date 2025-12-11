-- Simple SQLite schema for JustLayMe
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT,
  name TEXT,
  google_id TEXT UNIQUE,
  subscription_status TEXT DEFAULT 'free',
  subscription_end TEXT,
  message_count INTEGER DEFAULT 0,
  email_verified INTEGER DEFAULT 0,
  verification_token TEXT,
  verification_expires TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  last_login TEXT
);

CREATE TABLE IF NOT EXISTS characters (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  backstory TEXT,
  personality_traits TEXT DEFAULT '{}',
  speech_patterns TEXT DEFAULT '[]',
  avatar_url TEXT,
  is_public INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

-- Persistent session storage for premium users
CREATE TABLE IF NOT EXISTS sessions (
  session_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  character_id TEXT NOT NULL,
  messages TEXT DEFAULT '[]',
  start_time TEXT DEFAULT (datetime('now')),
  last_activity TEXT DEFAULT (datetime('now')),
  is_premium INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS character_memories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
  user_message TEXT NOT NULL,
  ai_response TEXT NOT NULL,
  feedback_score INTEGER,
  corrected_response TEXT,
  importance_score REAL DEFAULT 0.5,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS character_learning (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
  pattern_type TEXT,
  user_input TEXT,
  expected_output TEXT,
  confidence REAL DEFAULT 1.0,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS conversations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  model_type TEXT NOT NULL,
  title TEXT,
  message_count INTEGER DEFAULT 0,
  is_archived INTEGER DEFAULT 0,
  tags TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  conversation_uuid INTEGER REFERENCES conversations(id) ON DELETE CASCADE,
  conversation_id TEXT,
  sender_type TEXT NOT NULL,
  content TEXT NOT NULL,
  metadata TEXT DEFAULT '{}',
  is_deleted INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS email_verification_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

-- Grey Mirror async job queue for large conversation analysis
CREATE TABLE IF NOT EXISTS grey_mirror_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id TEXT UNIQUE NOT NULL,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending',
  file_name TEXT,
  file_size INTEGER,
  file_path TEXT,
  message_count INTEGER,
  personalization TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  started_at TEXT,
  completed_at TEXT,
  progress_percentage INTEGER DEFAULT 0,
  progress_message TEXT,
  error_message TEXT,
  result_data TEXT
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_memories_character ON character_memories(character_id);
CREATE INDEX IF NOT EXISTS idx_learning_character ON character_learning(character_id);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_uuid);
CREATE INDEX IF NOT EXISTS idx_conversations_user ON conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated ON conversations(updated_at);
CREATE INDEX IF NOT EXISTS idx_users_email_verified ON users(email_verified);
CREATE INDEX IF NOT EXISTS idx_users_verification_token ON users(verification_token);
CREATE INDEX IF NOT EXISTS idx_grey_mirror_jobs_job_id ON grey_mirror_jobs(job_id);
CREATE INDEX IF NOT EXISTS idx_grey_mirror_jobs_user_id ON grey_mirror_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_grey_mirror_jobs_status ON grey_mirror_jobs(status);
CREATE INDEX IF NOT EXISTS idx_grey_mirror_jobs_created_at ON grey_mirror_jobs(created_at);