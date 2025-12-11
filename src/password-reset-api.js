/**
 * Password Reset API - Task 6 GREEN Phase
 * Minimal implementation to pass all backend tests
 */

const crypto = require('crypto');
const bcrypt = require('bcrypt');
const Database = require('./database');

// Rate limiting storage (in-memory for simplicity)
const rateLimitStore = new Map();

// Clear rate limits (for testing)
function clearRateLimits() {
    rateLimitStore.clear();
}

/**
 * Generate secure reset token using crypto.randomBytes
 */
async function generateResetToken() {
    // Generate 32 random bytes
    const buffer = crypto.randomBytes(32);
    // Convert to URL-safe base64 string
    return buffer.toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
}

/**
 * Check rate limit for IP address
 */
function checkRateLimit(ip) {
    const now = Date.now();
    const oneHour = 60 * 60 * 1000;

    if (!rateLimitStore.has(ip)) {
        rateLimitStore.set(ip, []);
    }

    const attempts = rateLimitStore.get(ip);
    // Remove attempts older than 1 hour
    const recentAttempts = attempts.filter(time => now - time < oneHour);

    if (recentAttempts.length >= 3) {
        const oldestAttempt = recentAttempts[0];
        const retryAfter = Math.ceil((oneHour - (now - oldestAttempt)) / 1000);
        return { allowed: false, retryAfter };
    }

    recentAttempts.push(now);
    rateLimitStore.set(ip, recentAttempts);
    return { allowed: true };
}

/**
 * Validate email format
 */
function validateEmail(email) {
    if (!email || typeof email !== 'string') {
        return false;
    }
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
}

/**
 * Validate password strength
 */
function validatePasswordStrength(password) {
    if (!password || password.length < 8) {
        return { valid: false, error: 'Password must be at least 8 characters' };
    }
    if (!/[A-Z]/.test(password)) {
        return { valid: false, error: 'Password must contain at least one uppercase letter' };
    }
    if (!/[a-z]/.test(password)) {
        return { valid: false, error: 'Password must contain at least one lowercase letter' };
    }
    if (!/[0-9]/.test(password)) {
        return { valid: false, error: 'Password must contain at least one number' };
    }
    if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
        return { valid: false, error: 'Password must contain at least one special character' };
    }

    // Check for common passwords
    const commonPasswords = ['password123', 'Password123', 'Password1', 'password1'];
    if (commonPasswords.includes(password)) {
        return { valid: false, error: 'Password is too common' };
    }

    return { valid: true };
}

/**
 * Mock email sending function
 */
async function sendResetEmail({ email, resetToken, resetUrl }) {
    // Mock implementation for testing
    // In production, this would send actual emails
    console.log(`[Mock Email] Sending reset email to ${email}`);
    console.log(`Reset URL: ${resetUrl}`);
    return true;
}

/**
 * Cleanup expired tokens
 */
async function cleanupExpiredTokens() {
    const db = Database.getInstance();
    const now = new Date().toISOString();

    await db.query(
        'DELETE FROM password_reset_tokens WHERE expires_at < ?',
        [now]
    );
}

// Export functions for mocking in tests
const api = {
    sendResetEmail
};

/**
 * Setup Express routes
 */
