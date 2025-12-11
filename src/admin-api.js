const express = require('express');
const Database = require('./database.js');
const WebSocket = require('ws');

class AdminMonitoringAPI {
    constructor(server) {
        this.router = express.Router();
        this.db = Database.getInstance();
        this.setupRoutes();
        this.setupWebSocket(server);
        this.activeUsers = new Map();
        this.systemStats = {
            startTime: Date.now(),
            messageCount: 0,
            errorCount: 0,
            responseTimes: []
        };
    }

    setupRoutes() {
        // Active users endpoint
        this.router.get('/users/active', async (req, res) => {
            try {
                const activeUsers = Array.from(this.activeUsers.values());
                const todayStart = new Date().setHours(0, 0, 0, 0);
                
                // Get daily users from database
                const dailyUsersQuery = `
                    SELECT COUNT(DISTINCT user_id) as count 
                    FROM conversations 
                    WHERE created_at >= ?
                `;
                const dailyResult = await this.db.query(dailyUsersQuery, [new Date(todayStart).toISOString()]);
                
                // Get premium users count
                const premiumQuery = `
                    SELECT COUNT(*) as count 
                    FROM users 
                    WHERE premium_until > datetime('now')
                `;
                const premiumResult = await this.db.query(premiumQuery);

                res.json({
                    active: activeUsers.length,
                    daily: dailyResult.rows[0]?.count || 0,
                    premium: premiumResult.rows[0]?.count || 0,
                    users: activeUsers.map(user => ({
                        email: user.email || 'Guest',
                        currentActivity: user.activity || 'Browsing',
                        status: user.isPremium ? 'premium' : 'free',
                        lastSeen: user.lastSeen,
                        sessionId: user.sessionId
                    }))
                });
            } catch (error) {
                console.error('Admin API - Failed to get active users:', error);
                res.status(500).json({ error: 'Failed to fetch user data' });
            }
        });

        // System statistics endpoint
        this.router.get('/system/stats', async (req, res) => {
            try {
                const todayStart = new Date().setHours(0, 0, 0, 0);
                
                // Get daily message count
                const messageQuery = `
                    SELECT COUNT(*) as count 
                    FROM messages 
                    WHERE created_at >= ?
                `;
                const messageResult = await this.db.query(messageQuery, [new Date(todayStart).toISOString()]);
                
                // Calculate average response time
                const avgResponseTime = this.systemStats.responseTimes.length > 0 
                    ? Math.round(this.systemStats.responseTimes.reduce((a, b) => a + b) / this.systemStats.responseTimes.length)
                    : 0;
                
                // Calculate uptime in hours
                const uptimeMs = Date.now() - this.systemStats.startTime;
                const uptimeHours = Math.floor(uptimeMs / (1000 * 60 * 60));
                
                // Calculate error rate
                const totalRequests = this.systemStats.messageCount + this.systemStats.errorCount;
                const errorRate = totalRequests > 0 
                    ? ((this.systemStats.errorCount / totalRequests) * 100).toFixed(1)
                    : 0;

                res.json({
                    dailyMessages: messageResult.rows[0]?.count || 0,
                    avgResponseTime,
                    uptime: uptimeHours,
                    errorRate: errorRate + '%'
                });
            } catch (error) {
                console.error('Admin API - Failed to get system stats:', error);
                res.status(500).json({ error: 'Failed to fetch system stats' });
            }
        });

        // AI Model status endpoint
        this.router.get('/models/status', async (req, res) => {
            try {
                const models = [];
                
                // Check Ollama models
                try {
                    const { exec } = require('child_process');
                    const { promisify } = require('util');
                    const execAsync = promisify(exec);
                    
                    // Get VRAM usage
                    const vramResult = await execAsync('nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits');
                    const [vramUsed, vramTotal] = vramResult.stdout.trim().split(',').map(v => parseInt(v.trim()));
                    
                    // Get running models
                    const ollamaResult = await execAsync('ollama ps');
                    const runningModels = ollamaResult.stdout.includes('sushruth/solar-uncensored');
                    
                    models.push({
                        name: 'LayMe V1 (Solar)',
                        status: runningModels ? 'online' : 'offline',
                        load: Math.round((vramUsed / vramTotal) * 100),
                        memory: (vramUsed / 1024).toFixed(1)
                    });
                    
                } catch (error) {
                    console.error('Failed to get GPU stats:', error);
                    models.push({
                        name: 'LayMe V1 (Solar)',
                        status: 'unknown',
                        load: 0,
                        memory: 0
                    });
                }

                res.json({ models });
            } catch (error) {
                console.error('Admin API - Failed to get model status:', error);
                res.status(500).json({ error: 'Failed to fetch model status' });
            }
        });

        // Recent conversations endpoint
        this.router.get('/conversations/recent', async (req, res) => {
            try {
                const query = `
                    SELECT 
                        c.id,
                        c.created_at,
                        u.email as user_email,
                        c.character_id,
                        (
                            SELECT json_group_array(
                                json_object(
                                    'role', m.sender_type,
                                    'content', m.content,
                                    'timestamp', m.created_at
                                )
                            )
                            FROM messages m 
                            WHERE m.conversation_uuid = c.id 
                            ORDER BY m.created_at DESC 
                            LIMIT 5
                        ) as recent_messages
                    FROM conversations c
                    LEFT JOIN users u ON c.user_id = u.id
                    WHERE c.created_at >= datetime('now', '-1 hour')
                    ORDER BY c.updated_at DESC
                    LIMIT 20
                `;
                
                const result = await this.db.query(query);
                
                const conversations = result.rows.map(row => {
                    let messages = [];
                    try {
                        messages = JSON.parse(row.recent_messages || '[]');
                    } catch (e) {
                        console.error('Failed to parse messages:', e);
                    }
                    
                    return {
                        id: row.id,
                        user: row.user_email || 'Guest User',
                        timestamp: new Date(row.created_at).getTime(),
                        character: row.character_id,
                        messages: messages.reverse(), // Show in chronological order
                        hasAlert: this.checkForAlerts(messages)
                    };
                });

                res.json({ conversations });
            } catch (error) {
                console.error('Admin API - Failed to get conversations:', error);
                res.status(500).json({ error: 'Failed to fetch conversations' });
            }
        });

        // Activity feed endpoint
        this.router.get('/activity/recent', async (req, res) => {
            try {
                const activities = [];
                
                // Get recent user activities
                const userQuery = `
                    SELECT 'user_login' as type, u.email, u.last_login as timestamp
                    FROM users u 
                    WHERE u.last_login >= datetime('now', '-1 hour')
                    ORDER BY u.last_login DESC
                    LIMIT 10
                `;
                const userResult = await this.db.query(userQuery);
                
                userResult.rows.forEach(row => {
                    activities.push({
                        icon: '🟢',
                        text: `User logged in: ${row.email}`,
                        timestamp: new Date(row.timestamp).getTime()
                    });
                });

                // Get recent messages
                const messageQuery = `
                    SELECT m.sender_type, m.created_at, u.email
                    FROM messages m
                    JOIN conversations c ON m.conversation_uuid = c.id
                    LEFT JOIN users u ON c.user_id = u.id
                    WHERE m.created_at >= datetime('now', '-1 hour')
                    ORDER BY m.created_at DESC
                    LIMIT 20
                `;
                const messageResult = await this.db.query(messageQuery);
                
                messageResult.rows.forEach(row => {
                    activities.push({
                        icon: row.sender_type === 'user' ? '💬' : '🤖',
                        text: `New ${row.sender_type} message from ${row.email || 'Guest'}`,
                        timestamp: new Date(row.created_at).getTime()
                    });
                });

                // Get recent character creations
                const characterQuery = `
                    SELECT cc.name, cc.created_at, u.email
                    FROM custom_characters cc
                    JOIN users u ON cc.user_id = u.id
                    WHERE cc.created_at >= datetime('now', '-1 hour')
                    ORDER BY cc.created_at DESC
                    LIMIT 10
                `;
                const characterResult = await this.db.query(characterQuery);
                
                characterResult.rows.forEach(row => {
                    activities.push({
                        icon: 'ROLEPLAY',
                        text: `Character created: "${row.name}" by ${row.email}`,
                        timestamp: new Date(row.created_at).getTime()
                    });
                });

                // Sort by timestamp
                activities.sort((a, b) => b.timestamp - a.timestamp);

                res.json({ activities: activities.slice(0, 50) });
            } catch (error) {
                console.error('Admin API - Failed to get activity feed:', error);
                res.status(500).json({ error: 'Failed to fetch activity feed' });
            }
        });

        // Real-time message logging endpoint
        this.router.post('/log/message', (req, res) => {
            const { user, role, content, character } = req.body;
            
            // Track system stats
            this.systemStats.messageCount++;
            
            // Broadcast to admin WebSocket clients
            if (this.wsServer) {
                this.broadcastToAdmins({
                    type: 'new_message',
                    payload: {
                        user: user?.email || 'Guest',
                        role,
                        content,
                        character,
                        timestamp: Date.now()
                    }
                });
            }
            
            res.json({ success: true });
        });

        // Track response times
        this.router.post('/log/response-time', (req, res) => {
            const { responseTime } = req.body;
            
            if (responseTime && typeof responseTime === 'number') {
                this.systemStats.responseTimes.push(responseTime);
                
                // Keep only last 100 response times
                if (this.systemStats.responseTimes.length > 100) {
                    this.systemStats.responseTimes.shift();
                }
            }
            
            res.json({ success: true });
        });

        // Track errors
        this.router.post('/log/error', (req, res) => {
            const { error, user } = req.body;
            
            this.systemStats.errorCount++;
            
            // Broadcast critical errors to admins
            if (this.wsServer) {
                this.broadcastToAdmins({
                    type: 'system_alert',
                    payload: {
                        title: 'System Error',
                        message: `Error occurred for user ${user?.email || 'Guest'}: ${error}`,
                        severity: 'error',
                        timestamp: Date.now()
                    }
                });
            }
            
            res.json({ success: true });
        });
    }

