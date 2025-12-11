const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const resourceLifecycleManager = require('../resource-lifecycle-manager');

/**
 * Production-Grade Admin Authentication Middleware
 * Implements secure PIN-based authentication for admin endpoints
 * 
 * Security Features:
 * - Strong ADMIN_PIN requirement
 * - Rate limiting and brute force protection
 * - Session management with secure tokens
 * - Comprehensive audit logging
 * - IP whitelisting capability
 * - Timing attack prevention
 * - Automatic session expiration
 */

class AdminAuthManager {
    constructor() {
        this.cleanupIntervalId = null; // ARCHITECTURAL FIX: Store interval ID for cleanup
        this.initializeConfig();
        this.initializeRateLimiting();
        this.initializeLogging();
        this.initializeSessionManager();
    }

    initializeConfig() {
        // Validate ADMIN_PIN is properly configured
        this.adminPin = process.env.ADMIN_PIN;
        
        if (!this.adminPin) {
            console.error('CRITICAL SECURITY ERROR: ADMIN_PIN environment variable is not set');
            console.error('Admin endpoints will be completely disabled for security');
            throw new Error('ADMIN_PIN must be configured for production deployment');
        }

        // Validate PIN strength
        if (this.adminPin.length < 8) {
            throw new Error('ADMIN_PIN must be at least 8 characters long');
        }

        if (!/^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]/.test(this.adminPin)) {
            console.warn('WARNING: ADMIN_PIN should contain letters, numbers, and special characters for maximum security');
        }

        // Hash the PIN for secure comparison (prevents timing attacks)
        this.adminPinHash = crypto.createHash('sha256').update(this.adminPin).digest('hex');

        // Configuration
        this.config = {
            maxAttempts: parseInt(process.env.ADMIN_MAX_ATTEMPTS) || 5,
            lockoutDuration: parseInt(process.env.ADMIN_LOCKOUT_DURATION) || 900000, // 15 minutes
            sessionDuration: parseInt(process.env.ADMIN_SESSION_DURATION) || 3600000, // 1 hour
            allowedIPs: process.env.ADMIN_ALLOWED_IPS ? process.env.ADMIN_ALLOWED_IPS.split(',') : [],
            requireHTTPS: process.env.NODE_ENV === 'production',
            logPath: path.join(__dirname, '../../logs/admin-access.log')
        };

