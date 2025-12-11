/**
 * Grey Mirror (BlackMirror) API Routes
 * Handles conversation analysis and LLM-powered relationship insights
 *
 * ARCHITECTURE: Modular route design with middleware separation
 * SECURITY: Authentication, premium validation, and rate limiting applied
 */

const express = require('express');
const router = express.Router();
const Database = require('../database');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { getJobQueue } = require('../services/grey-mirror-job-queue');

// Get database instance
const db = Database.getInstance();

// Configure multer for file uploads
const upload = multer({
  dest: '/home/fastl/JustLayMe/uploads/grey-mirror/',
  limits: {
    fileSize: 100 * 1024 * 1024, // 100MB max file size
    fieldSize: 100 * 1024 * 1024
  },
  fileFilter: (req, file, cb) => {
    // Accept text files only
    const allowedMimes = ['text/plain', 'text/csv', 'application/json'];
    const allowedExts = ['.txt', '.csv', '.json'];
    const ext = path.extname(file.originalname).toLowerCase();

    if (allowedMimes.includes(file.mimetype) || allowedExts.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only text, CSV, and JSON files are allowed.'));
    }
  }
});

// Ensure upload directory exists
const uploadDir = '/home/fastl/JustLayMe/uploads/grey-mirror/';
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Initialize job queue worker on module load
const jobQueue = getJobQueue();
console.log('✅ Grey Mirror job queue initialized');

/**
 * POST /api/grey-mirror/upload-async
 * Upload conversation file and create async analysis job
 * Returns job ID immediately (no Cloudflare timeout)
 *
 * SUPPORTS: 100K+ messages, years of conversation history
 *
 * MIDDLEWARE APPLIED (via router mounting in ai-server.js):
 * - expensiveLimiter: Strict rate limiting
 * - authenticateToken: JWT authentication
 * - requirePremium: Premium subscription validation
 */
router.post('/upload-async', upload.single('file'), async (req, res) => {
    const startTime = Date.now();
    try {
        const userId = req.user?.id;

        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        const { userName, contactName, insightsGoal } = req.body;

        console.log(`📤 Async upload from user ${userId}: ${req.file.originalname} (${req.file.size} bytes) - Upload took ${Date.now() - startTime}ms`);

        // Create job in queue (should be instant)
        const dbStart = Date.now();
        const jobQueue = getJobQueue();
        const job = await jobQueue.createJob({
            userId,
            fileName: req.file.originalname,
            fileSize: req.file.size,
            filePath: req.file.path,
            personalization: {
                userName: userName || 'You',
                contactName: contactName || 'Them',
                insightsGoal: insightsGoal || ''
            }
        });
        console.log(`✅ Job ${job.job_id} created in ${Date.now() - dbStart}ms - Total request time: ${Date.now() - startTime}ms`);

        // Return job ID immediately (< 1 second response time)
        res.json({
            success: true,
            jobId: job.job_id,
            message: 'Analysis job created. Use /job/:jobId to check status.',
            estimatedTime: '2-5 minutes',
            uploadTime: Date.now() - startTime
        });

    } catch (error) {
        console.error(`❌ Async upload error after ${Date.now() - startTime}ms:`, error);

        // Clean up uploaded file on error
        if (req.file && req.file.path) {
            try {
                fs.unlinkSync(req.file.path);
            } catch (cleanupError) {
                console.warn('Failed to cleanup file:', cleanupError);
            }
        }

        res.status(500).json({
            error: 'Upload failed',
            message: error.message
        });
    }
});

/**
 * GET /api/grey-mirror/job/:jobId
 * Get status and results of an async analysis job
 *
 * RETURNS:
 * - pending: Job is waiting in queue
 * - processing: Job is being analyzed
 * - completed: Job finished successfully (includes results)
 * - failed: Job failed (includes error message)
 *
 * MIDDLEWARE APPLIED (via router mounting in ai-server.js):
 * - authenticateToken: JWT authentication
 * - requirePremium: Premium subscription validation
 */
