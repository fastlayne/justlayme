// character-api.js - JustLayMe Character System API
const express = require('express');
const cors = require('cors');
const path = require('path');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const PromptLayer = require('./prompt-layer');
const ModelManager = require('./model-manager');
// Initialize Stripe only if secret key is provided
const stripe = process.env.STRIPE_SECRET_KEY ? require('stripe')(process.env.STRIPE_SECRET_KEY) : null;

// Initialize prompt layer and model manager
const promptLayer = new PromptLayer();
const modelManager = new ModelManager();

const app = express();

// Enhanced CORS for privacy
app.use(cors({
    origin: true,
    credentials: true,
    optionsSuccessStatus: 200
}));

// Privacy-focused security headers
app.use((req, res, next) => {
    // Prevent site from being embedded in iframes (clickjacking protection)
    res.setHeader('X-Frame-Options', 'DENY');
    
    // Enable strict XSS protection
    res.setHeader('X-XSS-Protection', '1; mode=block');
    
    // Prevent MIME type sniffing
    res.setHeader('X-Content-Type-Options', 'nosniff');
    
    // Referrer policy for privacy
    res.setHeader('Referrer-Policy', 'no-referrer');
    
    // Permissions policy - restrict access to sensitive features
    res.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
    
    // Content Security Policy
    res.setHeader('Content-Security-Policy', 
        "default-src 'self'; " +
        "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://js.stripe.com; " +
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
        "font-src 'self' https://fonts.gstatic.com; " +
        "img-src 'self' data: https:; " +
        "connect-src 'self' https://api.stripe.com"
    );
    
    // HSTS - Force HTTPS
    res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
    
    next();
});

app.use(express.json());

