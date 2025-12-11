/**
 * Password Reset Service
 * Handles secure password reset flow with token generation, validation, and expiration
 *
 * @module PasswordResetService
 */

const crypto = require('crypto');
const Database = require('../database');
const EmailService = require('./email-service');
const authService = require('./auth');

/**
 * Password Reset Configuration
 */
const CONFIG = {
    TOKEN_EXPIRY_HOURS: 1,
    MAX_REQUESTS_PER_HOUR: 3,
    TOKEN_LENGTH: 32,
    CLEANUP_INTERVAL_HOURS: 6
};

class PasswordResetService {
    constructor() {
        this.db = null;
        this.requestTracker = new Map(); // Track requests per IP/email
    }

    /**
     * Get database instance
     */
    _getDb() {
        if (!this.db) {
            this.db = Database.getInstance();
        }
        return this.db;
    }

    /**
     * Generate secure random token
     * @returns {string} Hex token
     */
    generateToken() {
        return crypto.randomBytes(CONFIG.TOKEN_LENGTH).toString('hex');
    }

    /**
     * Hash token for secure storage
     * @param {string} token - Plain token
     * @returns {string} SHA-256 hash
     */
    hashToken(token) {
        return crypto.createHash('sha256').update(token).digest('hex');
    }

    /**
     * Check rate limiting for password reset requests
     * @param {string} key - IP address or email
     * @returns {boolean} True if rate limited
     */
    isRateLimited(key) {
        const now = Date.now();
        const attempts = this.requestTracker.get(key) || [];

        // Remove attempts older than 1 hour
        const recentAttempts = attempts.filter(
            timestamp => now - timestamp < 60 * 60 * 1000
        );

        if (recentAttempts.length >= CONFIG.MAX_REQUESTS_PER_HOUR) {
            return true;
        }

        // Update tracker
        recentAttempts.push(now);
        this.requestTracker.set(key, recentAttempts);

        return false;
    }

    /**
     * Request password reset
     * @param {string} email - User email
     * @param {string} ipAddress - Request IP
     * @param {string} userAgent - User agent string
     * @returns {Promise<Object>} Result object
     */
    async requestPasswordReset(email, ipAddress, userAgent) {
        const db = this._getDb();

        // Validate email format
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            throw new Error('Invalid email format');
        }

        // Rate limiting by IP
        if (this.isRateLimited(ipAddress)) {
            throw new Error('Too many password reset requests. Please try again later.');
        }

        // Rate limiting by email (prevents targeted attacks)
        if (this.isRateLimited(email)) {
            throw new Error('Too many password reset requests for this email. Please try again later.');
        }

