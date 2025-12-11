/**
 * Analytics API Endpoint
 * Receives and stores user behavior events for retention optimization
 */

const express = require('express');
const router = express.Router();
const logger = require('../logger');
const Database = require('../database');

// Get database instance
const db = Database.getInstance();

/**
 * POST /api/analytics
 * Store analytics events
 */
router.post('/', async (req, res) => {
    try {
        const { session_id, user_id, events } = req.body;

        if (!events || !Array.isArray(events)) {
            return res.status(400).json({ error: 'Invalid events data' });
        }

        // Store events in database
        const insertPromises = events.map(event => {
            // Log to console for real-time monitoring
            logger.info('Analytics Event', {
                session_id,
                user_id: user_id || 'anonymous',
                event: event.event,
                properties: event.properties
            });

            // Store in database
            return db.query(
                'INSERT INTO analytics_events (session_id, user_id, evt_name, page, properties) VALUES (?, ?, ?, ?, ?)',
                [
                    session_id,
                    user_id || 'anonymous',
                    event.event,
                    event.properties?.page || null,
                    JSON.stringify(event.properties || {})
                ]
            );
        });

        // Wait for all inserts to complete
        await Promise.all(insertPromises);

        res.json({ success: true, events_received: events.length });

    } catch (error) {
        logger.error('Analytics endpoint error:', error);
        res.status(500).json({ error: 'Failed to process analytics' });
    }
});

/**
 * GET /api/analytics/summary
 * Get analytics summary for dashboard
 */
router.get('/summary', async (req, res) => {
    try {
        const { days = 7 } = req.query;
        const daysAgo = new Date();
        daysAgo.setDate(daysAgo.getDate() - parseInt(days));

        // Format date for SQLite: YYYY-MM-DD HH:MM:SS (not ISO with timezone)
        const formatDateForSQLite = (date) => {
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const day = String(date.getDate()).padStart(2, '0');
            const hours = String(date.getHours()).padStart(2, '0');
            const minutes = String(date.getMinutes()).padStart(2, '0');
            const seconds = String(date.getSeconds()).padStart(2, '0');
            return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
        };

        const dateThreshold = formatDateForSQLite(daysAgo);

        // Get event counts by type
        const eventCounts = await db.query(`
            SELECT evt_name, COUNT(*) as count
            FROM analytics_events
            WHERE created_at >= ?
            GROUP BY evt_name
            ORDER BY count DESC
        `, [dateThreshold]);

        // Get unique sessions
        const sessions = await db.query(`
            SELECT COUNT(DISTINCT session_id) as count
            FROM analytics_events
            WHERE created_at >= ?
        `, [dateThreshold]);

        // Get unique users
        const users = await db.query(`
            SELECT COUNT(DISTINCT user_id) as count
            FROM analytics_events
            WHERE created_at >= ? AND user_id != 'anonymous'
        `, [dateThreshold]);

        // Get events per day
        const dailyEvents = await db.query(`
            SELECT DATE(created_at) as date, COUNT(*) as count
            FROM analytics_events
            WHERE created_at >= ?
            GROUP BY DATE(created_at)
            ORDER BY date DESC
        `, [dateThreshold]);

        res.json({
            period: `${days} days`,
            event_counts: eventCounts.rows || eventCounts,
            total_sessions: sessions.rows?.[0]?.count || sessions[0]?.count || 0,
            total_users: users.rows?.[0]?.count || users[0]?.count || 0,
            daily_breakdown: dailyEvents.rows || dailyEvents
        });

    } catch (error) {
        logger.error('Analytics summary error:', error);
        res.status(500).json({ error: 'Failed to fetch analytics summary' });
    }
});

/**
 * GET /api/analytics/events
 * Get recent events for monitoring
 */
router.get('/events', async (req, res) => {
    try {
        const { limit = 100, evt_name, user_id } = req.query;

        let query = 'SELECT * FROM analytics_events WHERE 1=1';
        const params = [];

        if (evt_name) {
            query += ' AND evt_name = ?';
            params.push(evt_name);
        }

        if (user_id) {
            query += ' AND user_id = ?';
            params.push(user_id);
        }

        query += ' ORDER BY created_at DESC LIMIT ?';
        params.push(parseInt(limit));

        const events = await db.query(query, params);

        res.json({
            events: events.rows || events,
            count: (events.rows || events).length
        });

    } catch (error) {
        logger.error('Analytics events error:', error);
        res.status(500).json({ error: 'Failed to fetch events' });
    }
});

/**
 * GET /api/analytics/funnel
 * Get conversion funnel data
 */
router.get('/funnel', async (req, res) => {
    try {
        const { days = 7 } = req.query;
        const daysAgo = new Date();
        daysAgo.setDate(daysAgo.getDate() - parseInt(days));

        // Format date for SQLite: YYYY-MM-DD HH:MM:SS (not ISO with timezone)
        const formatDateForSQLite = (date) => {
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const day = String(date.getDate()).padStart(2, '0');
            const hours = String(date.getHours()).padStart(2, '0');
            const minutes = String(date.getMinutes()).padStart(2, '0');
            const seconds = String(date.getSeconds()).padStart(2, '0');
            return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
        };

        const dateThreshold = formatDateForSQLite(daysAgo);

        // Key funnel events
        const funnelSteps = [
            'page_view',
            'first_visit',
            'onboarding_started',
            'onboarding_completed',
            'message_sent',
            'chat_started'
        ];

        const funnelData = await Promise.all(
            funnelSteps.map(async (step) => {
                const result = await db.query(`
                    SELECT COUNT(DISTINCT session_id) as count
                    FROM analytics_events
                    WHERE evt_name = ? AND created_at >= ?
                `, [step, dateThreshold]);

                return {
                    step,
                    count: result.rows?.[0]?.count || result[0]?.count || 0
                };
            })
        );

        res.json({
            period: `${days} days`,
            funnel: funnelData
        });

    } catch (error) {
        logger.error('Analytics funnel error:', error);
        res.status(500).json({ error: 'Failed to fetch funnel data' });
    }
});

module.exports = router;