function setupRoutes(app) {
    const db = Database.getInstance();

    /**
     * POST /api/forgot-password
     * Request password reset
     */
    app.post('/api/forgot-password', async (req, res) => {
        try {
            const { email } = req.body;

            // Validate email format
            if (!validateEmail(email)) {
                return res.status(400).json({ error: 'Please provide a valid email address' });
            }

            // Check rate limit
            const ip = req.ip || req.connection.remoteAddress || '127.0.0.1';
            const rateLimit = checkRateLimit(ip);

            if (!rateLimit.allowed) {
                console.warn(`Rate limit exceeded for IP: ${ip}`);
                return res.status(429).json({
                    error: 'too many password reset requests, please try again later',
                    retryAfter: rateLimit.retryAfter
                });
            }

            // Look up user by email
            const userResult = await db.query(
                'SELECT id, email FROM users WHERE email = ?',
                [email]
            );

            const users = userResult.rows || userResult;

            // Always return success to prevent email enumeration (security measure)
            // But only send email if user exists
            if (users && users.length > 0) {
                const user = users[0];

                // Generate secure token
                const resetToken = await generateResetToken();
                const tokenHash = crypto.createHash('sha256').update(resetToken).digest('hex');

                // Set expiration to 2 hours from now
                const expiresAt = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();

                // Invalidate previous tokens for this user
                await db.query(
                    'UPDATE password_reset_tokens SET used = 1 WHERE user_id = ? AND used = 0',
                    [user.id]
                );

                // Store hashed token
                await db.query(
                    'INSERT INTO password_reset_tokens (user_id, token_hash, expires_at, used) VALUES (?, ?, ?, ?)',
                    [user.id, tokenHash, expiresAt, 0]
                );

                // Send reset email
                const resetUrl = `${req.protocol}://${req.get('host')}/reset-password?token=${resetToken}`;
                await api.sendResetEmail({
                    email: user.email,
                    resetToken,
                    resetUrl
                });
            }

            // Always return success message (prevent email enumeration)
            res.json({
                success: true,
                message: 'If an account exists with that email, a password reset link has been sent.'
            });

        } catch (error) {
            console.error('Forgot password error:', error);
            res.status(500).json({ error: 'An error occurred processing your request' });
        }
    });

    /**
     * GET /api/verify-reset-token
     * Verify token is valid before showing reset form
     */
    app.get('/api/verify-reset-token', async (req, res) => {
        try {
            const { token } = req.query;

            if (!token) {
                return res.status(400).json({
                    valid: false,
                    error: 'Reset token is required'
                });
            }

            // Hash the token to look up in database
            const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

            // Look up token
            const result = await db.query(
                'SELECT user_id, expires_at, used FROM password_reset_tokens WHERE token_hash = ?',
                [tokenHash]
            );

            const tokens = result.rows || result;

            if (!tokens || tokens.length === 0) {
                return res.status(400).json({
                    valid: false,
                    error: 'Invalid or expired reset token'
                });
            }

            const tokenData = tokens[0];

            // Check if token is expired
            if (new Date(tokenData.expires_at) < new Date()) {
                return res.status(400).json({
                    valid: false,
                    error: 'Reset token has expired'
                });
            }

            // Check if token has been used
            if (tokenData.used === 1) {
                return res.status(400).json({
                    valid: false,
                    error: 'Reset token has already been used'
                });
            }

            res.json({ valid: true });

        } catch (error) {
            console.error('Token verification error:', error);
            res.status(500).json({
                valid: false,
                error: 'An error occurred verifying the token'
            });
        }
    });

    /**
     * POST /api/reset-password
     * Reset password with valid token
     */
    app.post('/api/reset-password', async (req, res) => {
        try {
            const { token, newPassword, confirmPassword } = req.body;

            // Validate passwords match
            if (newPassword !== confirmPassword) {
                return res.status(400).json({
                    error: 'Passwords do not match'
                });
            }

            // Validate password strength
            const passwordValidation = validatePasswordStrength(newPassword);
            if (!passwordValidation.valid) {
                return res.status(400).json({
                    error: passwordValidation.error
                });
            }

            // Hash the token to look up in database
            const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

            // Look up token
            const result = await db.query(
                'SELECT user_id, expires_at, used FROM password_reset_tokens WHERE token_hash = ?',
                [tokenHash]
            );

            const tokens = result.rows || result;

            if (!tokens || tokens.length === 0) {
                return res.status(400).json({
                    error: 'invalid or expired reset token'
                });
            }

            const tokenData = tokens[0];

            // Check if token is expired
            if (new Date(tokenData.expires_at) < new Date()) {
                return res.status(400).json({
                    error: 'Reset token has expired'
                });
            }

            // Check if token has been used
            if (tokenData.used === 1) {
                return res.status(400).json({
                    error: 'Reset token has already been used'
                });
            }

            // Hash new password with bcrypt (cost factor 10)
            const passwordHash = await bcrypt.hash(newPassword, 10);

            // Update user's password
            await db.query(
                'UPDATE users SET password_hash = ? WHERE id = ?',
                [passwordHash, tokenData.user_id]
            );

            // Mark token as used
            await db.query(
                'UPDATE password_reset_tokens SET used = 1 WHERE token_hash = ?',
                [tokenHash]
            );

            res.json({
                success: true,
                message: 'Password has been reset successfully'
            });

        } catch (error) {
            console.error('Password reset error:', error);
            res.status(500).json({
                error: 'An error occurred resetting your password'
            });
        }
    });
}

/**
 * Create Express app for testing
 */
function createTestApp() {
    const express = require('express');
    const app = express();

    // Middleware
    app.use(express.json());
    app.use(express.urlencoded({ extended: true }));

    // Setup routes
    setupRoutes(app);

    return app;
}

module.exports = {
    setupRoutes,
    generateResetToken,
    sendResetEmail,
    cleanupExpiredTokens,
    clearRateLimits,
    createTestApp,
    api
};
