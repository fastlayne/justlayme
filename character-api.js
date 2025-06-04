// character-api.js - JustLayMe Character System API
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(cors());
app.use(express.json());

// Environment config
const JWT_SECRET = process.env.JWT_SECRET || 'justlayme-secret-key-change-this';
const LM_STUDIO_URL = process.env.LM_STUDIO_URL || 'http://localhost:1234';
const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://localhost/justlayme';

// Database connection
const pg = new Pool({ connectionString: DATABASE_URL });

// Initialize database
async function initDB() {
  await pg.query(`
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email VARCHAR(255) UNIQUE NOT NULL,
      password_hash VARCHAR(255) NOT NULL,
      subscription_status VARCHAR(50) DEFAULT 'free',
      subscription_end DATE,
      message_count INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS characters (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      name VARCHAR(100) NOT NULL,
      backstory TEXT,
      personality_traits JSONB DEFAULT '{}',
      speech_patterns JSONB DEFAULT '[]',
      avatar_url TEXT,
      is_public BOOLEAN DEFAULT false,
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS character_memories (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      character_id UUID REFERENCES characters(id) ON DELETE CASCADE,
      user_message TEXT NOT NULL,
      ai_response TEXT NOT NULL,
      feedback_score INTEGER,
      corrected_response TEXT,
      importance_score FLOAT DEFAULT 0.5,
      created_at TIMESTAMP DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS character_learning (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      character_id UUID REFERENCES characters(id) ON DELETE CASCADE,
      pattern_type VARCHAR(50),
      user_input TEXT,
      expected_output TEXT,
      confidence FLOAT DEFAULT 1.0,
      created_at TIMESTAMP DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_memories_character ON character_memories(character_id);
    CREATE INDEX IF NOT EXISTS idx_learning_character ON character_learning(character_id);
  `);
  
  console.log('Database initialized');
}

// Middleware
function authenticateToken(req, res, next) {
  const token = req.headers['authorization']?.split(' ')[1];
  if (!token) return res.sendStatus(401);
  
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    req.user = user;
    next();
  });
}

// Check message limits for free users
async function checkMessageLimit(userId) {
  const result = await pg.query(`
    SELECT subscription_status, message_count 
    FROM users WHERE id = $1
  `, [userId]);
  
  const user = result.rows[0];
  if (user.subscription_status === 'free' && user.message_count >= 100) {
    return false;
  }
  
  // Increment message count
  await pg.query(`
    UPDATE users SET message_count = message_count + 1 
    WHERE id = $1
  `, [userId]);
  
  return true;
}

// Auth endpoints
app.post('/api/register', async (req, res) => {
  const { email, password } = req.body;
  
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const result = await pg.query(`
      INSERT INTO users (email, password_hash)
      VALUES ($1, $2)
      RETURNING id, email, subscription_status
    `, [email, hashedPassword]);
    
    const user = result.rows[0];
    const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET);
    
    res.json({ token, user });
  } catch (error) {
    if (error.code === '23505') {
      res.status(400).json({ error: 'Email already exists' });
    } else {
      res.status(500).json({ error: 'Registration failed' });
    }
  }
});