        try {
            // Find user by email
            const userResult = await db.query(
                'SELECT id, email FROM users WHERE email = ?',
                [email.toLowerCase().trim()]
            );

            const users = userResult.rows || userResult;

            // SECURITY: Don't reveal if email exists
            // Always return success message to prevent email enumeration
            if (!users || users.length === 0) {
                console.log(`Password reset requested for non-existent email: ${email}`);
                return {
                    success: true,
                    message: 'If an account exists with this email, a password reset link has been sent.'
                };
            }

            const user = users[0];

            // Generate secure token
            const token = this.generateToken();
            const tokenHash = this.hashToken(token);
            const expiresAt = new Date(Date.now() + CONFIG.TOKEN_EXPIRY_HOURS * 60 * 60 * 1000).toISOString();

            // Store token in database
            await db.query(`
                INSERT INTO password_reset_tokens
                (user_id, token_hash, email, expires_at, ip_address, user_agent)
                VALUES (?, ?, ?, ?, ?, ?)
            `, [user.id, tokenHash, email.toLowerCase().trim(), expiresAt, ipAddress, userAgent]);

            // Send email with reset link
            try {
                await EmailService.sendPasswordResetEmail(email, token);
                console.log(`Password reset email sent to: ${email}`);
            } catch (emailError) {
                console.error('Failed to send password reset email:', emailError);
                // Don't throw - we don't want to reveal if email sending failed
            }

            return {
                success: true,
                message: 'If an account exists with this email, a password reset link has been sent.'
            };
        } catch (error) {
            console.error('Password reset request error:', error);
            throw error;
        }
    }

    /**
     * Verify password reset token
     * @param {string} token - Reset token
     * @returns {Promise<Object>} Token validation result
     */
    async verifyToken(token) {
        const db = this._getDb();

        if (!token) {
            return {
                valid: false,
                error: 'Token is required'
            };
        }

        try {
            const tokenHash = this.hashToken(token);

            // Find token in database
            const result = await db.query(`
                SELECT
                    prt.id,
                    prt.user_id,
                    prt.email,
                    prt.expires_at,
                    prt.used,
                    u.id as user_exists
                FROM password_reset_tokens prt
                LEFT JOIN users u ON prt.user_id = u.id
                WHERE prt.token_hash = ?
            `, [tokenHash]);

            const tokens = result.rows || result;

            if (!tokens || tokens.length === 0) {
                return {
                    valid: false,
                    error: 'Invalid or expired reset link'
                };
            }

            const tokenData = tokens[0];

            // Check if token has been used
            if (tokenData.used) {
                return {
                    valid: false,
                    error: 'This reset link has already been used'
                };
            }

            // Check if token is expired
            const expiresAt = new Date(tokenData.expires_at);
            if (expiresAt < new Date()) {
                return {
                    valid: false,
                    error: 'This reset link has expired. Please request a new one.'
                };
            }

            // Check if user still exists
            if (!tokenData.user_exists) {
                return {
                    valid: false,
                    error: 'Invalid reset link'
                };
            }

            return {
                valid: true,
                userId: tokenData.user_id,
                email: tokenData.email
            };
        } catch (error) {
            console.error('Token verification error:', error);
            return {
                valid: false,
                error: 'Failed to verify reset link'
            };
        }
    }

    /**
     * Complete password reset
     * @param {string} token - Reset token
     * @param {string} newPassword - New password
     * @param {string} ipAddress - Request IP
     * @returns {Promise<Object>} Result with JWT token
     */
    async completePasswordReset(token, newPassword, ipAddress) {
        const db = this._getDb();

        // Verify token first
        const verification = await this.verifyToken(token);
        if (!verification.valid) {
            throw new Error(verification.error);
        }

        // Validate new password
        const passwordValidation = authService.validatePassword(newPassword);
        if (!passwordValidation.isValid) {
            throw new Error(passwordValidation.errors.join(', '));
        }

        try {
            const bcrypt = require('bcrypt');
            const jwt = require('jsonwebtoken');

            // Hash new password
            const passwordHash = await bcrypt.hash(newPassword, 10);

            // Update user password
            await db.query(
                'UPDATE users SET password_hash = ? WHERE id = ?',
                [passwordHash, verification.userId]
            );

            // Mark token as used
            const tokenHash = this.hashToken(token);
            await db.query(
                'UPDATE password_reset_tokens SET used = 1, used_at = ? WHERE token_hash = ?',
                [new Date().toISOString(), tokenHash]
            );

            // Get updated user data
            const userResult = await db.query(
                `SELECT id, email, email_verified, subscription_status, is_admin
                 FROM users WHERE id = ?`,
                [verification.userId]
            );

            const users = userResult.rows || userResult;
            const user = users[0];

            // Generate JWT token for auto-login
            const authToken = authService.generateToken({
                id: user.id,
                email: user.email,
                emailVerified: user.email_verified === 1 || user.email_verified === true,
                subscriptionStatus: user.subscription_status || 'free'
            });

            console.log(`Password reset completed for user: ${user.email} from IP: ${ipAddress}`);

            return {
                success: true,
                token: authToken,
                user: {
                    id: user.id,
                    email: user.email,
                    emailVerified: user.email_verified === 1 || user.email_verified === true,
                    subscriptionStatus: user.subscription_status || 'free',
                    isPremium: ['premium', 'premium_monthly', 'premium_yearly', 'lifetime'].includes(user.subscription_status),
                    isAdmin: user.is_admin === 1 || user.is_admin === true
                }
            };
        } catch (error) {
            console.error('Password reset completion error:', error);
            throw new Error('Failed to reset password. Please try again.');
        }
    }

    /**
     * Clean up expired tokens
     * Should be run periodically
     */
    async cleanupExpiredTokens() {
        const db = this._getDb();

        try {
            const result = await db.query(
                'DELETE FROM password_reset_tokens WHERE expires_at < ?',
                [new Date().toISOString()]
            );

            const deletedCount = result.rowCount || result.changes || 0;
            if (deletedCount > 0) {
                console.log(`Cleaned up ${deletedCount} expired password reset tokens`);
            }
        } catch (error) {
            console.error('Token cleanup error:', error);
        }
    }

    /**
     * Invalidate all tokens for a user
     * Useful for security purposes (e.g., after successful password change)
     * @param {number} userId - User ID
     */
    async invalidateUserTokens(userId) {
        const db = this._getDb();

        try {
            await db.query(
                'UPDATE password_reset_tokens SET used = 1, used_at = ? WHERE user_id = ? AND used = 0',
                [new Date().toISOString(), userId]
            );
            console.log(`Invalidated all password reset tokens for user: ${userId}`);
        } catch (error) {
            console.error('Error invalidating user tokens:', error);
        }
    }
}

// Export singleton instance
module.exports = new PasswordResetService();