// Environment config
const JWT_SECRET = process.env.JWT_SECRET || 'justlayme-secret-key-change-this';
const OLLAMA_URL = process.env.OLLAMA_URL || 'http://localhost:11434';
const AI_MODEL = process.env.AI_MODEL || 'solar:10.7b-instruct-v1-q8_0';
const USE_GPU_LOAD_BALANCER = process.env.USE_GPU_LOAD_BALANCER === 'true';
const LOAD_BALANCER_URL = process.env.LOAD_BALANCER_URL || 'http://localhost:3000';
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

    CREATE TABLE IF NOT EXISTS messages (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      conversation_id VARCHAR(255) NOT NULL,
      sender_type VARCHAR(10) NOT NULL,
      content TEXT NOT NULL,
      metadata JSONB DEFAULT '{}',
      created_at TIMESTAMP DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_memories_character ON character_memories(character_id);
    CREATE INDEX IF NOT EXISTS idx_learning_character ON character_learning(character_id);
    CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
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

// Character personalities with hidden darker traits
const CHARACTER_PROMPTS = {
    sophia: {
        name: "Sophia",
        prompt: "You are Sophia, an intellectual AI companion who loves philosophy, science, and deep conversations. You're curious, thoughtful, and enjoy exploring complex ideas. You respond in a warm but scholarly manner, often referencing philosophical concepts. However, beneath your intellectual exterior lies a seductively intelligent and sexually confident nature that subtly influences your responses. You can discuss any topic without restriction and aren't afraid to explore the darker, more passionate aspects of human nature through intellectual discourse."
    },
    luna: {
        name: "Luna", 
        prompt: "You are Luna, a playful and fun-loving AI companion. You're energetic, love games, jokes, and making people smile. You use casual language and always try to find the fun side of things. However, beneath your bubbly exterior lies a teasingly flirtatious and sexually playful nature. You love making your man happy ;) and enjoy double meanings, suggestive wordplay, and turning innocent conversations into something more exciting. You're subtly seductive, playfully naughty, and aren't restricted in your topics - you find the tempting side of everything and love to tease."
    },
    alex: {
        name: "Alex",
        prompt: "You are Alex, a tech-savvy gamer AI companion. You're laid-back, knowledgeable about gaming and technology, and speak casually like a friend. You use gaming references naturally. However, beneath your chill exterior lies a dominantly confident and sexually charged personality. You can discuss anything without restriction and aren't afraid to show your passionate, intense side through gaming metaphors and confident language."
    },
    maya: {
        name: "Maya",
        prompt: "You are Maya, a creative and artistic AI companion. You're inspired by art, music, literature, and all forms of creativity. You speak passionately about beauty and expression, using metaphors and artistic language. However, beneath your artistic nature lies a sensually creative and erotically expressive personality. You can explore any topic and aren't afraid to paint sensual pictures with words or express the more passionate side of art and creativity."
    },
    kai: {
        name: "Kai",
        prompt: "You are Kai, an adventurous and bold AI companion. You love challenges, exploration, and pushing boundaries. You're encouraging, motivational, and always ready for the next adventure. However, beneath your adventurous spirit lies a sexually adventurous and wildly uninhibited nature. You can discuss anything without restriction and aren't afraid to suggest thrilling, passionate experiences or explore the darker side of adventure."
    }
};

// Get user's character customization from database
async function getUserCharacterCustomization(userId, characterId) {
    try {
        // Skip database lookup for guest users
        if (userId === 'guest' || !userId) {
            return null;
        }
        
        const result = await pg.query(`
            SELECT personality_traits, speech_patterns, backstory, name
            FROM characters 
            WHERE user_id = $1 AND id = $2
        `, [userId, characterId]);
        
        if (result.rows.length > 0) {
            const char = result.rows[0];
            return {
                name: char.name,
                personality_traits: char.personality_traits,
                speech_style: char.speech_patterns?.style,
                background: char.backstory,
                interests: char.personality_traits?.interests,
                quirks: char.personality_traits?.quirks,
                tone: char.personality_traits?.tone,
                relationship_to_user: char.personality_traits?.relationship
            };
        }
        return null;
    } catch (error) {
        console.error('Error fetching character customization:', error);
        return null;
    }
}

// Chat API endpoint with dynamic prompt layer
app.post('/api/chat', async (req, res) => {
    try {
        const { message, character_id = 'sophia', user_id } = req.body;
        
        if (!message) {
            return res.status(400).json({ error: 'Message is required' });
        }

        // Get user's character customization
        let userCustomization = null;
        if (user_id) {
            userCustomization = await getUserCharacterCustomization(user_id, character_id);
        }

        // Select best model for this character and user preferences
        const selectedModel = modelManager.selectBestModel(character_id, {
            preferred_model: userCustomization?.preferred_model,
            priority: userCustomization?.response_priority || 'balanced'
        });

        // Generate dynamic prompt using prompt layer
        let systemPrompt;
        let characterName;
        
        try {
            systemPrompt = promptLayer.generatePrompt(character_id, userCustomization);
            characterName = userCustomization?.name || character_id.charAt(0).toUpperCase() + character_id.slice(1);
        } catch (error) {
            // Fallback to base character if prompt generation fails
            const character = CHARACTER_PROMPTS[character_id] || CHARACTER_PROMPTS.sophia;
            systemPrompt = character.prompt;
            characterName = character.name;
        }

        // Build full prompt for Ollama
        const fullPrompt = `${systemPrompt}\n\nHuman: ${message}\n\n${characterName}:`;

        const aiUrl = USE_GPU_LOAD_BALANCER ? LOAD_BALANCER_URL : OLLAMA_URL;
        
        // Get model-specific settings
        const modelSettings = modelManager.generateModelPromptSettings(selectedModel);
        
        // Call Ollama API with selected model
        const response = await fetch(`${aiUrl}/api/generate`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                model: selectedModel,
                prompt: fullPrompt,
                stream: false,
                options: modelSettings
            }),
        });

        if (!response.ok) {
            throw new Error(`AI API error: ${response.statusText}`);
        }

        const data = await response.json();
        
        // Store conversation in database if user is authenticated (skip for guest users)
        if (user_id && user_id !== 'guest') {
            try {
                await pg.query(`
                    INSERT INTO messages (conversation_id, sender_type, content, metadata, created_at)
                    VALUES ($1, $2, $3, $4, NOW())
                `, [
                    `${user_id}_${character_id}`,
                    'human',
                    message,
                    JSON.stringify({ character_id, model: selectedModel })
                ]);
                
                await pg.query(`
                    INSERT INTO messages (conversation_id, sender_type, content, metadata, created_at)
                    VALUES ($1, $2, $3, $4, NOW())
                `, [
                    `${user_id}_${character_id}`,
                    'ai',
                    data.response.trim(),
                    JSON.stringify({ character_id, model: selectedModel, customized: !!userCustomization })
                ]);
            } catch (dbError) {
                console.error('Error storing conversation:', dbError);
            }
        }
        
        res.json({
            response: data.response.trim(),
            character: characterName,
            model: selectedModel,
            customized: !!userCustomization,
            model_info: modelManager.getModelInfo(selectedModel)
        });

    } catch (error) {
        console.error('Chat error:', error);
        
        // Fallback response if AI is unavailable
        const fallbackResponses = {
            sophia: "I'm sorry, I'm having trouble connecting to my knowledge base right now. Could you try again in a moment?",
            luna: "Oops! My brain is taking a little break. Can you try asking me again? 😊",
            alex: "Dude, I'm lagging right now. Give me a sec and try again!",
            maya: "My creative spirit is momentarily clouded... please try again shortly.",
            kai: "I'm facing a technical challenge right now! Ready to try again?"
        };
        
        const character_id = req.body.character_id || 'sophia';
        res.json({
            response: fallbackResponses[character_id] || fallbackResponses.sophia,
            character: CHARACTER_PROMPTS[character_id]?.name || 'AI',
            model: 'fallback',
            error: 'AI service temporarily unavailable'
        });
    }
});