router.get('/job/:jobId', async (req, res) => {
    try {
        const { jobId } = req.params;
        const userId = req.user?.id;

        const jobQueue = getJobQueue();
        const job = await jobQueue.getJob(jobId);

        // Security: Verify user owns this job
        if (job.user_id !== userId) {
            return res.status(403).json({ error: 'Access denied' });
        }

        res.json({
            jobId: job.job_id,
            status: job.status,
            progress: job.progress_percentage || 0,
            message: job.progress_message || '',
            messageCount: job.message_count,
            createdAt: job.created_at,
            startedAt: job.started_at,
            completedAt: job.completed_at,
            results: job.status === 'completed' ? job.result_data : null,
            error: job.status === 'failed' ? job.error_message : null
        });

    } catch (error) {
        console.error('❌ Get job error:', error);
        res.status(404).json({
            error: 'Job not found',
            message: error.message
        });
    }
});

/**
 * GET /api/grey-mirror/job/:jobId/stream
 * SSE (Server-Sent Events) endpoint for real-time progress updates
 *
 * CLIENT USAGE:
 * const eventSource = new EventSource('/api/grey-mirror/job/abc-123/stream')
 * eventSource.onmessage = (event) => {
 *   const data = JSON.parse(event.data)
 *   console.log(`Progress: ${data.progress}% - ${data.message}`)
 * }
 *
 * MIDDLEWARE APPLIED (via router mounting in ai-server.js):
 * - authenticateToken: JWT authentication
 * - requirePremium: Premium subscription validation
 */
router.get('/job/:jobId/stream', async (req, res) => {
    try {
        const { jobId } = req.params;
        const userId = req.user?.id;

        const jobQueue = getJobQueue();

        // Verify job exists and user has access
        const job = await jobQueue.getJob(jobId);
        if (job.user_id !== userId) {
            return res.status(403).json({ error: 'Access denied' });
        }

        // Setup SSE headers
        res.setHeader('Content-Type', 'text/event-stream');
        res.setHeader('Cache-Control', 'no-cache');
        res.setHeader('Connection', 'keep-alive');
        res.setHeader('X-Accel-Buffering', 'no'); // Disable nginx buffering

        // Send initial status
        res.write(`data: ${JSON.stringify({
            progress: job.progress_percentage || 0,
            status: job.status,
            message: job.progress_message || 'Waiting in queue...'
        })}\n\n`);

        // Register client for updates
        jobQueue.addSSEClient(jobId, res);

        // If job is already completed, send final update and close
        if (job.status === 'completed' || job.status === 'failed') {
            res.write(`data: ${JSON.stringify({
                progress: 100,
                status: job.status,
                message: job.status === 'completed' ? 'Analysis complete!' : 'Analysis failed',
                done: true
            })}\n\n`);
            res.end();
        }

    } catch (error) {
        console.error('❌ SSE stream error:', error);
        res.status(404).json({
            error: 'Job not found',
            message: error.message
        });
    }
});

/**
 * POST /api/grey-mirror/analyze-advanced
 * Calls Python ML service for advanced relationship analysis (22 metrics)
 * Returns comprehensive metrics including Love Languages, Gottman Ratio, etc.
 *
 * ⚠️ LEGACY ENDPOINT: Use /upload-async for large files (100K+ messages)
 * This endpoint is synchronous and subject to Cloudflare 100s timeout
 *
 * MIDDLEWARE APPLIED (via router mounting in ai-server.js):
 * - expensiveLimiter: Strict rate limiting
 * - authenticateToken: JWT authentication
 * - requirePremium: Premium subscription validation
 */
router.post('/analyze-advanced', async (req, res) => {
    try {
        const { messages, personalization } = req.body;
        const userId = req.user?.id || 'anonymous';

        console.log(`🧠 Advanced ML analysis requested by user: ${userId}, ${messages?.length || 0} messages`);

        if (!messages || messages.length < 2) {
            return res.status(400).json({ error: 'Need at least 2 messages for analysis' });
        }

        // Call Python ML service
        const mlResponse = await fetch('http://localhost:5001/analyze', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                messages,
                personalization: personalization || {
                    userName: 'You',
                    contactName: 'Them',
                    insightsGoal: ''
                }
            })
        });

        if (!mlResponse.ok) {
            const errorText = await mlResponse.text();
            console.error('❌ ML Service Error:', errorText);
            return res.status(500).json({
                error: 'ML analysis failed',
                details: errorText
            });
        }

        const results = await mlResponse.json();

        console.log(`✅ Advanced ML analysis complete: ${results.processing_time}s`);

        res.json(results);

    } catch (error) {
        console.error('❌ Advanced analysis error:', error);
        res.status(500).json({
            error: 'Analysis failed',
            message: error.message
        });
    }
});