app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;
  
  try {
    const result = await pg.query(`
      SELECT * FROM users WHERE email = $1
    `, [email]);
    
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const user = result.rows[0];
    const validPassword = await bcrypt.compare(password, user.password_hash);
    
    if (!validPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET);
    
    res.json({ 
      token, 
      user: {
        id: user.id,
        email: user.email,
        subscription_status: user.subscription_status
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Login failed' });
  }
});

app.get('/api/verify', authenticateToken, async (req, res) => {
  res.json(req.user);
});

// Character endpoints
app.get('/api/characters', authenticateToken, async (req, res) => {
  try {
    const result = await pg.query(`
      SELECT * FROM characters 
      WHERE user_id = $1 OR is_public = true
      ORDER BY created_at DESC
    `, [req.user.id]);
    
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch characters' });
  }
});

app.post('/api/characters', authenticateToken, async (req, res) => {
  const { name, backstory, personality_traits, speech_patterns } = req.body;
  
  try {
    // Check character limit for free users
    const countResult = await pg.query(`
      SELECT COUNT(*) FROM characters WHERE user_id = $1
    `, [req.user.id]);
    
    const userResult = await pg.query(`
      SELECT subscription_status FROM users WHERE id = $1
    `, [req.user.id]);
    
    const count = parseInt(countResult.rows[0].count);
    const subscription = userResult.rows[0].subscription_status;
    
    if (subscription === 'free' && count >= 1) {
      return res.status(403).json({ error: 'Free users can only create 1 character' });
    }
    
    const result = await pg.query(`
      INSERT INTO characters 
      (user_id, name, backstory, personality_traits, speech_patterns)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
    `, [req.user.id, name, backstory, personality_traits, speech_patterns]);
    
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create character' });
  }
});

app.put('/api/characters/:id', authenticateToken, async (req, res) => {
  const { personality_traits, backstory, speech_patterns } = req.body;
  
  try {
    const result = await pg.query(`
      UPDATE characters 
      SET personality_traits = $1, backstory = $2, speech_patterns = $3, 
          updated_at = NOW()
      WHERE id = $4 AND user_id = $5
      RETURNING *
    `, [personality_traits, backstory, speech_patterns, req.params.id, req.user.id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Character not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update character' });
  }
});

// Chat endpoint
app.post('/api/chat/:character_id', authenticateToken, async (req, res) => {
  const { message } = req.body;
  const characterId = req.params.character_id;
  
  try {
    // Check message limit
    const canSend = await checkMessageLimit(req.user.id);
    if (!canSend) {
      return res.status(403).json({ 
        error: 'Message limit reached. Upgrade to Pro for unlimited messages.' 
      });
    }
    
    // Get character
    const charResult = await pg.query(`
      SELECT * FROM characters 
      WHERE id = $1 AND (user_id = $2 OR is_public = true)
    `, [characterId, req.user.id]);
    
    if (charResult.rows.length === 0) {
      return res.status(404).json({ error: 'Character not found' });
    }
    
    const character = charResult.rows[0];
    
    // Get recent memories
    const memories = await pg.query(`
      SELECT user_message, ai_response, corrected_response
      FROM character_memories
      WHERE character_id = $1
      ORDER BY importance_score DESC, created_at DESC
      LIMIT 10
    `, [characterId]);
    
    // Get learned patterns
    const patterns = await pg.query(`
      SELECT user_input, expected_output
      FROM character_learning
      WHERE character_id = $1 AND confidence > 0.7
      ORDER BY confidence DESC
      LIMIT 5
    `, [characterId]);
    
    // Build system prompt
    let systemPrompt = `You are ${character.name}.\n\n`;
    
    if (character.backstory) {
      systemPrompt += `Backstory: ${character.backstory}\n\n`;
    }
    
    if (character.personality_traits) {
      const traits = Object.entries(character.personality_traits)
        .map(([trait, value]) => `${trait}: ${value}/10`)
        .join(', ');
      systemPrompt += `Personality: ${traits}\n\n`;
    }
    
    if (character.speech_patterns && character.speech_patterns.length > 0) {
      systemPrompt += `Speech patterns:\n`;
      character.speech_patterns.forEach(pattern => {
        systemPrompt += `- ${pattern}\n`;
      });
      systemPrompt += '\n';
    }
    
    if (patterns.rows.length > 0) {
      systemPrompt += `Examples of how to respond:\n`;
      patterns.rows.forEach(p => {
        systemPrompt += `User: "${p.user_input}" → You: "${p.expected_output}"\n`;
      });
      systemPrompt += '\n';
    }
    
    if (memories.rows.length > 0) {
      systemPrompt += `Recent interactions to remember:\n`;
      memories.rows.slice(0, 3).forEach(m => {
        if (m.corrected_response) {
          systemPrompt += `When user says something like: "${m.user_message}" → Respond like: "${m.corrected_response}"\n`;
        }
      });
    }
    
    systemPrompt += `\nStay perfectly in character. Be creative and engaging.`;
    
    // Call LM Studio
    const response = await fetch(`${LM_STUDIO_URL}/v1/chat/completions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: message }
        ],
        temperature: 0.8,
        max_tokens: 500
      })
    });
    
    if (!response.ok) {
      throw new Error('AI service unavailable');
    }
    
    const data = await response.json();
    const aiResponse = data.choices[0].message.content;
    
    // Store in memory
    const memoryResult = await pg.query(`
      INSERT INTO character_memories 
      (character_id, user_message, ai_response)
      VALUES ($1, $2, $3)
      RETURNING id
    `, [characterId, message, aiResponse]);
    
    res.json({ 
      response: aiResponse,
      memory_id: memoryResult.rows[0].id
    });
    
  } catch (error) {
    console.error('Chat error:', error);
    res.status(500).json({ error: 'Chat failed. Make sure LM Studio is running.' });
  }
});

// Feedback endpoint
app.post('/api/feedback/:memory_id', authenticateToken, async (req, res) => {
  const { score, corrected_response, pattern_type } = req.body;
  
  try {
    // Update memory with feedback
    const memory = await pg.query(`
      UPDATE character_memories 
      SET feedback_score = $1, corrected_response = $2
      WHERE id = $3
      RETURNING *
    `, [score, corrected_response, req.params.memory_id]);
    
    if (memory.rows.length === 0) {
      return res.status(404).json({ error: 'Memory not found' });
    }
    
    // If correction provided, add to learning
    if (corrected_response) {
      await pg.query(`
        INSERT INTO character_learning
        (character_id, pattern_type, user_input, expected_output, confidence)
        VALUES ($1, $2, $3, $4, $5)
      `, [
        memory.rows[0].character_id,
        pattern_type || 'speech',
        memory.rows[0].user_message,
        corrected_response,
        0.9
      ]);
    }
    
    // Update importance score
    const multiplier = score > 3 ? 1.2 : 0.8;
    await pg.query(`
      UPDATE character_memories
      SET importance_score = LEAST(importance_score * $1, 1.0)
      WHERE id = $2
    `, [multiplier, req.params.memory_id]);
    
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to process feedback' });
  }
});

// Serve static files in production
if (process.env.NODE_ENV === 'production') {
  app.use(express.static('public'));
  app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
  });
}

// Start server
async function start() {
  await initDB();
  
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`JustLayMe Character API running on port ${PORT}`);
    console.log(`Make sure LM Studio is running on ${LM_STUDIO_URL}`);
  });
}

start().catch(console.error);