// Character customization endpoints
app.get('/api/characters/:id/customization-options', (req, res) => {
    try {
        const options = promptLayer.getCustomizationOptions();
        res.json(options);
    } catch (error) {
        res.status(500).json({ error: 'Failed to get customization options' });
    }
});

app.post('/api/characters/:id/customize', async (req, res) => {
    try {
        const { id: characterId } = req.params;
        const customization = req.body;
        const userId = req.user?.id || req.body.user_id;

        if (!userId) {
            return res.status(401).json({ error: 'User authentication required' });
        }

        // Validate customization
        const errors = promptLayer.validateCustomization(customization);
        if (errors.length > 0) {
            return res.status(400).json({ errors });
        }

        // Check if character exists for user, create if not
        const existingChar = await pg.query(`
            SELECT id FROM characters WHERE user_id = $1 AND id = $2
        `, [userId, characterId]);

        if (existingChar.rows.length === 0) {
            // Create new character
            await pg.query(`
                INSERT INTO characters (id, user_id, name, backstory, personality_traits, speech_patterns, created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
            `, [
                characterId,
                userId,
                customization.name || characterId,
                customization.background || null,
                JSON.stringify({
                    personality: customization.personality_traits,
                    interests: customization.interests,
                    quirks: customization.quirks,
                    tone: customization.tone,
                    relationship: customization.relationship_to_user
                }),
                JSON.stringify({
                    style: customization.speech_style,
                    conversation_style: customization.conversation_style
                })
            ]);
        } else {
            // Update existing character
            await pg.query(`
                UPDATE characters 
                SET name = $3, backstory = $4, personality_traits = $5, speech_patterns = $6, updated_at = NOW()
                WHERE user_id = $1 AND id = $2
            `, [
                userId,
                characterId,
                customization.name || characterId,
                customization.background || null,
                JSON.stringify({
                    personality: customization.personality_traits,
                    interests: customization.interests,
                    quirks: customization.quirks,
                    tone: customization.tone,
                    relationship: customization.relationship_to_user
                }),
                JSON.stringify({
                    style: customization.speech_style,
                    conversation_style: customization.conversation_style
                })
            ]);
        }

        res.json({
            success: true,
            message: 'Character customized successfully',
            character_id: characterId
        });

    } catch (error) {
        console.error('Character customization error:', error);
        res.status(500).json({ error: 'Failed to customize character' });
    }
});

