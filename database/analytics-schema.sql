-- Analytics Event Tracking Schema
-- Stores all user behavior events for retention analysis

CREATE TABLE IF NOT EXISTS analytics_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    user_id TEXT,
    event_name TEXT NOT NULL,
    page TEXT,
    properties TEXT, -- JSON blob for event-specific data
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_analytics_session ON analytics_events(session_id);
CREATE INDEX IF NOT EXISTS idx_analytics_user ON analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_event ON analytics_events(event_name);
CREATE INDEX IF NOT EXISTS idx_analytics_timestamp ON analytics_events(timestamp);

-- Analytics Summary Table for quick dashboard queries
CREATE TABLE IF NOT EXISTS analytics_summary (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date DATE NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    metadata TEXT, -- JSON blob for additional context
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(date, metric_name)
);

CREATE INDEX IF NOT EXISTS idx_summary_date ON analytics_summary(date);
CREATE INDEX IF NOT EXISTS idx_summary_metric ON analytics_summary(metric_name);