        console.log('Admin authentication configured with security features enabled');
    }

    initializeRateLimiting() {
        // Rate limiting data structures
        this.attemptTracker = new Map(); // IP -> { attempts, lastAttempt, lockedUntil }
        this.sessionAttempts = new Map(); // Session -> attempt count
    }

    initializeLogging() {
        // Ensure log directory exists
        const logDir = path.dirname(this.config.logPath);
        if (!fs.existsSync(logDir)) {
            fs.mkdirSync(logDir, { recursive: true, mode: 0o750 });
        }
    }

    initializeSessionManager() {
        // Active admin sessions
        this.activeSessions = new Map(); // sessionId -> { ip, createdAt, lastActivity, userAgent }

        // ARCHITECTURAL FIX: Use ResourceLifecycleManager for automatic cleanup
        this.cleanupIntervalId = resourceLifecycleManager.registerInterval(
            'admin-auth-session-cleanup',
            () => this.cleanupExpiredSessions(),
            300000 // Every 5 minutes
        );
    }

    /**
     * Shutdown and cleanup resources
     * ARCHITECTURAL FIX: Proper resource cleanup on server shutdown
     */
    shutdown() {
        if (this.cleanupIntervalId) {
            resourceLifecycleManager.clearInterval('admin-auth-session-cleanup');
            this.cleanupIntervalId = null;
        }
        this.activeSessions.clear();
        this.attemptTracker.clear();
        this.sessionAttempts.clear();
        console.log('✅ AdminAuthManager shutdown complete');
    }

    /**
     * Secure constant-time string comparison to prevent timing attacks
     */
    secureCompare(a, b) {
        if (a.length !== b.length) {
            return false;
        }
        
        let result = 0;
        for (let i = 0; i < a.length; i++) {
            result |= a.charCodeAt(i) ^ b.charCodeAt(i);
        }
        
        return result === 0;
    }

    /**
     * Generate cryptographically secure session token
     */
    generateSessionToken() {
        return crypto.randomBytes(32).toString('hex');
    }

    /**
     * Log security events with structured format
     */
    logSecurityEvent(event, ip, details = {}) {
        const timestamp = new Date().toISOString();
        const logEntry = {
            timestamp,
            event,
            ip,
            details,
            severity: this.getEventSeverity(event)
        };

        const logLine = JSON.stringify(logEntry) + '\n';

        try {
            fs.appendFileSync(this.config.logPath, logLine, { mode: 0o640 });
        } catch (error) {
            console.error('Failed to write admin security log:', error.message);
        }

        // Also log to console for monitoring
        const logLevel = logEntry.severity === 'critical' ? 'error' : 'warn';
        console[logLevel](`ADMIN_SECURITY [${event}] IP: ${ip}`, details);
    }

    getEventSeverity(event) {
        const criticalEvents = ['BRUTE_FORCE_DETECTED', 'UNAUTHORIZED_ACCESS_BLOCKED', 'IP_BLOCKED'];
        const warningEvents = ['INVALID_PIN_ATTEMPT', 'SESSION_EXPIRED', 'RATE_LIMIT_EXCEEDED'];
        
        if (criticalEvents.includes(event)) return 'critical';
        if (warningEvents.includes(event)) return 'warning';
        return 'info';
    }

    /**
     * Check if IP is allowed (whitelist feature)
     */
    isIPAllowed(ip) {
        if (this.config.allowedIPs.length === 0) {
            return true; // No whitelist configured
        }
        
        return this.config.allowedIPs.some(allowedIP => {
            // Support CIDR notation in the future if needed
            return ip === allowedIP || ip.startsWith(allowedIP);
        });
    }

    /**
     * Check rate limiting and brute force protection
     */
    checkRateLimit(ip) {
        const now = Date.now();
        const tracker = this.attemptTracker.get(ip) || { attempts: 0, lastAttempt: 0, lockedUntil: 0 };

        // Check if IP is currently locked out
        if (tracker.lockedUntil > now) {
            const remainingLockout = Math.ceil((tracker.lockedUntil - now) / 1000);
            this.logSecurityEvent('RATE_LIMIT_EXCEEDED', ip, { remainingLockout });
            return { allowed: false, remainingLockout };
        }

        // Reset attempts if enough time has passed
        if (now - tracker.lastAttempt > this.config.lockoutDuration) {
            tracker.attempts = 0;
        }

        return { allowed: true, currentAttempts: tracker.attempts };
    }

    /**
     * Record failed authentication attempt
     */
    recordFailedAttempt(ip) {
        const now = Date.now();
        const tracker = this.attemptTracker.get(ip) || { attempts: 0, lastAttempt: 0, lockedUntil: 0 };
        
        tracker.attempts++;
        tracker.lastAttempt = now;

        if (tracker.attempts >= this.config.maxAttempts) {
            tracker.lockedUntil = now + this.config.lockoutDuration;
            this.logSecurityEvent('BRUTE_FORCE_DETECTED', ip, { 
                attempts: tracker.attempts,
                lockoutDuration: this.config.lockoutDuration 
            });
        } else {
            this.logSecurityEvent('INVALID_PIN_ATTEMPT', ip, { 
                attempts: tracker.attempts,
                maxAttempts: this.config.maxAttempts 
            });
        }

        this.attemptTracker.set(ip, tracker);
    }

    /**
     * Create new admin session
     */
    createSession(ip, userAgent) {
        const sessionId = this.generateSessionToken();
        const now = Date.now();
        
        this.activeSessions.set(sessionId, {
            ip,
            userAgent,
            createdAt: now,
            lastActivity: now
        });

        // Reset failed attempts for this IP
        this.attemptTracker.delete(ip);

        this.logSecurityEvent('ADMIN_LOGIN_SUCCESS', ip, { sessionId: sessionId.substring(0, 8) + '...' });
        
        return sessionId;
    }

    /**
     * Validate existing session
     */
    validateSession(sessionId, ip) {
        const session = this.activeSessions.get(sessionId);
        
        if (!session) {
            return { valid: false, reason: 'SESSION_NOT_FOUND' };
        }

        const now = Date.now();
        
        // Check session expiration
        if (now - session.lastActivity > this.config.sessionDuration) {
            this.activeSessions.delete(sessionId);
            this.logSecurityEvent('SESSION_EXPIRED', ip, { sessionId: sessionId.substring(0, 8) + '...' });
            return { valid: false, reason: 'SESSION_EXPIRED' };
        }

        // Check IP consistency
        if (session.ip !== ip) {
            this.activeSessions.delete(sessionId);
            this.logSecurityEvent('SESSION_IP_MISMATCH', ip, { 
                sessionId: sessionId.substring(0, 8) + '...',
                originalIP: session.ip 
            });
            return { valid: false, reason: 'IP_MISMATCH' };
        }

        // Update last activity
        session.lastActivity = now;
        
        return { valid: true, session };
    }

    /**
     * Clean up expired sessions
     */
    cleanupExpiredSessions() {
        const now = Date.now();
        let cleanedCount = 0;
        
        for (const [sessionId, session] of this.activeSessions.entries()) {
            if (now - session.lastActivity > this.config.sessionDuration) {
                this.activeSessions.delete(sessionId);
                cleanedCount++;
            }
        }
        
        if (cleanedCount > 0) {
            console.log(`Cleaned up ${cleanedCount} expired admin sessions`);
        }
    }

    /**
     * Main authentication middleware
     */
    authenticate() {
        return async (req, res, next) => {
            try {
                const ip = req.ip || req.connection.remoteAddress || 'unknown';
                const userAgent = req.get('user-agent') || 'unknown';

                // Security headers check
                if (this.config.requireHTTPS && req.get('x-forwarded-proto') !== 'https' && !req.secure) {
                    this.logSecurityEvent('HTTPS_REQUIRED', ip);
                    return res.status(426).json({ 
                        error: 'HTTPS required for admin access',
                        code: 'HTTPS_REQUIRED'
                    });
                }

                // IP whitelist check
                if (!this.isIPAllowed(ip)) {
                    this.logSecurityEvent('IP_BLOCKED', ip);
                    return res.status(403).json({ 
                        error: 'Access denied - IP not authorized',
                        code: 'IP_BLOCKED'
                    });
                }

                // Check for existing session
                const sessionToken = req.get('X-Admin-Session') || req.cookies?.['admin-session'];
                
                if (sessionToken) {
                    const sessionValidation = this.validateSession(sessionToken, ip);
                    if (sessionValidation.valid) {
                        // Valid session - allow access
                        req.adminSession = sessionValidation.session;
                        return next();
                    }
                    // Invalid session - continue to PIN authentication
                }

                // Rate limiting check
                const rateLimitCheck = this.checkRateLimit(ip);
                if (!rateLimitCheck.allowed) {
                    return res.status(429).json({ 
                        error: 'Too many attempts - try again later',
                        code: 'RATE_LIMITED',
                        retryAfter: rateLimitCheck.remainingLockout
                    });
                }

                // PIN authentication
                const providedPin = req.get('X-Admin-PIN') || req.body?.admin_pin;
                
                if (!providedPin) {
                    return res.status(401).json({ 
                        error: 'Admin PIN required',
                        code: 'PIN_REQUIRED'
                    });
                }

                // Secure PIN comparison (prevents timing attacks)
                const providedPinHash = crypto.createHash('sha256').update(providedPin).digest('hex');
                const isValidPin = this.secureCompare(this.adminPinHash, providedPinHash);

                if (!isValidPin) {
                    this.recordFailedAttempt(ip);
                    return res.status(401).json({ 
                        error: 'Invalid admin PIN',
                        code: 'INVALID_PIN'
                    });
                }

                // Successful authentication - create session
                const sessionId = this.createSession(ip, userAgent);
                
                // Set secure session cookie
                res.cookie('admin-session', sessionId, {
                    httpOnly: true,
                    secure: this.config.requireHTTPS,
                    sameSite: 'strict',
                    maxAge: this.config.sessionDuration
                });

                // Also provide session in response for API clients
                res.set('X-Admin-Session', sessionId);

                req.adminSession = this.activeSessions.get(sessionId);
                next();

            } catch (error) {
                console.error('Admin authentication error:', error);
                this.logSecurityEvent('AUTH_ERROR', req.ip || 'unknown', { error: error.message });
                return res.status(500).json({ 
                    error: 'Authentication system error',
                    code: 'AUTH_ERROR'
                });
            }
        };
    }

    /**
     * Get current authentication status
     */
    getStatus() {
        return {
            activeSessions: this.activeSessions.size,
            blockedIPs: Array.from(this.attemptTracker.entries())
                .filter(([, tracker]) => tracker.lockedUntil > Date.now())
                .length,
            config: {
                maxAttempts: this.config.maxAttempts,
                sessionDuration: this.config.sessionDuration,
                hasIPWhitelist: this.config.allowedIPs.length > 0,
                httpsRequired: this.config.requireHTTPS
            }
        };
    }
}

// Create singleton instance
const adminAuthManager = new AdminAuthManager();

// Export middleware function
const authenticateAdmin = adminAuthManager.authenticate();

// Export additional utilities
module.exports = {
    authenticateAdmin,
    getAuthStatus: () => adminAuthManager.getStatus(),
    cleanupSessions: () => adminAuthManager.cleanupExpiredSessions()
};