/**
 * POST /api/grey-mirror/analyze-with-llm
 * Accepts classifier results and provides deep AI-generated insights
 * Streams response for real-time UI updates
 *
 * MIDDLEWARE APPLIED (via router mounting in ai-server.js):
 * - expensiveLimiter: Strict rate limiting for expensive operations (10 per 10 min)
 * - authenticateToken: JWT authentication
 * - requirePremium: Premium subscription validation
 */
router.post('/analyze-with-llm', async (req, res) => {
    // Extended timeout for LLM streaming response
    // Prevents proxy timeout (Cloudflare default is 100s)
    req.setTimeout(300000); // 5 minutes
    res.setTimeout(300000);

    try {
        const results = req.body;
        const userId = req.user?.id || 'anonymous';

        console.log(`🔮 The Grey Mirror LLM Analysis requested by user: ${userId}`);

        // Extract personalization data
        const personalization = results.personalization || {};
        const userName = personalization.userName || 'You';
        const contactName = personalization.contactName || 'Them';
        const insightsGoal = personalization.insightsGoal || '';

        // Extract key metrics from classifier results
        const metrics = {
            healthScore: results.healthScore || 'N/A',
            sentiment: results.sentiment?.value || 'N/A',
            toxicity: results.toxicity?.value || 'N/A',
            engagement: results.engagement?.value || 'N/A',
            patterns: results.patterns?.value || 'N/A',
            conflict: results.conflict?.value || 'N/A',
            positivity: results.positivity?.value || 'N/A',
            messageCount: results.messageCount || 0,
        };

        // Extract message excerpts for contextual analysis - use personalized names
        const messageExcerpts = results.messageExcerpts || [];
        const excerptText = messageExcerpts.length > 0
            ? messageExcerpts.slice(0, 30).map((m, i) =>
                `[${m.direction === 'sent' ? userName : contactName}]: "${m.content}"`
              ).join('\n')
            : 'No message excerpts available';

        // Create a comprehensive relationship expert prompt
        // PERSONALIZATION: Include custom names and user's specific analysis goal
        const userGoalSection = insightsGoal
            ? `\n## THE USER'S SPECIFIC QUESTION/GOAL
The user wants to understand: "${insightsGoal}"

⚠️ IMPORTANT: Make sure to DIRECTLY address this question/concern in your analysis. This is what they care about most.\n`
            : '';

        const prompt = `You are a world-class relationship psychologist and communication expert. ${userName} has shared their conversation data with ${contactName} for deep analysis. Your role is to provide profound, actionable insights that help them understand their relationship dynamics.

## YOUR EXPERTISE
- Attachment theory and relationship patterns
- Non-verbal communication cues in text
- Emotional intelligence and empathy mapping
- Conflict resolution and healthy boundaries
- Love languages and communication styles
${userGoalSection}
## ANALYSIS DATA

### People in this Conversation:
- **${userName}** (the person asking for analysis)
- **${contactName}** (the person they're messaging)

### Relationship Metrics:
- Overall Health Score: ${metrics.healthScore}/100
- Sentiment: ${metrics.sentiment}
- Engagement Level: ${metrics.engagement}
- Communication Patterns: ${metrics.patterns}
- Conflict Indicators: ${metrics.conflict}
- Toxicity Level: ${metrics.toxicity}
- Positivity: ${metrics.positivity}
- Messages Analyzed: ${metrics.messageCount}

### Sample Conversation Excerpts:
${excerptText}

## YOUR ANALYSIS TASK

Based on the metrics AND the actual conversation excerpts above, provide a deeply insightful analysis covering:

1. **The Truth About ${userName} and ${contactName}'s Relationship** - Be honest but compassionate. What do the numbers and actual messages reveal about the real state of this relationship?

2. **Communication Patterns** - Analyze how ${userName} and ${contactName} communicate. Who initiates? Who asks questions? Who gives longer responses? What does this reveal about investment levels?

3. **Emotional Dynamics** - What emotions are present? Is there warmth? Distance? Tension? Look at specific message examples to illustrate your points.

4. **Red Flags & Green Lights** - Be specific. Quote actual messages if helpful. What concerns you? What looks healthy?

5. **The Deeper Story** - What's really happening beneath the surface? Are there unspoken needs? Patterns from past relationships repeating?

6. **Actionable Guidance for ${userName}** - Give 3-5 specific, practical things ${userName} can do to improve this relationship with ${contactName}.

Write in a warm, direct tone. Be like a trusted friend who happens to be a relationship expert - honest but kind. Use the actual message excerpts to make your analysis specific and personal, not generic. Always refer to the people by their names (${userName} and ${contactName}), not "you" and "them".

Remember: You are The Grey Mirror - reflecting truth with compassion.`;

        // Set headers for streaming response
        res.setHeader('Content-Type', 'text/event-stream');
        res.setHeader('Cache-Control', 'no-cache');
        res.setHeader('Connection', 'keep-alive');
        res.setHeader('X-Accel-Buffering', 'no'); // Disable nginx buffering

        // Send immediate acknowledgment to prevent proxy timeout
        res.write('🔮 Starting deep analysis...\n\n');

        // Send streaming response using Ollama
        try {
            const ollamaResponse = await fetch('http://localhost:11434/api/generate', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    // Use Qwen 2.5 7B for better analysis + 128K context
                    model: process.env.LLM_MODEL || 'qwen2.5:7b-instruct',
                    prompt: prompt,
                    stream: true,
                    options: {
                        num_ctx: 32768, // 32K context for comprehensive analysis
                        top_p: 0.9,
                        top_k: 40,
                        temperature: 0.7,
                        num_predict: 3000, // Allow longer, more detailed insights
                    }
                })
            });

            if (!ollamaResponse.ok) {
                throw new Error(`Ollama API error: ${ollamaResponse.status}`);
            }

            // Stream the response chunks
            const reader = ollamaResponse.body.getReader();
            const decoder = new TextDecoder();

            let buffer = '';
            while (true) {
                const { done, value } = await reader.read();
                if (done) break;

                buffer += decoder.decode(value, { stream: true });
                const lines = buffer.split('\n');

                // Process all complete lines
                for (let i = 0; i < lines.length - 1; i++) {
                    const line = lines[i];
                    if (line.trim()) {
                        try {
                            const chunk = JSON.parse(line);
                            if (chunk.response) {
                                // Send only the text part to client
                                res.write(chunk.response);
                            }
                        } catch (e) {
                            // Skip malformed JSON lines
                        }
                    }
                }

                // Keep incomplete line in buffer
                buffer = lines[lines.length - 1];
            }

            // Process any remaining content in buffer
            if (buffer.trim()) {
                try {
                    const chunk = JSON.parse(buffer);
                    if (chunk.response) {
                        res.write(chunk.response);
                    }
                } catch (e) {
                    // Ignore
                }
            }

            console.log(`✅ LLM analysis complete for user: ${userId}`);
            res.end();

        } catch (ollamaError) {
            console.error('❌ Ollama streaming error:', ollamaError.message);
            res.write(`\n\n⚠️ Error: Could not connect to AI model. ${ollamaError.message}`);
            res.end();
        }

    } catch (error) {
        console.error('❌ The Grey Mirror LLM Error:', error);
        res.status(500).write(`Error: ${error.message}`);
        res.end();
    }
});