    setupWebSocket(server) {
        this.wsServer = new WebSocket.Server({ 
            server,
            path: '/admin-ws'
        });

        this.adminClients = new Set();

        this.wsServer.on('connection', (ws, req) => {
            console.log('🔌 Admin WebSocket client connected');
            this.adminClients.add(ws);

            ws.on('close', () => {
                console.log('🔌 Admin WebSocket client disconnected');
                this.adminClients.delete(ws);
            });

            ws.on('error', (error) => {
                console.error('WebSocket error:', error);
                this.adminClients.delete(ws);
            });

            // Send initial data
            ws.send(JSON.stringify({
                type: 'connection_established',
                payload: { timestamp: Date.now() }
            }));
        });
    }

    broadcastToAdmins(data) {
        this.adminClients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                try {
                    client.send(JSON.stringify(data));
                } catch (error) {
                    console.error('Failed to send WebSocket message:', error);
                    this.adminClients.delete(client);
                }
            }
        });
    }

    // Track user activity
    trackUserActivity(userId, email, activity, isPremium = false) {
        const sessionId = `${userId || 'guest'}_${Date.now()}`;
        
        this.activeUsers.set(sessionId, {
            userId,
            email: email || 'Guest',
            activity,
            isPremium,
            lastSeen: Date.now(),
            sessionId
        });

        // Broadcast user joined event
        this.broadcastToAdmins({
            type: 'user_joined',
            payload: {
                email: email || 'Guest',
                activity,
                isPremium,
                timestamp: Date.now()
            }
        });

        // Clean up old sessions (older than 5 minutes)
        this.cleanupOldSessions();
    }

    updateUserActivity(sessionId, activity) {
        const user = this.activeUsers.get(sessionId);
        if (user) {
            user.activity = activity;
            user.lastSeen = Date.now();
        }
    }

    removeUserActivity(sessionId) {
        const user = this.activeUsers.get(sessionId);
        if (user) {
            this.activeUsers.delete(sessionId);
            
            this.broadcastToAdmins({
                type: 'user_left',
                payload: {
                    email: user.email,
                    timestamp: Date.now()
                }
            });
        }
    }

    cleanupOldSessions() {
        const fiveMinutesAgo = Date.now() - (5 * 60 * 1000);
        
        for (const [sessionId, user] of this.activeUsers.entries()) {
            if (user.lastSeen < fiveMinutesAgo) {
                this.activeUsers.delete(sessionId);
            }
        }
    }

    checkForAlerts(messages) {
        // Check for potentially problematic content
        const alertKeywords = [
            'illegal', 'hack', 'bomb', 'weapon', 'drug', 'suicide',
            'kill', 'murder', 'violence', 'terrorism'
        ];
        
        return messages.some(msg => {
            if (msg.role === 'user') {
                const content = msg.content.toLowerCase();
                return alertKeywords.some(keyword => content.includes(keyword));
            }
            return false;
        });
    }

    getRouter() {
        return this.router;
    }
}

module.exports = AdminMonitoringAPI;