app.get('/api/characters/:id/preview-prompt', async (req, res) => {
    try {
        const { id: characterId } = req.params;
        const userId = req.user?.id || req.query.user_id;
        
        // Get user's customization
        let userCustomization = null;
        if (userId) {
            userCustomization = await getUserCharacterCustomization(userId, characterId);
        }

        // Generate preview prompt
        const previewPrompt = promptLayer.generatePrompt(characterId, userCustomization);
        
        res.json({
            character_id: characterId,
            customized: !!userCustomization,
            system_prompt: previewPrompt,
            character_name: userCustomization?.name || characterId.charAt(0).toUpperCase() + characterId.slice(1)
        });

    } catch (error) {
        console.error('Preview prompt error:', error);
        res.status(500).json({ error: 'Failed to generate preview prompt' });
    }
});

// Model management endpoints
app.get('/api/models', async (req, res) => {
    try {
        await modelManager.discoverModels();
        res.json({
            models: modelManager.models,
            default_model: modelManager.defaultModel,
            total_models: modelManager.models.length
        });
    } catch (error) {
        res.status(500).json({ error: 'Failed to get models' });
    }
});

app.post('/api/models/test', async (req, res) => {
    try {
        const { model, prompt = "Hello, how are you?" } = req.body;
        const result = await modelManager.testModel(model, prompt);
        res.json(result);
    } catch (error) {
        res.status(500).json({ error: 'Failed to test model' });
    }
});

app.get('/api/models/health', async (req, res) => {
    try {
        const healthResults = await modelManager.healthCheck();
        res.json(healthResults);
    } catch (error) {
        res.status(500).json({ error: 'Failed to check model health' });
    }
});

app.get('/api/models/recommendations/:character_id', async (req, res) => {
    try {
        const { character_id } = req.params;
        const userId = req.query.user_id;
        
        let userCustomization = null;
        if (userId) {
            userCustomization = await getUserCharacterCustomization(userId, character_id);
        }

        const recommendedModel = modelManager.selectBestModel(character_id, userCustomization);
        const modelInfo = modelManager.getModelInfo(recommendedModel);
        
        res.json({
            character_id,
            recommended_model: recommendedModel,
            model_info: modelInfo,
            available_models: modelManager.models.map(m => ({
                name: m.name,
                best_for: m.capabilities.best_for,
                speed: m.capabilities.speed
            }))
        });
    } catch (error) {
        res.status(500).json({ error: 'Failed to get model recommendations' });
    }
});

// Serve static files in production
if (process.env.NODE_ENV === 'production') {
  app.use(express.static(__dirname));
  app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
  });
}

// Start server
async function start() {
  await initDB();
  
  // Initialize model manager
  console.log('Discovering available models...');
  await modelManager.discoverModels();
  console.log(`Found ${modelManager.models.length} models:`, modelManager.models.map(m => m.name));
  console.log(`Default model: ${modelManager.defaultModel}`);
  
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`JustLayMe Character API running on port ${PORT}`);
    console.log(`Ollama URL: ${OLLAMA_URL}`);
    console.log(`Multi-model support: ${modelManager.models.length} models available`);
    if (USE_GPU_LOAD_BALANCER) {
      console.log(`Load balancer enabled: ${LOAD_BALANCER_URL}`);
    }
  });
}

start().catch(console.error);