/**
 * POST /api/grey-mirror/analyze-conversation/:conversationId
 * Analyzes an active conversation without requiring file upload
 *
 * HIGH IMPACT FEATURE: Users can now analyze their ongoing chats in real-time
 *
 * MIDDLEWARE APPLIED (via router mounting in ai-server.js):
 * - expensiveLimiter: Strict rate limiting
 * - authenticateToken: JWT authentication
 * - requirePremium: Premium subscription validation
 */
router.post('/analyze-conversation/:conversationId', async (req, res) => {
    try {
        const { conversationId } = req.params;
        const userId = req.user?.id;

        console.log(`🔮 The Grey Mirror analyzing active conversation ${conversationId} for user ${userId}`);

        // 1. Verify user owns this conversation
        const convCheck = await db.query(
            'SELECT id, model_type, title FROM conversations WHERE id = ? AND user_id = ?',
            [conversationId, userId]
        );

        const conversation = convCheck.rows ? convCheck.rows[0] : convCheck[0];
        if (!conversation) {
            return res.status(404).json({ error: 'Conversation not found or access denied' });
        }

        // 2. Fetch all messages from the conversation
        const messagesResult = await db.query(
            `SELECT sender_type, content, created_at
             FROM messages
             WHERE conversation_uuid = ?
             ORDER BY created_at ASC`,
            [conversationId]
        );

        const messages = messagesResult.rows || messagesResult || [];

        if (messages.length === 0) {
            return res.status(400).json({ error: 'No messages found in conversation' });
        }

        console.log(`📊 Analyzing ${messages.length} messages from conversation "${conversation.title}"`);

        // 3. Convert messages to text format for ML analysis
        const conversationText = messages.map(msg => {
            const sender = msg.sender_type === 'user' ? 'User' : 'Assistant';
            return `[${sender}] ${msg.content}`;
        }).join('\n');

        // 4. Calculate basic metrics (simplified version - could call ML orchestrator)
        const userMessages = messages.filter(m => m.sender_type === 'user');
        const assistantMessages = messages.filter(m => m.sender_type === 'assistant');

        const basicMetrics = {
            totalMessages: messages.length,
            userMessages: userMessages.length,
            assistantMessages: assistantMessages.length,
            balance: userMessages.length / (assistantMessages.length || 1),
            conversationTitle: conversation.title,
            characterId: conversation.model_type,
            analysisDate: new Date().toISOString()
        };

        // 5. Generate AI insights using LLM
        const analysisPrompt = `You are The The Grey Mirror - analyze this conversation and provide insights.

CONVERSATION DETAILS:
- Title: ${conversation.title}
- Total Messages: ${basicMetrics.totalMessages}
- User Messages: ${basicMetrics.userMessages}
- Assistant Messages: ${basicMetrics.assistantMessages}
- Balance: ${basicMetrics.balance.toFixed(2)} (user/assistant ratio)

CONVERSATION TRANSCRIPT:
${conversationText.substring(0, 4000)} ${conversationText.length > 4000 ? '...(truncated)' : ''}

Provide a comprehensive analysis covering:
1. **Conversation Health** - Overall quality and engagement
2. **Communication Patterns** - Key patterns you notice
3. **Emotional Tone** - Sentiment and emotional dynamics
4. **Areas of Strength** - What's working well
5. **Areas for Improvement** - What could be better
6. **Actionable Recommendations** - Specific suggestions

Be insightful, empathetic, and honest. Focus on helping the user improve their conversations.`;

        // Set headers for streaming response
        res.setHeader('Content-Type', 'text/event-stream');
        res.setHeader('Cache-Control', 'no-cache');
        res.setHeader('Connection', 'keep-alive');

        // Send basic metrics first
        res.write(`data: ${JSON.stringify({ type: 'metrics', data: basicMetrics })}\n\n`);

        // Stream LLM analysis
        try {
            const ollamaResponse = await fetch('http://localhost:11434/api/generate', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    model: process.env.LLM_MODEL || 'sushruth/solar-uncensored',
                    prompt: analysisPrompt,
                    stream: true,
                    options: {
                        num_ctx: 4096,
                        top_p: 0.9,
                        top_k: 40,
                        temperature: 0.7,
                    }
                })
            });

            if (!ollamaResponse.ok) {
                throw new Error(`Ollama API error: ${ollamaResponse.status}`);
            }

            const reader = ollamaResponse.body.getReader();
            const decoder = new TextDecoder();

            let buffer = '';
            while (true) {
                const { done, value } = await reader.read();
                if (done) break;

                buffer += decoder.decode(value, { stream: true });
                const lines = buffer.split('\n');

                for (let i = 0; i < lines.length - 1; i++) {
                    const line = lines[i];
                    if (line.trim()) {
                        try {
                            const chunk = JSON.parse(line);
                            if (chunk.response) {
                                res.write(`data: ${JSON.stringify({ type: 'text', data: chunk.response })}\n\n`);
                            }
                        } catch (e) {
                            // Ignore parse errors
                        }
                    }
                }

                buffer = lines[lines.length - 1];
            }

            console.log(`✅ Active conversation analysis complete for ${conversationId}`);
            res.write(`data: ${JSON.stringify({ type: 'done' })}\n\n`);
            res.end();

        } catch (ollamaError) {
            console.error('❌ Ollama error:', ollamaError.message);
            res.write(`data: ${JSON.stringify({ type: 'error', data: `AI model error: ${ollamaError.message}` })}\n\n`);
            res.end();
        }

    } catch (error) {
        console.error('❌ Active conversation analysis error:', error);
        res.status(500).json({ error: 'Analysis failed', message: error.message });
    }
});

module.exports = router;
