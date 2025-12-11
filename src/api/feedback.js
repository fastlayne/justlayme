// User feedback system for JustLayMe
// Handles bug reports and user feedback collection

const express = require('express');
const router = express.Router();
const logger = require('../logger');
const Database = require('../database');
const inputValidation = require('../middleware/input-validation');

// Initialize database connection
const db = Database.getInstance();

// Create feedback table at module initialization (not on every request)
(async function initFeedbackTable() {
    try {
        await db.query(`
            CREATE TABLE IF NOT EXISTS feedback (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL,
                subject TEXT NOT NULL,
                message TEXT NOT NULL,
                user_email TEXT,
                user_id TEXT,
                severity TEXT DEFAULT 'medium',
                browser_info TEXT,
                url TEXT,
                steps TEXT,
                expected_result TEXT,
                actual_result TEXT,
                status TEXT DEFAULT 'open',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `);
        logger.info('Feedback table initialized');
    } catch (error) {
        logger.error('Failed to initialize feedback table:', error);
    }
})();

// Feedback validation schema
const feedbackValidation = (req, res, next) => {
    const { type, subject, message, userEmail, userId, severity, browserInfo, url } = req.body;
    
    const errors = [];
    
    // Required fields
    if (!type || !['bug', 'feature', 'general', 'ui', 'performance'].includes(type)) {
        errors.push('Valid feedback type is required (bug, feature, general, ui, performance)');
    }
    
    if (!subject || subject.trim().length < 5 || subject.length > 200) {
        errors.push('Subject must be between 5 and 200 characters');
    }
    
    if (!message || message.trim().length < 10 || message.length > 5000) {
        errors.push('Message must be between 10 and 5000 characters');
    }
    
    // Optional but validated if provided
    if (userEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(userEmail)) {
        errors.push('Invalid email format');
    }
    
    if (userId && !/^[0-9]+$/.test(userId)) {
        errors.push('Invalid user ID format');
    }
    
    if (severity && !['low', 'medium', 'high', 'critical'].includes(severity)) {
        errors.push('Severity must be low, medium, high, or critical');
    }
    
    if (errors.length > 0) {
        return res.status(400).json({
            error: 'Validation failed',
            details: errors,
            requestId: req.requestId
        });
    }
    
    // Sanitize strings
    req.body.subject = subject.trim();
    req.body.message = message.trim();
    if (userEmail) req.body.userEmail = userEmail.trim().toLowerCase();
    
    next();
};

/**
 * Submit feedback/bug report
 */
router.post('/submit', feedbackValidation, async (req, res) => {
    try {
        const {
            type,
            subject,
            message,
            userEmail,
            userId,
            severity = 'medium',
            browserInfo = {},
            url = '',
            steps = '',
            expected = '',
            actual = ''
        } = req.body;
        
        logger.info('Feedback submission received', req.requestId, { type, subject, userId });

        // Table already created at module initialization

        // Insert feedback
        const result = await db.query(`
            INSERT INTO feedback (
                type, subject, message, user_email, user_id, severity,
                browser_info, url, steps, expected_result, actual_result
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `, [
            type,
            subject,
            message,
            userEmail || null,
            userId || null,
            severity,
            JSON.stringify(browserInfo),
            url,
            steps,
            expected,
            actual
        ]);
        
        const feedbackId = result.lastInsertRowid || result.insertId;
        
        logger.info('Feedback saved successfully', req.requestId, { feedbackId, type });
        
        // Send notification email if configured
        try {
            await sendFeedbackNotification({
                id: feedbackId,
                type,
                subject,
                message,
                userEmail,
                severity
            });
        } catch (emailError) {
            logger.warn('Failed to send feedback notification email', req.requestId, emailError.message);
        }
        
        res.status(201).json({
            success: true,
            message: 'Feedback submitted successfully',
            feedbackId,
            requestId: req.requestId
        });
        
    } catch (error) {
        logger.error('Error submitting feedback', req.requestId, error);
        res.status(500).json({
            error: 'Failed to submit feedback',
            message: 'Please try again later',
            requestId: req.requestId
        });
    }
});

/**
 * Get user's feedback history
 */
router.get('/history/:userId', inputValidation.userId, async (req, res) => {
    try {
        const { userId } = req.params;
        const limit = Math.min(parseInt(req.query.limit) || 50, 100);
        const offset = parseInt(req.query.offset) || 0;
        
        logger.debug('Fetching feedback history', req.requestId, { userId, limit, offset });
        
        const feedback = await db.query(`
            SELECT id, type, subject, severity, status, created_at, updated_at
            FROM feedback
            WHERE user_id = ?
            ORDER BY created_at DESC
            LIMIT ? OFFSET ?
        `, [userId, limit, offset]);
        
        const total = await db.query(`
            SELECT COUNT(*) as count
            FROM feedback
            WHERE user_id = ?
        `, [userId]);
        
        res.json({
            feedback: feedback.rows || feedback,
            total: total.rows?.[0]?.count || total[0]?.count || 0,
            limit,
            offset,
            requestId: req.requestId
        });
        
    } catch (error) {
        logger.error('Error fetching feedback history', req.requestId, error);
        res.status(500).json({
            error: 'Failed to fetch feedback history',
            requestId: req.requestId
        });
    }
});

/**
 * Get feedback status
 */
router.get('/status/:feedbackId', async (req, res) => {
    try {
        const { feedbackId } = req.params;
        
        if (!/^[0-9]+$/.test(feedbackId)) {
            return res.status(400).json({
                error: 'Invalid feedback ID format',
                requestId: req.requestId
            });
        }
        
        const feedback = await db.query(`
            SELECT id, type, subject, status, created_at, updated_at
            FROM feedback
            WHERE id = ?
        `, [feedbackId]);
        
        const result = feedback.rows?.[0] || feedback[0];
        
        if (!result) {
            return res.status(404).json({
                error: 'Feedback not found',
                requestId: req.requestId
            });
        }
        
        res.json({
            feedback: result,
            requestId: req.requestId
        });
        
    } catch (error) {
        logger.error('Error fetching feedback status', req.requestId, error);
        res.status(500).json({
            error: 'Failed to fetch feedback status',
            requestId: req.requestId
        });
    }
});

/**
 * Send feedback notification email (placeholder)
 */
async function sendFeedbackNotification(feedback) {
    // This would integrate with your email service
    // For now, just log it
    logger.info('Feedback notification', null, {
        id: feedback.id,
        type: feedback.type,
        subject: feedback.subject,
        severity: feedback.severity,
        userEmail: feedback.userEmail
    });
}

module.exports = router;